-- tb_tg_tm_manager_top.vhd
--
-- Testbench for tg_tm_manager_top (TG write phase + Manager NI).
--
-- Goal:
--   * Drive 5 write transactions from TG into the Manager NI
--   * Emulate the remote NoC endpoint at flit level:
--       - capture request packet flits leaving the manager (l_in_*)
--       - build and inject a response packet (l_out_*) following the packet format
--         shown in the provided figures
--       - echo payload back (loopback), so later TM can compare sequences
--   * Print the observed payload words (WDATA sequence / LFSR progression)
--
-- Notes:
--   * This TB assumes a single control bit at flit MSB and a 32-bit packet word
--     in the lower bits when c_FLIT_WIDTH = 33. If your c_FLIT_WIDTH differs,
--     the helper functions adapt by always treating the MSB as the control bit
--     and taking the lower 32 bits as the packet word.
--   * Integrity/checksum features can be disabled through generics in the DUT.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity tb_tg_tm_manager_top is
end entity;

architecture tb of tb_tg_tm_manager_top is
  constant c_CLK_PERIOD : time := 10 ns;
  constant c_WORD_W     : natural := 32;

  -- DUT I/O
  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal i_tg_start   : std_logic := '0';
  signal o_tg_done    : std_logic;
  signal i_tg_address : std_logic_vector(63 downto 0) := (others => '0');
  signal i_tg_seed    : std_logic_vector(31 downto 0) := (others => '0');

  signal i_tg_ext_update_en : std_logic := '0';
  signal i_tg_ext_data_in   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  signal o_tg_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal o_corrupt_packet : std_logic;

  signal l_in_data_i  : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal l_in_val_i   : std_logic;
  signal l_in_ack_o   : std_logic := '1';

  signal l_out_data_o : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal l_out_val_o  : std_logic := '0';
  signal l_out_ack_i  : std_logic;

  -- Helper types for response buffering
  type flit_mem_t is array (0 to 63) of std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

  -- ========= Helper functions =========

  -- MSB is used as the "control" bit (1 for header/checksum flits; 0 for others)
  function flit_ctrl(f : std_logic_vector) return std_logic is
  begin
    return f(f'high);
  end function;

  -- Get the 32-bit packet word from the lower bits of the flit.
  function flit_word(f : std_logic_vector) return std_logic_vector is
    variable w : std_logic_vector(c_WORD_W - 1 downto 0) := (others => '0');
    variable n : natural;
  begin
    n := f'length;
    if n >= c_WORD_W then
      w := f(c_WORD_W - 1 downto 0);
    else
      -- pad MSBs with zero if flit is unexpectedly narrower
      w(c_WORD_W - 1 downto c_WORD_W - n) := f;
    end if;
    return w;
  end function;

  -- Build a flit from ctrl bit and 32-bit word.
  function mk_flit(ctrl : std_logic; w : std_logic_vector(c_WORD_W - 1 downto 0))
    return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  begin
    -- lower 32 bits carry the packet word
    if c_FLIT_WIDTH >= c_WORD_W then
      f(c_WORD_W - 1 downto 0) := w;
    else
      f := w(c_FLIT_WIDTH - 1 downto 0);
    end if;

    -- MSB carries control (if there is room for it)
    f(f'high) := ctrl;
    return f;
  end function;

  -- XOR checksum over a list of 32-bit words.
  function xor_checksum(words : in std_logic_vector) return std_logic_vector is
    -- unused: placeholder to satisfy some tools
    variable dummy : std_logic_vector(31 downto 0);
  begin
    dummy := (others => '0');
    return dummy;
  end function;

begin
  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- Always-ready on injection link (manager -> NoC)
  l_in_ack_o <= '1';

  -- DUT
  dut: entity work.tg_tm_manager_top
    generic map(
      -- Keep a deterministic init above the seed (you can change it)
      p_TG_INIT_VALUE => (others => '0'),

      -- Disable integrity features in the NI for bring-up TB robustness
      p_USE_TMR_PACKETIZER => false,
      p_USE_TMR_FLOW       => false,
      p_USE_TMR_INTEGRITY  => false,
      p_USE_HAMMING        => false,
      p_USE_INTEGRITY      => false
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start   => i_tg_start,
      o_tg_done    => o_tg_done,
      i_tg_address => i_tg_address,
      i_tg_seed    => i_tg_seed,

      i_tg_ext_update_en => i_tg_ext_update_en,
      i_tg_ext_data_in   => i_tg_ext_data_in,

      o_tg_lfsr_value  => o_tg_lfsr_value,
      o_corrupt_packet => o_corrupt_packet,

      l_in_data_i  => l_in_data_i,
      l_in_val_i   => l_in_val_i,
      l_in_ack_o   => l_in_ack_o,
      l_out_data_o => l_out_data_o,
      l_out_val_o  => l_out_val_o,
      l_out_ack_i  => l_out_ack_i
    );

  -- ================================
  -- NoC remote endpoint (flit-level)
  -- ================================
  -- Captures manager request packets and injects a response packet back.
  -- Response mirrors ID/LEN/BURST/OP and echoes the payload.
  noc_stub: process(ACLK)
    -- request capture
    variable req_words : std_logic_vector(63*32-1 downto 0); -- packed storage (word0 at [31:0])
    variable req_word_cnt : natural := 0;
    variable req_expected_words : natural := 0;

    -- decoded
    variable header0 : std_logic_vector(31 downto 0);
    variable header1 : std_logic_vector(31 downto 0);
    variable ctrlw   : std_logic_vector(31 downto 0);

    variable xdest : std_logic_vector(15 downto 0);
    variable ydest : std_logic_vector(15 downto 0);
    variable xsrc  : std_logic_vector(15 downto 0);
    variable ysrc  : std_logic_vector(15 downto 0);

    -- control-word bit positions (assumed from your diagram)
    constant C_TYPE_LSB   : natural := 0;
    constant C_OP_LSB     : natural := 1;
    constant C_STATUS_LSB : natural := 2;
    constant C_STATUS_MSB : natural := C_STATUS_LSB + c_AXI_RESP_WIDTH - 1;
    constant C_BURST_LSB  : natural := C_STATUS_MSB + 1;
    constant C_BURST_MSB  : natural := C_BURST_LSB + 1;
    constant C_LEN_LSB    : natural := C_BURST_MSB + 1;
    constant C_LEN_MSB    : natural := C_LEN_LSB + 7;
    constant C_ID_LSB     : natural := C_LEN_MSB + 1;
    constant C_ID_MSB     : natural := C_ID_LSB + c_AXI_ID_WIDTH - 1;

    variable req_len   : unsigned(7 downto 0);
    variable payload_n : natural;

    -- response buffer
    variable resp_mem : flit_mem_t;
    variable resp_len_flits : natural := 0;
    variable resp_idx : natural := 0;

    -- local helpers
    variable w : std_logic_vector(31 downto 0);
    variable checksum : std_logic_vector(31 downto 0);

    -- bookkeeping
    variable pkt_count : natural := 0;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        req_word_cnt := 0;
        req_expected_words := 0;
        resp_len_flits := 0;
        resp_idx := 0;
        l_out_val_o <= '0';
        l_out_data_o <= (others => '0');
        pkt_count := 0;

      else
        -- default drive for response sender
        if resp_idx < resp_len_flits then
          l_out_val_o  <= '1';
          l_out_data_o <= resp_mem(resp_idx);
          if l_out_ack_i = '1' then
            resp_idx := resp_idx + 1;
          end if;
        else
          l_out_val_o  <= '0';
          l_out_data_o <= (others => '0');
        end if;

        -- Capture outgoing flits (manager -> NoC)
        if (l_in_val_i = '1') and (l_in_ack_o = '1') then
          w := flit_word(l_in_data_i);

          -- pack the word into req_words vector (LSB word-first)
          req_words(req_word_cnt*32 + 31 downto req_word_cnt*32) := w;
          req_word_cnt := req_word_cnt + 1;

          -- Once we captured word2 (ctrl word), compute expected request size.
          -- Request format: [hdr0][hdr1][ctrl][addr][payload(0..n)][checksum]
          if req_word_cnt = 3 then
            ctrlw := w;
            req_len := unsigned(ctrlw(C_LEN_MSB downto C_LEN_LSB));
            payload_n := to_integer(req_len) + 1; -- AXI LEN semantics
            req_expected_words := 4 + payload_n + 1; -- 4 header words incl addr + payload + checksum
          end if;

          -- If we know how many words to expect, and we captured them all, build response.
          if (req_expected_words /= 0) and (req_word_cnt = req_expected_words) then
            header0 := req_words(0*32 + 31 downto 0*32);
            header1 := req_words(1*32 + 31 downto 1*32);
            ctrlw   := req_words(2*32 + 31 downto 2*32);

            xdest := header0(31 downto 16);
            ydest := header0(15 downto 0);
            xsrc  := header1(31 downto 16);
            ysrc  := header1(15 downto 0);

            payload_n := (req_expected_words - 5); -- request: hdr0 hdr1 ctrl addr + payload_n + checksum

            -- ===== Build response packet =====
            -- Response format: [hdr0][hdr1][ctrl][payload(0..n)][checksum]
            -- hdr0: dest=original src
            resp_mem(0) := mk_flit('1', xsrc & ysrc);
            -- hdr1: src=original dest
            resp_mem(1) := mk_flit('0', xdest & ydest);

            -- ctrl word: mirror ID/LEN/BURST/OP; set STATUS=OKAY (0s) and TYPE=1 (response)
            -- start from zeros to avoid carrying reserved bits with unknown meaning
            w := (others => '0');
            w(C_ID_MSB downto C_ID_LSB) := ctrlw(C_ID_MSB downto C_ID_LSB);
            w(C_LEN_MSB downto C_LEN_LSB) := ctrlw(C_LEN_MSB downto C_LEN_LSB);
            w(C_BURST_MSB downto C_BURST_LSB) := ctrlw(C_BURST_MSB downto C_BURST_LSB);
            w(C_OP_LSB) := ctrlw(C_OP_LSB);
            -- STATUS = 0 (OKAY)
            w(C_STATUS_MSB downto C_STATUS_LSB) := (others => '0');
            -- TYPE = 1 (response)
            w(C_TYPE_LSB) := '1';
            resp_mem(2) := mk_flit('0', w);

            -- payload echo (copy payload words from request)
            -- request payload starts at word index 4 (0:hdr0,1:hdr1,2:ctrl,3:addr,4:payload0,...)
            for i in 0 to payload_n - 1 loop
              w := req_words((4+i)*32 + 31 downto (4+i)*32);
              resp_mem(3+i) := mk_flit('0', w);
            end loop;

            -- checksum (simple XOR of all response words)
            checksum := (others => '0');
            checksum := checksum xor (xsrc & ysrc);
            checksum := checksum xor (xdest & ydest);
            checksum := checksum xor resp_mem(2)(31 downto 0);
            for i in 0 to payload_n - 1 loop
              checksum := checksum xor resp_mem(3+i)(31 downto 0);
            end loop;
            resp_mem(3+payload_n) := mk_flit('1', checksum);

            resp_len_flits := 4 + payload_n; -- hdr0,hdr1,ctrl,payload_n,checksum
            resp_idx := 0;

            pkt_count := pkt_count + 1;

            -- Print progression (payload[0] is what we loop back)
            w := req_words(4*32 + 31 downto 4*32);
            report "REQ pkt=" & integer'image(pkt_count) &
                   " payload0=0x" & to_hstring(w) &
                   " tg_dbg=0x" & to_hstring(o_tg_lfsr_value) &
                   " corrupt=" & std_logic'image(o_corrupt_packet);

            -- reset request capture for next packet
            req_word_cnt := 0;
            req_expected_words := 0;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- =====================
  -- Stimulus / sequencing
  -- =====================
  stim: process
    variable done_count : natural := 0;
  begin
    -- reset
    ARESETn <= '0';
    i_tg_start <= '0';
    i_tg_ext_update_en <= '0';
    i_tg_ext_data_in <= (others => '0');

    -- Choose an address (destination encoding depends on your system; this is a safe placeholder)
    -- If your NI routes based on Xdest/Ydest encoded in the address, set these bits accordingly.
    i_tg_address <= x"0000000000001000";

    -- Seed for the LFSR
    i_tg_seed <= x"12345678";

    wait for 10*c_CLK_PERIOD;
    ARESETn <= '1';
    wait for 10*c_CLK_PERIOD;

    -- Run 5 transactions. Hold start high until done, then wait a gap.
    for k in 1 to 5 loop
      i_tg_start <= '1';
      wait until rising_edge(ACLK);

      wait until o_tg_done = '1';
      done_count := done_count + 1;
      report "TG DONE " & integer'image(done_count) &
             " lfsr_dbg=0x" & to_hstring(o_tg_lfsr_value);

      i_tg_start <= '0';
      wait for 20*c_CLK_PERIOD;
    end loop;

    report "Simulation finished after 5 transactions." severity note;
    wait for 50*c_CLK_PERIOD;
    assert false report "End of TB" severity failure;
  end process;

end architecture;
