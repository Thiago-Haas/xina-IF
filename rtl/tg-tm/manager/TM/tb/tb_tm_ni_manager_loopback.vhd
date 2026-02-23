library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- VHDL-2008 simulation control
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TB: TM read -> NI manager, with a simple NoC-side loopback (subordinate emulation).
--
-- Mirrors the working TG/manager loopback TB behaviour:
--  * NI -> TB: lin_val/lin_data, TB acks with 1-cycle pulses on lin_ack.
--  * TB -> NI: lout_val/lout_data held until lout_ack; TB inserts a 1-cycle VAL-low gap
--              between flits to create clear beat boundaries (robust for pulse-based ACK logic).
--
-- For READ transactions, the response includes payload words. Here we generate them
-- deterministically using the SAME 32-bit LFSR step used by tm_read_lfsr, seeded by
-- STARTING_SEED given to the TM.
entity tb_tm_ni_manager_loopback is
end entity;

architecture tb of tb_tm_ni_manager_loopback is
  constant c_CLK_PERIOD : time := 10 ns;

  constant c_NUM_ITERS      : natural := 20;
  constant c_GAP_CYCLES     : natural := 2;
  constant c_TIMEOUT_CYCLES : natural := 50000;

  -- Optional fault injection (payload bit flip) to validate mismatch detection.
  constant c_INJECT_MISMATCH_EN  : boolean := false;
  constant c_INJECT_MISMATCH_AT  : natural := 3; -- transaction index (0-based)
  constant c_INJECT_MISMATCH_BIT : natural := 0; -- bit to flip in first payload word

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TM control
  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;
  signal input_address : std_logic_vector(63 downto 0) := (others => '0');
  signal starting_seed : std_logic_vector(31 downto 0) := (others => '0');

  -- TM observation ports (non-debug top)
  signal tm_mismatch       : std_logic;
  signal tm_expected_value : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- NoC side (NI injection = lin_*, NI ejection = lout_*)
  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic := '0';  -- IMPORTANT: pulse per flit

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lout_val  : std_logic := '0';
  signal lout_ack  : std_logic;

  -- hdr2 bit positions (must match NI decode)
  constant c_TYPE_BIT      : integer := 0;   -- always 0 in NI packetizer; kept for completeness
  constant c_OPC_BIT       : integer := 1;   -- 0=write, 1=read
  constant c_STATUS_LSB    : integer := 2;
  constant c_STATUS_MSB    : integer := 4;
  constant c_BURST_LSB     : integer := 5;
  constant c_BURST_MSB     : integer := 6;
  constant c_LENGTH_LSB    : integer := 7;
  constant c_LENGTH_MSB    : integer := 14;
  constant c_ID_LSB        : integer := 15;
  constant c_ID_MSB        : integer := 19;

  -- flit helpers
  function mk_flit(ctrl : std_logic; w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  begin
    f(f'left) := ctrl;           -- ctrl at MSB
    f(31 downto 0) := w;
    return f;
  end function;

  subtype t_flit is std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  constant c_MAX_FLITS : natural := 32;
  type t_pkt is array(0 to c_MAX_FLITS-1) of t_flit;

  function flit_ctrl(f : t_flit) return std_logic is
  begin
    return f(f'left);
  end function;

  -- 32-bit hex formatting (no std_logic_textio dependency)
  function hex32(v : std_logic_vector(31 downto 0)) return string is
    constant H : string := "0123456789ABCDEF";
    variable r : string(1 to 8);
    variable nib : unsigned(3 downto 0);
  begin
    for i in 0 to 7 loop
      nib := unsigned(v(31 - i*4 downto 28 - i*4));
      r(i+1) := H(to_integer(nib) + 1);
    end loop;
    return r;
  end function;

  -- tm_read_lfsr equivalent (32-bit)
  function next_lfsr32(v : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable fb : std_logic;
  begin
    fb := v(31) xor v(30) xor v(28) xor v(27);
    return v(30 downto 0) & fb;
  end function;

  signal sim_done : std_logic := '0';

begin
  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT (non-debug top)
  u_dut: entity work.tm_ni_read_only_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start       => tm_start,
      o_done        => tm_done,
      INPUT_ADDRESS => input_address,
      STARTING_SEED => starting_seed,

      o_mismatch       => tm_mismatch,
      o_expected_value => tm_expected_value,

      l_in_data_o => lin_data,
      l_in_val_o  => lin_val,
      l_in_ack_i  => lin_ack,

      l_out_data_i => lout_data,
      l_out_val_i  => lout_val,
      l_out_ack_o  => lout_ack
    );

  ---------------------------------------------------------------------------
  -- NoC loopback (subordinate) emulator
  ---------------------------------------------------------------------------
  noc_loopback: process
    variable req  : t_pkt;
    variable req_len  : natural;

    variable req_hdr0 : std_logic_vector(31 downto 0);
    variable req_hdr1 : std_logic_vector(31 downto 0);
    variable req_hdr2 : std_logic_vector(31 downto 0);

    variable req_type : std_logic;
    variable req_opc  : std_logic;
    variable req_len_field : unsigned(7 downto 0);
    variable req_id_field  : unsigned(4 downto 0);
    variable req_burst     : std_logic_vector(1 downto 0);

    variable resp_hdr0 : std_logic_vector(31 downto 0);
    variable resp_hdr1 : std_logic_vector(31 downto 0);
    variable resp_hdr2 : std_logic_vector(31 downto 0);

    variable payload_words : natural;

    variable cyc : natural;
    variable lfsr_v : std_logic_vector(31 downto 0);
    variable txn_idx : natural := 0;
    variable word : std_logic_vector(31 downto 0);

    -- Accept one request flit (NI->TB) then pulse ACK for one cycle.
    procedure accept_one_req_flit(variable dst : out t_flit; constant idx : in natural) is
    begin
      cyc := 0;
      while lin_val /= '1' loop
        wait until rising_edge(ACLK);
        if sim_done = '1' then
          dst := (others => '0');
          return;
        end if;
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lin_val (request flit)" severity failure;
        end if;
      end loop;

      wait for 1 ns; -- sample stable
      dst := lin_data;

      lin_ack <= '1';
      wait until rising_edge(ACLK);
      lin_ack <= '0';
      wait until rising_edge(ACLK);
    end procedure;

    -- Send one response flit (TB->NI): robust beat delimiting.
    procedure send_resp_flit(constant f : in t_flit) is
    begin
      -- wait ack low (beat boundary)
      cyc := 0;
      while lout_ack = '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack deassert" severity failure;
        end if;
      end loop;

      lout_val  <= '1';
      lout_data <= f;

      cyc := 0;
      while lout_ack /= '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack assert" severity failure;
        end if;
      end loop;

      -- drop VAL for one cycle
      lout_val  <= '0';
      lout_data <= (others => '0');
      wait until rising_edge(ACLK);
    end procedure;

  begin
    lin_ack   <= '0';
    lout_val  <= '0';
    lout_data <= (others => '0');

    wait until ARESETn = '1';
    wait until rising_edge(ACLK);

    while sim_done = '0' loop
      ---------------------------------------------------------------------
      -- Capture one full request packet, stop on checksum flit (ctrl='1')
      ---------------------------------------------------------------------
      req_len := 0;

      accept_one_req_flit(req(0), 0);
      if sim_done = '1' then
        exit;
      end if;
      assert flit_ctrl(req(0)) = '1'
        report "Expected ctrl=1 on hdr0" severity failure;
      req_len := 1;

      while req_len < c_MAX_FLITS loop
        accept_one_req_flit(req(req_len), req_len);
        if sim_done = '1' then
          exit;
        end if;
        req_len := req_len + 1;
        exit when flit_ctrl(req(req_len-1)) = '1';
      end loop;

      assert req_len < c_MAX_FLITS
        report "Request packet too long (no checksum delimiter)" severity failure;

      assert req_len >= 3 report "Request packet too short" severity failure;

      req_hdr0 := req(0)(31 downto 0);
      req_hdr1 := req(1)(31 downto 0);
      req_hdr2 := req(2)(31 downto 0);

      req_type      := req_hdr2(c_TYPE_BIT);
      req_opc       := req_hdr2(c_OPC_BIT);
      req_len_field := unsigned(req_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB));
      req_id_field  := unsigned(req_hdr2(c_ID_MSB downto c_ID_LSB));
      req_burst     := req_hdr2(c_BURST_MSB downto c_BURST_LSB);

      report "RX pkt: flits=" & integer'image(integer(req_len)) &
             " hdr0=0x" & hex32(req_hdr0) &
             " hdr1=0x" & hex32(req_hdr1) &
             " hdr2=0x" & hex32(req_hdr2) &
             " TYPE=" & std_logic'image(req_type) &
             " OPC=" & std_logic'image(req_opc) &
             " ID=" & integer'image(to_integer(req_id_field)) &
             " LEN=" & integer'image(to_integer(req_len_field)) &
             " BURST=" & integer'image(to_integer(unsigned(req_burst)))
        severity note;

      -- Expect READ request
      assert req_opc = '1' report "Expected OPC=1 (read)" severity failure;

      ---------------------------------------------------------------------
      -- Build READ response
      --  swap hdr0/hdr1, keep hdr2 (OPC=1, LEN/ID/BURST), set STATUS=000, keep bit0 as-is
      ---------------------------------------------------------------------
      resp_hdr0 := req_hdr1;
      resp_hdr1 := req_hdr0;

      resp_hdr2 := req_hdr2;
      resp_hdr2(c_STATUS_MSB downto c_STATUS_LSB) := (others => '0'); -- OKAY/0

      payload_words := to_integer(req_len_field) + 1;

      report "RESP build: hdr0=0x" & hex32(resp_hdr0) &
             " hdr1=0x" & hex32(resp_hdr1) &
             " hdr2=0x" & hex32(resp_hdr2) &
             " payload_words=" & integer'image(integer(payload_words))
        severity note;

      ---------------------------------------------------------------------
      -- Send response packet
      --  hdr0(ctrl=1), hdr1, hdr2, payload[0..LEN], checksum(ctrl=1)
      ---------------------------------------------------------------------
      -- small gap to allow NI/TM to settle RREADY before we start feeding the response
      for i in 0 to 3 loop
        wait until rising_edge(ACLK);
      end loop;

      send_resp_flit(mk_flit('1', resp_hdr0));
      send_resp_flit(mk_flit('0', resp_hdr1));
      send_resp_flit(mk_flit('0', resp_hdr2));

      -- payload generated by LFSR (seeded by STARTING_SEED each transaction in this simple TB)
      lfsr_v := next_lfsr32(starting_seed);
      for p in 0 to integer(payload_words)-1 loop
        word := lfsr_v;
        if c_INJECT_MISMATCH_EN and (txn_idx = c_INJECT_MISMATCH_AT) and (p = 0) then
          word(c_INJECT_MISMATCH_BIT) := not word(c_INJECT_MISMATCH_BIT);
        end if;

        send_resp_flit(mk_flit('0', word));
        lfsr_v := next_lfsr32(lfsr_v);
      end loop;

      send_resp_flit(mk_flit('1', (others => '0'))); -- checksum delimiter (integrity disabled)

      txn_idx := txn_idx + 1;
      wait until rising_edge(ACLK);
    end loop;

    lout_val  <= '0';
    lout_data <= (others => '0');
    lin_ack   <= '0';
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- Stimulus: multiple iterations
  ---------------------------------------------------------------------------
  stim: process
    variable cyc : natural;
  begin
    tm_start      <= '0';
    input_address <= x"0000_0000_0000_0100";
    starting_seed <= x"1ACE_B00C";

    -- reset
    ARESETn <= '0';
    wait for 100 ns;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    for it in 0 to integer(c_NUM_ITERS)-1 loop
      -- start pulse
      tm_start <= '1';
      wait until rising_edge(ACLK);
      tm_start <= '0';

      -- wait done
      cyc := 0;
      while tm_done /= '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting tm_done at iter=" & integer'image(it) severity failure;
        end if;
      end loop;

      -- gap between transactions
      for g in 0 to integer(c_GAP_CYCLES)-1 loop
        wait until rising_edge(ACLK);
      end loop;

      input_address <= std_logic_vector(unsigned(input_address) + 16);
    end loop;

    sim_done <= '1';
    wait for 50 ns;
    report "End of simulation" severity note;
    stop;
    wait;
  end process;

end architecture;
