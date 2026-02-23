library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TB: TM read -> NI manager, with a simple NoC-side loopback (subordinate emulation).
--
-- This mirrors the working TG/manager loopback TB behaviour:
--  * l_in_val/l_in_data come from NI (packetized request). TB acks with 1-cycle pulses.
--  * TB answers on l_out_val/l_out_data and waits for l_out_ack from NI.
--
-- For READ transactions, the response includes payload words. Here we generate them
-- deterministically using the SAME 32-bit LFSR step used by tm_read_lfsr, seeded by
-- STARTING_SEED given to the TM.

entity tb_tm_ni_manager_loopback is
end entity;

architecture tb of tb_tm_ni_manager_loopback is

  constant c_CLK_PERIOD : time := 10 ns;

  constant c_NUM_ITERS      : natural := 20;
  constant c_TIMEOUT_CYCLES : natural := 50000;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TM control
  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;
  signal input_address : std_logic_vector(63 downto 0) := (others => '0');
  signal starting_seed : std_logic_vector(31 downto 0) := (others => '0');

  signal tm_mismatch       : std_logic;
  signal tm_expected_value : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- NoC side (NI injection = l_in_*, NI ejection = l_out_*)
  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic := '0';  -- IMPORTANT: pulse per flit

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lout_val  : std_logic := '0';
  signal lout_ack  : std_logic;

  -- hdr2 bit positions (must match NI decode)
  constant c_TYPE_BIT      : integer := 0;   -- 0=req, 1=resp
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

  -- DUT
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
    variable resp_idx : natural;

    variable cyc : natural;
    variable lfsr_v : std_logic_vector(31 downto 0);

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

      wait for 1 ns;
      dst := lin_data;

      lin_ack <= '1';
      wait until rising_edge(ACLK);
      lin_ack <= '0';
      wait until rising_edge(ACLK);
    end procedure;

    procedure send_resp_flit(constant f : in t_flit) is
    begin
      lout_val  <= '1';
      lout_data <= f;
      cyc := 0;
      loop
        wait until rising_edge(ACLK);
        exit when lout_ack = '1';
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack (response flit)" severity failure;
        end if;
      end loop;
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

      -- hdr0
      accept_one_req_flit(req(0), 0);
      if sim_done = '1' then
        exit;
      end if;
      assert flit_ctrl(req(0)) = '1'
        report "Expected ctrl=1 on hdr0" severity failure;
      req_len := 1;

      -- capture until checksum (ctrl='1')
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

      -- decode headers
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

      -- we only support READ requests here
      assert req_type = '0' report "Expected TYPE=0 (request)" severity failure;
      assert req_opc  = '1' report "Expected OPC=1 (read)" severity failure;

      ---------------------------------------------------------------------
      -- Build READ response
      --  resp hdr0/hdr1 swapped, hdr2 type=1, status=0, keep OPC/ID/LEN/BURST
      ---------------------------------------------------------------------
      resp_hdr0 := req_hdr1;
      resp_hdr1 := req_hdr0;

      resp_hdr2 := req_hdr2;
      resp_hdr2(c_TYPE_BIT) := '1';
      resp_hdr2(c_STATUS_MSB downto c_STATUS_LSB) := (others => '0');

      payload_words := to_integer(req_len_field) + 1;

      report "RESP build: hdr0=0x" & hex32(resp_hdr0) &
             " hdr1=0x" & hex32(resp_hdr1) &
             " hdr2=0x" & hex32(resp_hdr2) &
             " payload_words=" & integer'image(integer(payload_words))
        severity note;

      ---------------------------------------------------------------------
      -- Send response packet
      --  hdr0(ctrl=1), hdr1, hdr2, payload[0..LEN], checksum(ctrl=1)
      --  checksum word is ZERO (integrity disabled)
      ---------------------------------------------------------------------
      resp_idx := 0;

      -- small gap to let TM/NI assert RREADY before we start feeding the response
      for i in 0 to 3 loop
        wait until rising_edge(ACLK);
      end loop;

      send_resp_flit(mk_flit('1', resp_hdr0));
      resp_idx := resp_idx + 1;

      send_resp_flit(mk_flit('0', resp_hdr1));
      resp_idx := resp_idx + 1;

      send_resp_flit(mk_flit('0', resp_hdr2));
      resp_idx := resp_idx + 1;

      -- payload generated by LFSR (seeded by STARTING_SEED)
      lfsr_v := next_lfsr32(starting_seed);
      for p in 0 to integer(payload_words)-1 loop
        send_resp_flit(mk_flit('0', lfsr_v));
        resp_idx := resp_idx + 1;
        lfsr_v := next_lfsr32(lfsr_v);
      end loop;

      -- checksum delimiter
      send_resp_flit(mk_flit('1', (others => '0')));
      resp_idx := resp_idx + 1;

      -- release bus
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
      report "=== ITER " & integer'image(it) & " START: addr=0x" & hex32(input_address(31 downto 0)) &
             " seed=0x" & hex32(starting_seed) & " ===" severity note;

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

      if tm_mismatch = '1' then
        report "*** MISMATCH asserted at iter=" & integer'image(it) & " expected=0x" & hex32(tm_expected_value(31 downto 0)) severity warning;
      else
        report "=== ITER " & integer'image(it) & " DONE (OK) ===" severity note;
      end if;

      -- small gap
      wait until rising_edge(ACLK);
      wait until rising_edge(ACLK);

      -- vary address/seed
      input_address <= std_logic_vector(unsigned(input_address) + 16);
      starting_seed <= std_logic_vector(unsigned(starting_seed) + 1);
    end loop;

    sim_done <= '1';
    report "TB completed" severity note;
    wait for 50 ns;
    assert false report "End of simulation" severity failure;
  end process;

end architecture;
