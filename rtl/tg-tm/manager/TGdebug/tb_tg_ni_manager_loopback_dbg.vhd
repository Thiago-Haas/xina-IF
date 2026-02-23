library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TB: TG write manager -> NI manager, with a simple NoC-side loopback.
--
-- This TB captures the request packet emitted by the NI (TG->NI->NoC),
-- and then injects a synthetically-built RESPONSE packet back into the NI (NoC->NI),
-- so the NI can generate the AXI B channel response to the TG.
--
-- IMPORTANT (based on NI decode in backend_manager_reception/depacketizer_control):
--   * The "H_INTERFACE" word is the 3rd flit of the packet (hdr2).
--   * The NI uses:
--       ID     = H_INTERFACE(19 downto 15)
--       LENGTH = H_INTERFACE(14 downto 7)
--       BURST  = H_INTERFACE(6  downto 5)
--       STATUS = H_INTERFACE(4  downto 2)
--       OPC    = H_INTERFACE(1)     -- 0=WRITE, 1=READ
--       TYPE   = H_INTERFACE(0)     -- 0=REQ,   1=RESP
--   * Depacketizer selects WRITE-RESP vs READ-RESP solely by OPC (bit 1).
--     If OPC=1 it will wait for RREADY and payload flits (and your write-only top ties RREADY low),
--     so sending OPC=1 will stall forever.
--
-- WRITE RESPONSE packet (for a single-beat write) must be:
--   hdr0(ctrl=1), hdr1(ctrl=0), hdr2/H_INTERFACE(ctrl=0), checksum(ctrl=1)
--   with TYPE=1, OPC=0, STATUS=OK (typically "000"), LENGTH=0.
--
-- Entity name kept as *_dbg so you can keep multiple TB variants side-by-side.

entity tb_tg_ni_manager_loopback_dbg is
end entity;

