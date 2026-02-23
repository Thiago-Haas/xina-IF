library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- VHDL-2008 simulation control
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TB: TM read master -> NI manager, with a NoC-side loopback/subordinate emulator.
-- DEBUG VERSION:
--  * Prints TM FSM state transitions and AXI AR/R handshakes
--  * Captures NI->NoC request packet and injects a READ response with LFSR payload
--
-- Handshake semantics (IMPORTANT):
--  * lin_ack is a 1-cycle PULSE per accepted flit (VALID/ACK pulse).
--  * For TB->NI response, we delimit each flit:
--      - wait lout_ack low
--      - assert lout_val with flit until lout_ack goes high
--      - deassert lout_val for 1 cycle (beat boundary)
entity tb_tm_ni_manager_loopback_dbg is
end entity;

architecture tb of tb_tm_ni_manager_loopback_dbg is
  constant c_CLK_PERIOD : time := 10 ns;
  constant c_TIMEOUT_CYCLES : natural := 50000;
  constant c_NUM_ITERS      : natural := 20;
  constant c_GAP_CYCLES     : natural := 2;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TM control
  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;
  signal input_address : std_logic_vector(63 downto 0) := (others => '0');
  signal starting_seed : std_logic_vector(31 downto 0) := (others => '0');

  -- NoC side
  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic := '0';

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lout_val  : std_logic := '0';
  signal lout_ack  : std_logic;

  -- Debug wires from top
  signal dbg_arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal dbg_araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal dbg_arlen   : std_logic_vector(7 downto 0);
  signal dbg_arburst : std_logic_vector(1 downto 0);
  signal dbg_arvalid : std_logic;
  signal dbg_arready : std_logic;

  signal dbg_rvalid  : std_logic;
  signal dbg_rready  : std_logic;
  signal dbg_rdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dbg_rlast   : std_logic;
  signal dbg_rid     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal dbg_rresp   : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal dbg_tm_state : std_logic_vector(1 downto 0);
  signal dbg_tm_ar_hs : std_logic;
  signal dbg_tm_r_hs  : std_logic;
  signal dbg_tm_last_hs : std_logic;
  signal dbg_tm_txn_start_pulse : std_logic;
  signal dbg_tm_rbeat_pulse     : std_logic;
  signal dbg_tm_arvalid         : std_logic;
  signal dbg_tm_rready          : std_logic;

  signal dbg_dp_seeded : std_logic;
  signal dbg_dp_do_init : std_logic;
  signal dbg_dp_do_step : std_logic;
  signal dbg_dp_expected : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dbg_dp_mismatch : std_logic;

  signal dbg_corrupt : std_logic;

  signal sim_done : std_logic := '0';

  -- Helpers
  constant c_DIAG_ENABLE : boolean := true;

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

  function hex_lo32(v : std_logic_vector) return string is
    variable lo : std_logic_vector(31 downto 0) := (others => '0');
  begin
    if v'length >= 32 then
      lo := v(31 downto 0);
    else
      lo(v'length-1 downto 0) := v;
    end if;
    return hex32(lo);
  end function;

  function hex_hi32(v : std_logic_vector) return string is
    variable hi : std_logic_vector(31 downto 0) := (others => '0');
  begin
    if v'length > 32 then
      hi := v(v'length-1 downto 32);
    end if;
    return hex32(hi);
  end function;

  procedure dbg(constant msg : in string) is
  begin
    if c_DIAG_ENABLE then
      report "t=" & time'image(now) & "  " & msg severity note;
    end if;
  end procedure;

  subtype t_flit is std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  constant c_MAX_FLITS : natural := 32;
  type t_pkt is array(0 to c_MAX_FLITS-1) of t_flit;

  function flit_ctrl(f : t_flit) return std_logic is
  begin
    return f(f'left);
  end function;

  function mk_flit(ctrl : std_logic; w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  begin
    f(f'left) := ctrl;
    f(31 downto 0) := w;
    return f;
  end function;

  -- LFSR next (must match tm_read_lfsr)
  function next_lfsr32(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v  : std_logic_vector(31 downto 0) := x;
    variable fb : std_logic;
  begin
    fb := v(31) xor v(30) xor v(28) xor v(27);
    v  := v(30 downto 0) & fb;
    return v;
  end function;

begin
  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  u_dut: entity work.tm_ni_read_only_top_dbg
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start       => tm_start,
      o_done        => tm_done,
      INPUT_ADDRESS => input_address,
      STARTING_SEED => starting_seed,

      l_in_data_o => lin_data,
      l_in_val_o  => lin_val,
      l_in_ack_i  => lin_ack,

      l_out_data_i => lout_data,
      l_out_val_i  => lout_val,
      l_out_ack_o  => lout_ack,

      o_dbg_axi_arid    => dbg_arid,
      o_dbg_axi_araddr  => dbg_araddr,
      o_dbg_axi_arlen   => dbg_arlen,
      o_dbg_axi_arburst => dbg_arburst,
      o_dbg_axi_arvalid => dbg_arvalid,
      o_dbg_axi_arready => dbg_arready,

      o_dbg_axi_rvalid  => dbg_rvalid,
      o_dbg_axi_rready  => dbg_rready,
      o_dbg_axi_rdata   => dbg_rdata,
      o_dbg_axi_rlast   => dbg_rlast,
      o_dbg_axi_rid     => dbg_rid,
      o_dbg_axi_rresp   => dbg_rresp,

      o_dbg_tm_state       => dbg_tm_state,
      o_dbg_tm_ar_hs       => dbg_tm_ar_hs,
      o_dbg_tm_r_hs        => dbg_tm_r_hs,
      o_dbg_tm_last_hs     => dbg_tm_last_hs,
      o_dbg_tm_txn_start_pulse => dbg_tm_txn_start_pulse,
      o_dbg_tm_rbeat_pulse     => dbg_tm_rbeat_pulse,
      o_dbg_tm_arvalid     => dbg_tm_arvalid,
      o_dbg_tm_rready      => dbg_tm_rready,

      o_dbg_dp_seeded       => dbg_dp_seeded,
      o_dbg_dp_do_init      => dbg_dp_do_init,
      o_dbg_dp_do_step      => dbg_dp_do_step,
      o_dbg_dp_init_value   => open,
      o_dbg_dp_lfsr_input   => open,
      o_dbg_dp_lfsr_next    => open,
      o_dbg_dp_lfsr_in_reg  => open,
      o_dbg_dp_expected_reg => dbg_dp_expected,
      o_dbg_dp_mismatch     => dbg_dp_mismatch,

      o_dbg_expected_value  => open,

      o_dbg_corrupt_packet  => dbg_corrupt
    );

  ---------------------------------------------------------------------------
  -- Monitor: state changes + AXI handshakes
  ---------------------------------------------------------------------------
  monitor: process
    variable prev_state : std_logic_vector(1 downto 0) := (others => 'X');
    variable stall_cnt : natural := 0;
  begin
    wait until ARESETn = '1';
    wait until rising_edge(ACLK);

    while sim_done = '0' loop
      wait until rising_edge(ACLK);

      if dbg_tm_state /= prev_state then
        dbg("TM STATE " & std_logic'image(prev_state(1)) & std_logic'image(prev_state(0)) &
            " -> " & std_logic'image(dbg_tm_state(1)) & std_logic'image(dbg_tm_state(0)) &
            " | ARV/ARR=" & std_logic'image(dbg_arvalid) & "/" & std_logic'image(dbg_arready) &
            " RV/RR=" & std_logic'image(dbg_rvalid) & "/" & std_logic'image(dbg_rready) &
            " RLAST=" & std_logic'image(dbg_rlast) &
            " corrupt=" & std_logic'image(dbg_corrupt));
        prev_state := dbg_tm_state;
      end if;

      if dbg_tm_ar_hs = '1' then
        dbg("AXI AR_HS: arid=" & integer'image(to_integer(unsigned(dbg_arid))) &
            " araddr_hi=0x" & hex_hi32(dbg_araddr) &
            " araddr_lo=0x" & hex_lo32(dbg_araddr) &
            " arlen=" & integer'image(to_integer(unsigned(dbg_arlen))) &
            " arburst=" & integer'image(to_integer(unsigned(dbg_arburst))));
      end if;

      if dbg_tm_r_hs = '1' then
        dbg("AXI R_HS: rid=" & integer'image(to_integer(unsigned(dbg_rid))) &
            " rresp=" & integer'image(to_integer(unsigned(dbg_rresp))) &
            " rlast=" & std_logic'image(dbg_rlast) &
            " rdata_lo=0x" & hex_lo32(dbg_rdata) &
            " exp_lo=0x" & hex_lo32(dbg_dp_expected) &
            " mismatch=" & std_logic'image(dbg_dp_mismatch));
      end if;

      -- crude stall detection (no NoC activity)
      if (lin_val = '1') or (lout_val = '1') then
        stall_cnt := 0;
      else
        stall_cnt := stall_cnt + 1;
      end if;

      if stall_cnt = 2000 then
        dbg("---- STALL SNAPSHOT ----");
        dbg("TM state=" & std_logic'image(dbg_tm_state(1)) & std_logic'image(dbg_tm_state(0)) &
            " ARV/ARR=" & std_logic'image(dbg_arvalid) & "/" & std_logic'image(dbg_arready) &
            " RV/RR=" & std_logic'image(dbg_rvalid) & "/" & std_logic'image(dbg_rready) &
            " RLAST=" & std_logic'image(dbg_rlast));
        dbg("NoC: lin_val=" & std_logic'image(lin_val) & " lin_ack=" & std_logic'image(lin_ack) &
            " | lout_val=" & std_logic'image(lout_val) & " lout_ack=" & std_logic'image(lout_ack));
      end if;
    end loop;
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- NoC loopback emulator (READ response with LFSR payload)
  ---------------------------------------------------------------------------
  noc_loopback: process
    variable req : t_pkt;
    variable req_len : natural;
    variable hdr0, hdr1, hdr2 : std_logic_vector(31 downto 0);
    variable resp0, resp1, resp2 : std_logic_vector(31 downto 0);
    variable len_field : unsigned(7 downto 0);
    variable payload_words : natural;
    variable word : std_logic_vector(31 downto 0);
    variable exp : std_logic_vector(31 downto 0);

    variable cyc : natural;

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

    procedure send_resp_flit(constant f : in t_flit; constant idx : in natural) is
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
      -- capture request until checksum ctrl=1
      req_len := 0;
      accept_one_req_flit(req(0), 0);
      req_len := 1;
      while req_len < c_MAX_FLITS loop
        accept_one_req_flit(req(req_len), req_len);
        req_len := req_len + 1;
        exit when flit_ctrl(req(req_len-1)) = '1';
      end loop;

      hdr0 := req(0)(31 downto 0);
      hdr1 := req(1)(31 downto 0);
      hdr2 := req(2)(31 downto 0);

      -- NI bit layout: LEN=14..7, BURST=6..5, STATUS=4..2, OPC=1, BIT0=0
      len_field := unsigned(hdr2(14 downto 7));
      payload_words := to_integer(len_field) + 1;

      dbg("RX pkt: flits=" & integer'image(integer(req_len)) &
          " hdr0=0x" & hex32(hdr0) &
          " hdr1=0x" & hex32(hdr1) &
          " hdr2=0x" & hex32(hdr2) &
          " OPC=" & std_logic'image(hdr2(1)) &
          " LEN=" & integer'image(to_integer(len_field)));

      -- Build READ response: swap hdr0/hdr1, keep hdr2 (OPC=1), status=000, bit0=0
      resp0 := hdr1;
      resp1 := hdr0;
      resp2 := hdr2;
      resp2(4 downto 2) := "000";
      resp2(0) := '0'; -- NI uses 0 here

      dbg("RESP build: hdr0=0x" & hex32(resp0) &
          " hdr1=0x" & hex32(resp1) &
          " hdr2=0x" & hex32(resp2) &
          " payload_words=" & integer'image(integer(payload_words)));

      -- seed expected sequence (matches tm_read_datapath): expected0 = next(seed)
      exp := next_lfsr32(starting_seed);

      -- Send response flits: hdr0(ctrl=1), hdr1, hdr2, payload..., checksum(ctrl=1)
      send_resp_flit(mk_flit('1', resp0), 0);
      send_resp_flit(mk_flit('0', resp1), 1);
      send_resp_flit(mk_flit('0', resp2), 2);

      for p in 0 to integer(payload_words)-1 loop
        word := exp;
        send_resp_flit(mk_flit('0', word), 3 + natural(p));
        exp := next_lfsr32(exp);
      end loop;

      send_resp_flit(mk_flit('1', (others => '0')), 3 + natural(payload_words));
    end loop;

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

    ARESETn <= '0';
    wait for 100 ns;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    for it in 0 to integer(c_NUM_ITERS)-1 loop
      dbg("=== ITER " & integer'image(it) & " START: addr=0x" & hex32(input_address(31 downto 0)) &
          " seed=0x" & hex32(starting_seed) & " ===");

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

      dbg("=== ITER " & integer'image(it) & " DONE (tm_done seen), mismatch=" &
          std_logic'image(dbg_dp_mismatch) & " ===");

      -- small gap between transactions
      for g in 0 to integer(c_GAP_CYCLES)-1 loop
        wait until rising_edge(ACLK);
      end loop;

      -- vary address/seed
      input_address <= std_logic_vector(unsigned(input_address) + 16);
      starting_seed <= std_logic_vector(unsigned(starting_seed) + 1);
    end loop;

    sim_done <= '1';
    wait for 50 ns;
    report "End of simulation" severity note;
    stop;
    wait;
end process;

end architecture;
