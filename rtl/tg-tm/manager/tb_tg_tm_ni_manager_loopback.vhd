library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- VHDL-2008 simulation control (optional)
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TB that combines TG(write) + TM(read) over a single NI (manager).
--
-- TB emulates the NoC/subordinate on the NI NoC-side ports:
--   * captures request packets emitted by the NI (lin_*)
--   * for WRITE requests: stores payload words in a simple RAM model and returns a WRITE response
--   * for READ requests : fetches words from the RAM model and returns a READ response with payload
--
-- Stimulus runs a sequence of iterations:
--   1) TG sends a write transaction
--   2) TM sends a read  transaction to the same address
--   3) TM compares returned data with its expected LFSR stream (must match TG stream)
entity tb_tg_tm_ni_manager_loopback is
end entity;

architecture tb of tb_tg_tm_ni_manager_loopback is

  constant c_CLK_PERIOD     : time := 10 ns;
  constant c_NUM_ITERS      : natural := 20;
  constant c_GAP_CYCLES     : natural := 2;
  constant c_TIMEOUT_CYCLES : natural := 50000;

  -- Simple RAM model sizing (word addressed)
  constant c_MEM_WORDS : natural := 4096;
  type t_mem is array(0 to c_MEM_WORDS-1) of std_logic_vector(31 downto 0);
  type t_memv is array(0 to c_MEM_WORDS-1) of std_logic;
  shared variable mem      : t_mem  := (others => (others => '0'));
  shared variable mem_valid: t_memv := (others => '0');

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TG control
  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;

  -- TM control
  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;

  signal input_address : std_logic_vector(63 downto 0) := (others => '0');
  signal starting_seed : std_logic_vector(31 downto 0) := (others => '0');

  signal tm_mismatch       : std_logic;
  signal tm_expected_value : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- NoC-side
  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic := '0';

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lout_val  : std_logic := '0';
  signal lout_ack  : std_logic;

  -- hdr2 bit positions (must match NI decode)
  constant c_TYPE_BIT      : integer := 0;
  constant c_OPC_BIT       : integer := 1;   -- 0=write, 1=read
  constant c_STATUS_LSB    : integer := 2;
  constant c_STATUS_MSB    : integer := 4;
  constant c_BURST_LSB     : integer := 5;
  constant c_BURST_MSB     : integer := 6;
  constant c_LENGTH_LSB    : integer := 7;
  constant c_LENGTH_MSB    : integer := 14;
  constant c_ID_LSB        : integer := 15;
  constant c_ID_MSB        : integer := 19;

  subtype t_flit is std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  constant c_MAX_FLITS : natural := 64;
  type t_pkt is array(0 to c_MAX_FLITS-1) of t_flit;

  function flit_ctrl(f : t_flit) return std_logic is
  begin
    return f(f'left);
  end function;

  function mk_flit(ctrl : std_logic; w : std_logic_vector(31 downto 0)) return t_flit is
    variable f : t_flit := (others => '0');
  begin
    f(f'left) := ctrl;
    f(31 downto 0) := w;
    return f;
  end function;

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

  function u16(x : unsigned(7 downto 0)) return unsigned is
    variable v : unsigned(15 downto 0);
  begin
    v := (others => '0');
    v(7 downto 0) := x;
    return v;
  end function;

  signal sim_done : std_logic := '0';

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  u_dut: entity work.tg_tm_ni_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start       => tg_start,
      o_tg_done        => tg_done,
      TG_INPUT_ADDRESS => input_address,
      TG_STARTING_SEED => starting_seed,

      i_tm_start       => tm_start,
      o_tm_done        => tm_done,
      TM_INPUT_ADDRESS => input_address,
      TM_STARTING_SEED => starting_seed,

      o_tm_mismatch       => tm_mismatch,
      o_tm_expected_value => tm_expected_value,

      l_in_data_o => lin_data,
      l_in_val_o  => lin_val,
      l_in_ack_i  => lin_ack,

      l_out_data_i => lout_data,
      l_out_val_i  => lout_val,
      l_out_ack_o  => lout_ack
    );

  ---------------------------------------------------------------------------
  -- NoC loopback / subordinate emulator
  ---------------------------------------------------------------------------
  noc_loopback: process
    variable req : t_pkt;
    variable req_len : natural;

    variable req_hdr0, req_hdr1, req_hdr2 : std_logic_vector(31 downto 0);
    variable req_opc  : std_logic;
    variable req_id   : std_logic_vector(4 downto 0);
    variable req_len_field : unsigned(7 downto 0);
    variable req_burst : std_logic_vector(1 downto 0);

    variable addr_w : std_logic_vector(31 downto 0);
    variable base_idx : natural;

    variable resp_hdr0, resp_hdr1, resp_hdr2 : std_logic_vector(31 downto 0);
    variable payload_words : natural;

    variable cyc : natural;

    procedure accept_one_req_flit(variable dst : out t_flit) is
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

      wait for 1 ns;
      dst := lin_data;

      -- 1-cycle ACK pulse per flit (matches previous working TBs)
      lin_ack <= '1';
      wait until rising_edge(ACLK);
      lin_ack <= '0';
      wait until rising_edge(ACLK);
    end procedure;

    procedure send_resp_flit(constant f : in t_flit) is
    begin
      -- Ensure previous ack is low
      cyc := 0;
      while lout_ack = '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack deassert (pre-flit)" severity failure;
        end if;
      end loop;

      lout_data <= f;
      lout_val  <= '1';

      cyc := 0;
      while lout_ack /= '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack assert (response flit)" severity failure;
        end if;
      end loop;

      -- Drop VAL for one full cycle (beat boundary)
      lout_val  <= '0';
      lout_data <= (others => '0');
      wait until rising_edge(ACLK);
    end procedure;

    function addr_to_idx(a : std_logic_vector(31 downto 0)) return natural is
      variable ua : unsigned(31 downto 0);
      variable w  : natural;
    begin
      ua := unsigned(a);
      -- word index = address >> 2 (byte addressing assumed)
      w := to_integer(ua(31 downto 2));
      return w mod c_MEM_WORDS;
    end function;

  begin
    lin_ack   <= '0';
    lout_val  <= '0';
    lout_data <= (others => '0');

    wait until ARESETn = '1';
    wait until rising_edge(ACLK);

    while sim_done = '0' loop
      -- Capture one full request packet, stopping on checksum flit (ctrl='1')
      req_len := 0;

      accept_one_req_flit(req(0));
      if sim_done = '1' then exit; end if;
      assert flit_ctrl(req(0)) = '1' report "Expected ctrl=1 on hdr0" severity failure;
      req_len := 1;

      while req_len < c_MAX_FLITS loop
        accept_one_req_flit(req(req_len));
        if sim_done = '1' then exit; end if;
        req_len := req_len + 1;
        exit when flit_ctrl(req(req_len-1)) = '1';
      end loop;

      assert req_len < c_MAX_FLITS report "Request too long (no checksum delimiter)" severity failure;
      assert req_len >= 5 report "Request too short" severity failure;

      req_hdr0 := req(0)(31 downto 0);
      req_hdr1 := req(1)(31 downto 0);
      req_hdr2 := req(2)(31 downto 0);

      req_opc  := req_hdr2(c_OPC_BIT);
      req_id   := req_hdr2(c_ID_MSB downto c_ID_LSB);
      req_len_field := unsigned(req_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB));
      req_burst := req_hdr2(c_BURST_MSB downto c_BURST_LSB);

      addr_w := req(3)(31 downto 0);
      base_idx := addr_to_idx(addr_w);

      report "RX req: flits=" & integer'image(integer(req_len)) &
             " OPC=" & std_logic'image(req_opc) &
             " ID=" & integer'image(to_integer(unsigned(req_id))) &
             " LEN=" & integer'image(to_integer(req_len_field)) &
             " ADDR=0x" & hex32(addr_w)
        severity note;

      -- Swap dest/src in response
      resp_hdr0 := req_hdr1;
      resp_hdr1 := req_hdr0;

      if req_opc = '0' then
        -------------------------------------------------------------------
        -- WRITE request: store payload and send WRITE response (no payload)
        -------------------------------------------------------------------
        payload_words := to_integer(u16(req_len_field)) + 1;

        -- Validate packet length: hdr0,hdr1,hdr2,addr,payload...,checksum
        assert req_len >= (4 + payload_words + 1)
          report "WRITE request length mismatch" severity failure;

        -- Store payload words to RAM
        for p in 0 to integer(payload_words)-1 loop
          if (base_idx + p) < c_MEM_WORDS then
            mem(base_idx + p) := req(4 + p)(31 downto 0);
            mem_valid(base_idx + p) := '1';
          else
            mem((base_idx + p) mod c_MEM_WORDS) := req(4 + p)(31 downto 0);
            mem_valid((base_idx + p) mod c_MEM_WORDS) := '1';
          end if;
        end loop;

        -- Build hdr2 for WRITE response
        resp_hdr2 := (others => '0');
        resp_hdr2(c_ID_MSB downto c_ID_LSB) := req_id;
        resp_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB) := (others => '0'); -- no payload
        resp_hdr2(c_BURST_MSB downto c_BURST_LSB) := req_burst;
        resp_hdr2(c_STATUS_MSB downto c_STATUS_LSB) := (others => '0'); -- OK
        resp_hdr2(c_OPC_BIT) := '0';
        resp_hdr2(c_TYPE_BIT) := '1';

        -- Send response: hdr0(ctrl=1), hdr1, hdr2, checksum(ctrl=1)
        send_resp_flit(mk_flit('1', resp_hdr0));
        send_resp_flit(mk_flit('0', resp_hdr1));
        send_resp_flit(mk_flit('0', resp_hdr2));
        send_resp_flit(mk_flit('1', (others => '0')));

      else
        -------------------------------------------------------------------
        -- READ request: send READ response with payload from RAM
        -------------------------------------------------------------------
        payload_words := to_integer(u16(req_len_field)) + 1;

        -- Build hdr2 for READ response (mirror LEN/ID/BURST, set TYPE=1, STATUS=OK)
        resp_hdr2 := req_hdr2;
        resp_hdr2(c_STATUS_MSB downto c_STATUS_LSB) := (others => '0');
        resp_hdr2(c_TYPE_BIT) := '1';
        resp_hdr2(c_OPC_BIT)  := '1';

        -- Small gap so NI/TM can assert RREADY before we start sending
        for i in 0 to 3 loop
          wait until rising_edge(ACLK);
        end loop;

        send_resp_flit(mk_flit('1', resp_hdr0));
        send_resp_flit(mk_flit('0', resp_hdr1));
        send_resp_flit(mk_flit('0', resp_hdr2));

        for p in 0 to integer(payload_words)-1 loop
          if mem_valid((base_idx + p) mod c_MEM_WORDS) = '1' then
            send_resp_flit(mk_flit('0', mem((base_idx + p) mod c_MEM_WORDS)));
          else
            report "WARN: READ of unwritten addr idx=" & integer'image(integer((base_idx+p) mod c_MEM_WORDS))
              severity warning;
            send_resp_flit(mk_flit('0', (others => '0')));
          end if;
        end loop;

        send_resp_flit(mk_flit('1', (others => '0')));
      end if;

      -- release
      lout_val  <= '0';
      lout_data <= (others => '0');
      wait until rising_edge(ACLK);
    end loop;

    lout_val  <= '0';
    lout_data <= (others => '0');
    lin_ack   <= '0';
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- Stimulus
  ---------------------------------------------------------------------------
  stim: process
    variable cyc : natural;
  begin
    tg_start      <= '0';
    tm_start      <= '0';

    input_address <= x"0000_0000_0000_0100";
    starting_seed <= x"1ACE_B00C";

    -- reset
    ARESETn <= '0';
    wait for 100 ns;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    -- Clear RAM
    for i in 0 to c_MEM_WORDS-1 loop
      mem(i) := (others => '0');
      mem_valid(i) := '0';
    end loop;

    for it in 0 to integer(c_NUM_ITERS)-1 loop
      -----------------------------------------------------------------------
      -- 1) WRITE (TG)
      -----------------------------------------------------------------------
      tg_start <= '1';
      wait until rising_edge(ACLK);
      tg_start <= '0';

      cyc := 0;
      while tg_done /= '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting tg_done at iter=" & integer'image(it) severity failure;
        end if;
      end loop;

      for g in 0 to integer(c_GAP_CYCLES)-1 loop
        wait until rising_edge(ACLK);
      end loop;

      -----------------------------------------------------------------------
      -- 2) READ (TM)
      -----------------------------------------------------------------------
      tm_start <= '1';
      wait until rising_edge(ACLK);
      tm_start <= '0';

      cyc := 0;
      while tm_done /= '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting tm_done at iter=" & integer'image(it) severity failure;
        end if;
      end loop;

      -- Check mismatch (sticky)
      assert tm_mismatch = '0'
        report "TM mismatch asserted at iter=" & integer'image(it) &
               " expected=0x" & hex32(tm_expected_value(31 downto 0))
        severity failure;

      for g in 0 to integer(c_GAP_CYCLES)-1 loop
        wait until rising_edge(ACLK);
      end loop;

      -- next address (keep seed constant; TG/TM seed only once after reset)
      input_address <= std_logic_vector(unsigned(input_address) + 16);
    end loop;

    sim_done <= '1';
    wait for 50 ns;
    report "TB completed OK" severity note;
    stop;
    wait;
  end process;

end architecture;