architecture tb of tb_tg_ni_manager_loopback_dbg is

  constant c_CLK_PERIOD : time := 10 ns;

  constant c_NUM_ITERS      : natural := 20;
  constant c_TIMEOUT_CYCLES : natural := 50000;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TG control
  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;
  signal input_address : std_logic_vector(63 downto 0) := (others => '0');
  signal starting_seed : std_logic_vector(31 downto 0) := (others => '0');

  -- NoC side (NI injection = lin_*, NI ejection = lout_*)
  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic := '0';  -- pulse per flit

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lout_val  : std_logic := '0';
  signal lout_ack  : std_logic;

  -- ------------------------------------------------------------------
  -- Debug wires from top
  -- ------------------------------------------------------------------
  signal dbg_awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal dbg_awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal dbg_awlen   : std_logic_vector(7 downto 0);
  signal dbg_awburst : std_logic_vector(1 downto 0);
  signal dbg_awvalid : std_logic;
  signal dbg_awready : std_logic;

  signal dbg_wvalid  : std_logic;
  signal dbg_wready  : std_logic;
  signal dbg_wdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dbg_wlast   : std_logic;

  signal dbg_bid     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal dbg_bresp   : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal dbg_bvalid  : std_logic;
  signal dbg_bready  : std_logic;

  signal dbg_tg_state    : std_logic_vector(1 downto 0);
  signal dbg_tg_aw_hs    : std_logic;
  signal dbg_tg_w_hs     : std_logic;
  signal dbg_tg_b_hs     : std_logic;
  signal dbg_tg_bhs_seen : std_logic;
  signal dbg_corrupt     : std_logic;

  signal dbg_dp_seeded   : std_logic;
  signal dbg_dp_do_init  : std_logic;
  signal dbg_dp_do_step  : std_logic;
  signal dbg_dp_lfsr_in  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dbg_dp_lfsr_nxt : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  -- ------------------------------------------------------------------
  -- Packet bit positions (MUST match backend_manager_reception)
  -- ------------------------------------------------------------------
  constant c_TYPE_BIT     : integer := 0;
  constant c_OPC_BIT      : integer := 1;
  constant c_STATUS_LSB   : integer := 2;
  constant c_STATUS_MSB   : integer := 4;
  constant c_BURST_LSB    : integer := 5;
  constant c_BURST_MSB    : integer := 6;
  constant c_LENGTH_LSB   : integer := 7;
  constant c_LENGTH_MSB   : integer := 14;
  constant c_ID_LSB       : integer := 15;
  constant c_ID_MSB       : integer := 19;

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

  -- Diagnostics helpers
  constant c_DIAG_ENABLE   : boolean := true;
  constant c_DIAG_DUMP_PKTS: boolean := true;

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
  -- Helpers for arbitrary widths (prints low 32 bits, and high 32 bits if present)
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

  procedure dump_flit(constant tag : in string; constant idx : in natural; constant f : in t_flit) is
  begin
    if c_DIAG_ENABLE then
      report "t=" & time'image(now) & "  " & tag &
             " [" & integer'image(integer(idx)) & "] ctrl=" & std_logic'image(f(f'left)) &
             " word=0x" & hex32(f(31 downto 0))
        severity note;
    end if;
  end procedure;

  function u_to_str(u : unsigned) return string is
  begin
    return integer'image(to_integer(u));
  end function;

  signal sim_done : std_logic := '0';

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  u_dut: entity work.tg_ni_write_only_top_dbg
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start       => tg_start,
      o_done        => tg_done,
      INPUT_ADDRESS => input_address,
      STARTING_SEED => starting_seed,

      l_in_data_o => lin_data,
      l_in_val_o  => lin_val,
      l_in_ack_i  => lin_ack,

      l_out_data_i => lout_data,
      l_out_val_i  => lout_val,
      l_out_ack_o  => lout_ack,

      -- debug exports
      o_dbg_axi_awid    => dbg_awid,
      o_dbg_axi_awaddr  => dbg_awaddr,
      o_dbg_axi_awlen   => dbg_awlen,
      o_dbg_axi_awburst => dbg_awburst,
      o_dbg_axi_awvalid => dbg_awvalid,
      o_dbg_axi_awready => dbg_awready,

      o_dbg_axi_wvalid  => dbg_wvalid,
      o_dbg_axi_wready  => dbg_wready,
      o_dbg_axi_wdata   => dbg_wdata,
      o_dbg_axi_wlast   => dbg_wlast,

      o_dbg_axi_bid     => dbg_bid,
      o_dbg_axi_bresp   => dbg_bresp,
      o_dbg_axi_bvalid  => dbg_bvalid,
      o_dbg_axi_bready  => dbg_bready,

      o_dbg_tg_state        => dbg_tg_state,
      o_dbg_tg_aw_hs        => dbg_tg_aw_hs,
      o_dbg_tg_w_hs         => dbg_tg_w_hs,
      o_dbg_tg_b_hs         => dbg_tg_b_hs,
      o_dbg_tg_bhs_seen     => dbg_tg_bhs_seen,
      o_dbg_tg_txn_start_pulse => open,
      o_dbg_tg_wbeat_pulse     => open,

      o_dbg_dp_seeded       => dbg_dp_seeded,
      o_dbg_dp_do_init      => dbg_dp_do_init,
      o_dbg_dp_do_step      => dbg_dp_do_step,
      o_dbg_dp_init_value   => open,
      o_dbg_dp_feedback_val => open,
      o_dbg_dp_lfsr_input   => dbg_dp_lfsr_in,
      o_dbg_dp_lfsr_next    => dbg_dp_lfsr_nxt,
      o_dbg_dp_lfsr_in_reg  => open,
      o_dbg_dp_wdata_reg    => open,
      o_dbg_tg_lfsr_value   => open,

      o_dbg_corrupt_packet  => dbg_corrupt
    );

  ---------------------------------------------------------------------------
  -- Debug monitor (prints TG state changes + AXI handshakes)
  ---------------------------------------------------------------------------
  monitor: process
    variable last_state : std_logic_vector(1 downto 0) := (others => 'X');
  begin
    wait until rising_edge(ACLK);
    while sim_done = '0' loop
      if dbg_tg_state /= last_state then
        report "t=" & time'image(now) &
               "  TG STATE " & std_logic'image(last_state(1)) & std_logic'image(last_state(0)) &
               " -> " & std_logic'image(dbg_tg_state(1)) & std_logic'image(dbg_tg_state(0)) &
               " | AWV/AWR=" & std_logic'image(dbg_awvalid) & "/" & std_logic'image(dbg_awready) &
               " WV/WR="    & std_logic'image(dbg_wvalid)  & "/" & std_logic'image(dbg_wready) &
               " BV/BR="    & std_logic'image(dbg_bvalid)  & "/" & std_logic'image(dbg_bready) &
               " corrupt="  & std_logic'image(dbg_corrupt)
          severity note;
        last_state := dbg_tg_state;
      end if;

      if (dbg_awvalid = '1' and dbg_awready = '1') then
        report "t=" & time'image(now) &
               "  AXI AW_HS: awid=" & u_to_str(unsigned(dbg_awid)) &
               " awaddr_hi=0x" & hex32(dbg_awaddr(63 downto 32)) &
               " awaddr_lo=0x" & hex32(dbg_awaddr(31 downto 0)) &
               " awlen=" & u_to_str(unsigned(dbg_awlen)) &
               " awburst=" & u_to_str(unsigned(dbg_awburst))
          severity note;
      end if;

      if (dbg_wvalid = '1' and dbg_wready = '1') then
        report "t=" & time'image(now) &
               "  AXI W_HS: wlast=" & std_logic'image(dbg_wlast) &
               " wdata_hi=0x" & hex_hi32(dbg_wdata) &
               " wdata_lo=0x" & hex_lo32(dbg_wdata) &
               " | seeded=" & std_logic'image(dbg_dp_seeded) &
               " do_init/do_step=" & std_logic'image(dbg_dp_do_init) & "/" & std_logic'image(dbg_dp_do_step) &
               " lfsr_in_lo=0x" & hex_lo32(dbg_dp_lfsr_in) &
               " lfsr_next_lo=0x" & hex32(dbg_dp_lfsr_nxt(31 downto 0))
          severity note;
      end if;

      if (dbg_bvalid = '1' and dbg_bready = '1') then
        report "t=" & time'image(now) &
               "  AXI B_HS: bid=" & u_to_str(unsigned(dbg_bid)) &
               " bresp=" & u_to_str(unsigned(dbg_bresp))
          severity note;
      end if;

      wait until rising_edge(ACLK);
    end loop;
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- NoC "subordinate" emulator:
  --   capture request flits from NI (lin_*), then inject a WRITE response to NI (lout_*)
  ---------------------------------------------------------------------------
  noc_loopback: process
    variable req  : t_pkt;
    variable req_len  : natural;

    variable req_hdr0 : std_logic_vector(31 downto 0);
    variable req_hdr1 : std_logic_vector(31 downto 0);
    variable req_hdr2 : std_logic_vector(31 downto 0);

    variable req_type : std_logic;
    variable req_opc  : std_logic;
    variable req_id   : std_logic_vector(4 downto 0);
    variable req_len_field : unsigned(7 downto 0);
    variable req_burst : std_logic_vector(1 downto 0);

    variable resp_hdr0 : std_logic_vector(31 downto 0);
    variable resp_hdr1 : std_logic_vector(31 downto 0);
    variable resp_hdr2 : std_logic_vector(31 downto 0);

    variable resp_idx : natural;
    variable cyc : natural;

    -- Accept exactly one outgoing flit (NI->TB): sample, then pulse lin_ack
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
      dump_flit("RX", idx, dst);

      lin_ack <= '1';
      wait until rising_edge(ACLK);
      lin_ack <= '0';
      wait until rising_edge(ACLK);
    end procedure;

    -- Send one response flit (TB->NI): hold VAL high until NI asserts lout_ack
    procedure send_resp_flit(constant f : in t_flit; constant idx : in natural) is
    begin
      -- Robust VAL/ACK handshake for NI receive_control:
      -- * Present data with VAL=1
      -- * Wait until ACK=1 on a rising edge
      -- * Then drop VAL for at least one cycle to mark a beat boundary
      -- * Also wait for ACK to deassert before starting the next flit
      dump_flit("TX", idx, f);

      -- Ensure previous ACK is low (some receiver implementations can keep ACK high while VAL is high)
      cyc := 0;
      while lout_ack = '1' loop
        wait until rising_edge(ACLK);
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack to deassert (pre-flit)" severity failure;
        end if;
      end loop;

      -- Drive flit
      lout_data <= f;
      lout_val  <= '1';

      -- Wait acceptance
      cyc := 0;
      loop
        wait until rising_edge(ACLK);
        exit when lout_ack = '1';
        cyc := cyc + 1;
        if cyc = c_TIMEOUT_CYCLES then
          assert false report "TIMEOUT waiting lout_ack (response flit)" severity failure;
        end if;
      end loop;

      -- Drop VAL for one full cycle
      lout_val <= '0';
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
      -- Capture one full request packet, stopping on checksum flit (ctrl='1').
      ---------------------------------------------------------------------
      req_len := 0;

      -- hdr0 (ctrl must be 1)
      accept_one_req_flit(req(0), 0);
      if sim_done = '1' then exit; end if;
      assert flit_ctrl(req(0)) = '1' report "Expected ctrl=1 on hdr0" severity failure;
      req_len := 1;

      -- capture until checksum (ctrl='1')
      while req_len < c_MAX_FLITS loop
        accept_one_req_flit(req(req_len), req_len);
        if sim_done = '1' then exit; end if;
        req_len := req_len + 1;
        exit when flit_ctrl(req(req_len-1)) = '1';
      end loop;

      assert req_len < c_MAX_FLITS report "Request too long (no checksum delimiter)" severity failure;

      if c_DIAG_DUMP_PKTS then
        dbg("---- BEGIN REQUEST PACKET DUMP (flits=" & integer'image(integer(req_len)) & ") ----");
        for k in 0 to integer(req_len)-1 loop
          dump_flit("REQ", natural(k), req(k));
        end loop;
        dbg("---- END   REQUEST PACKET DUMP ----");
      end if;

      -- decode headers
      req_hdr0 := req(0)(31 downto 0);
      req_hdr1 := req(1)(31 downto 0);
      req_hdr2 := req(2)(31 downto 0);

      req_type := req_hdr2(c_TYPE_BIT);
      req_opc  := req_hdr2(c_OPC_BIT);
      req_id   := req_hdr2(c_ID_MSB downto c_ID_LSB);
      req_len_field := unsigned(req_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB));
      req_burst := req_hdr2(c_BURST_MSB downto c_BURST_LSB);

      report "RX pkt: flits=" & integer'image(integer(req_len)) &
             "  hdr0=0x" & hex32(req_hdr0) &
             "  hdr1=0x" & hex32(req_hdr1) &
             "  hdr2=0x" & hex32(req_hdr2) &
             "  TYPE=" & std_logic'image(req_type) &
             "  OPC=" & std_logic'image(req_opc) &
             "  ID=" & integer'image(to_integer(unsigned(req_id))) &
             "  LEN=" & integer'image(to_integer(req_len_field)) &
             "  BURST=" & integer'image(to_integer(unsigned(req_burst)))
        severity note;

      ---------------------------------------------------------------------
      -- Build WRITE response packet as NI expects:
      --   hdr0 = request hdr1 (swap dest/src)
      --   hdr1 = request hdr0
      --   hdr2/H_INTERFACE:
      --       TYPE=1 (response)
      --       OPC = 0 (write)
      --       STATUS = "000" (OK)
      --       ID = request ID (matches AWID)
      --       LENGTH = 0 (no payload)
      --       BURST copied
      ---------------------------------------------------------------------
      resp_hdr0 := req_hdr1;
      resp_hdr1 := req_hdr0;

      resp_hdr2 := (others => '0');
      resp_hdr2(c_ID_MSB downto c_ID_LSB) := req_id;
      resp_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB) := (others => '0');
      resp_hdr2(c_BURST_MSB downto c_BURST_LSB) := req_burst;
      resp_hdr2(c_STATUS_MSB downto c_STATUS_LSB) := (others => '0'); -- OK
      resp_hdr2(c_OPC_BIT) := '0';  -- WRITE response (CRITICAL!)
      resp_hdr2(c_TYPE_BIT) := '1'; -- RESPONSE

      dbg("RESP build: hdr0=0x" & hex32(resp_hdr0) &
          " hdr1=0x" & hex32(resp_hdr1) &
          " hdr2=0x" & hex32(resp_hdr2) &
          " (TYPE=" & std_logic'image(resp_hdr2(c_TYPE_BIT)) &
          " OPC=" & std_logic'image(resp_hdr2(c_OPC_BIT)) & ")");

      ---------------------------------------------------------------------
      -- Send response: hdr0(ctrl=1), hdr1, hdr2, checksum(ctrl=1)
      ---------------------------------------------------------------------
      resp_idx := 0;
      send_resp_flit(mk_flit('1', resp_hdr0), resp_idx); resp_idx := resp_idx + 1;
      send_resp_flit(mk_flit('0', resp_hdr1), resp_idx); resp_idx := resp_idx + 1;
      send_resp_flit(mk_flit('0', resp_hdr2), resp_idx); resp_idx := resp_idx + 1;
      send_resp_flit(mk_flit('1', (others => '0')), resp_idx); resp_idx := resp_idx + 1;

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

      dbg("=== ITER " & integer'image(it) & " DONE ===");
      wait until rising_edge(ACLK);
      wait until rising_edge(ACLK);

      input_address <= std_logic_vector(unsigned(input_address) + 16);
      starting_seed <= std_logic_vector(unsigned(starting_seed) + 1);
    end loop;

    sim_done <= '1';
    report "TB completed OK" severity note;
    wait for 50 ns;
    assert false report "End of simulation" severity failure;
  end process;

end architecture;
