
library IEEE;
library std;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity tb_manager_integration_dbg_top is
end entity;

architecture tb of tb_manager_integration_dbg_top is
  constant c_CLK_PERIOD : time := 10 ns;

  -- timeouts (in cycles)
  constant c_TIMEOUT_CYCLES_WRITE : natural := 200000;
  constant c_TIMEOUT_CYCLES_READ  : natural := 200000;

  -- periodic status prints
  constant c_PRINT_EVERY_CYCLES : natural := 10000;

  -- capture up to first N flits in each direction
  constant c_CAP_FLITS : natural := 8;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal i_start_write : std_logic := '0';
  signal i_start_read  : std_logic := '0';

  signal i_address : std_logic_vector(63 downto 0) := (others => '0');
  signal i_seed    : std_logic_vector(31 downto 0) := (others => '0');

  signal o_done_write : std_logic;
  signal o_done_read  : std_logic;
  signal o_mismatch   : std_logic;
  signal o_expected_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal o_lfsr_value     : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal o_corrupt_packet : std_logic;

  -- debug taps from DUT
  signal dbg_awvalid : std_logic;
  signal dbg_awready : std_logic;
  signal dbg_awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal dbg_awlen   : std_logic_vector(7 downto 0);

  signal dbg_wvalid : std_logic;
  signal dbg_wready : std_logic;
  signal dbg_wlast  : std_logic;
  signal dbg_wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal dbg_bvalid : std_logic;
  signal dbg_bready : std_logic;
  signal dbg_bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal dbg_arvalid : std_logic;
  signal dbg_arready : std_logic;
  signal dbg_araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal dbg_arlen   : std_logic_vector(7 downto 0);

  signal dbg_rvalid : std_logic;
  signal dbg_rready : std_logic;
  signal dbg_rlast  : std_logic;
  signal dbg_rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dbg_rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal dbg_lin_val  : std_logic;
  signal dbg_lin_ack  : std_logic;
  signal dbg_lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

  signal dbg_lout_val  : std_logic;
  signal dbg_lout_ack  : std_logic;
  signal dbg_lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

  -- counters / history
  signal cnt_aw  : natural := 0;
  signal cnt_w   : natural := 0;
  signal cnt_b   : natural := 0;
  signal cnt_ar  : natural := 0;
  signal cnt_r   : natural := 0;
  signal cnt_lin : natural := 0;
  signal cnt_lout: natural := 0;

  signal last_awaddr : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal last_araddr : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal last_wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal last_rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  signal last_lin_word  : std_logic_vector(31 downto 0) := (others => '0');
  signal last_lin_ctrl  : std_logic := '0';
  signal last_lout_word : std_logic_vector(31 downto 0) := (others => '0');
  signal last_lout_ctrl : std_logic := '0';

  type t_word_hist is array (0 to c_CAP_FLITS-1) of std_logic_vector(31 downto 0);
  type t_ctrl_hist is array (0 to c_CAP_FLITS-1) of std_logic;

  signal lin_word_hist  : t_word_hist := (others => (others => '0'));
  signal lin_ctrl_hist  : t_ctrl_hist := (others => '0');
  signal lout_word_hist : t_word_hist := (others => (others => '0'));
  signal lout_ctrl_hist : t_ctrl_hist := (others => '0');

begin

  -- clock
  p_clk : process
  begin
    while true loop
      ACLK <= '0';
      wait for c_CLK_PERIOD/2;
      ACLK <= '1';
      wait for c_CLK_PERIOD/2;
    end loop;
  end process;

  -- DUT with debug ports
  dut : entity work.manager_integration_dbg_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start_write => i_start_write,
      i_start_read  => i_start_read,

      i_address => i_address,
      i_seed    => i_seed,

      o_done_write => o_done_write,
      o_done_read  => o_done_read,
      o_mismatch   => o_mismatch,
      o_expected_value => o_expected_value,
      o_lfsr_value     => o_lfsr_value,
      o_corrupt_packet => o_corrupt_packet,

      dbg_awvalid => dbg_awvalid,
      dbg_awready => dbg_awready,
      dbg_awaddr  => dbg_awaddr,
      dbg_awlen   => dbg_awlen,

      dbg_wvalid => dbg_wvalid,
      dbg_wready => dbg_wready,
      dbg_wlast  => dbg_wlast,
      dbg_wdata  => dbg_wdata,

      dbg_bvalid => dbg_bvalid,
      dbg_bready => dbg_bready,
      dbg_bresp  => dbg_bresp,

      dbg_arvalid => dbg_arvalid,
      dbg_arready => dbg_arready,
      dbg_araddr  => dbg_araddr,
      dbg_arlen   => dbg_arlen,

      dbg_rvalid => dbg_rvalid,
      dbg_rready => dbg_rready,
      dbg_rlast  => dbg_rlast,
      dbg_rdata  => dbg_rdata,
      dbg_rresp  => dbg_rresp,

      dbg_lin_val  => dbg_lin_val,
      dbg_lin_ack  => dbg_lin_ack,
      dbg_lin_data => dbg_lin_data,

      dbg_lout_val  => dbg_lout_val,
      dbg_lout_ack  => dbg_lout_ack,
      dbg_lout_data => dbg_lout_data
    );

  ---------------------------------------------------------------------------
  -- MONITOR: count handshakes and capture first few flits/words
  ---------------------------------------------------------------------------
  p_mon : process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        cnt_aw   <= 0;
        cnt_w    <= 0;
        cnt_b    <= 0;
        cnt_ar   <= 0;
        cnt_r    <= 0;
        cnt_lin  <= 0;
        cnt_lout <= 0;

        last_awaddr <= (others => '0');
        last_araddr <= (others => '0');
        last_wdata  <= (others => '0');
        last_rdata  <= (others => '0');

        last_lin_word <= (others => '0');
        last_lin_ctrl <= '0';
        last_lout_word <= (others => '0');
        last_lout_ctrl <= '0';

        lin_word_hist  <= (others => (others => '0'));
        lin_ctrl_hist  <= (others => '0');
        lout_word_hist <= (others => (others => '0'));
        lout_ctrl_hist <= (others => '0');

      else
        -- AXI write
        if (dbg_awvalid = '1' and dbg_awready = '1') then
          cnt_aw <= cnt_aw + 1;
          last_awaddr <= dbg_awaddr;
        end if;

        if (dbg_wvalid = '1' and dbg_wready = '1') then
          cnt_w <= cnt_w + 1;
          last_wdata <= dbg_wdata;
        end if;

        if (dbg_bvalid = '1' and dbg_bready = '1') then
          cnt_b <= cnt_b + 1;
        end if;

        -- AXI read
        if (dbg_arvalid = '1' and dbg_arready = '1') then
          cnt_ar <= cnt_ar + 1;
          last_araddr <= dbg_araddr;
        end if;

        if (dbg_rvalid = '1' and dbg_rready = '1') then
          cnt_r <= cnt_r + 1;
          last_rdata <= dbg_rdata;
        end if;

        -- NoC request flits (NI -> loopback)
        if (dbg_lin_val = '1' and dbg_lin_ack = '1') then
          last_lin_word <= dbg_lin_data(31 downto 0);
          last_lin_ctrl <= dbg_lin_data(c_FLIT_WIDTH-1);

          if cnt_lin < c_CAP_FLITS then
            lin_word_hist(cnt_lin) <= dbg_lin_data(31 downto 0);
            lin_ctrl_hist(cnt_lin) <= dbg_lin_data(c_FLIT_WIDTH-1);
          end if;

          cnt_lin <= cnt_lin + 1;
        end if;

        -- NoC response flits (loopback -> NI)
        if (dbg_lout_val = '1' and dbg_lout_ack = '1') then
          last_lout_word <= dbg_lout_data(31 downto 0);
          last_lout_ctrl <= dbg_lout_data(c_FLIT_WIDTH-1);

          if cnt_lout < c_CAP_FLITS then
            lout_word_hist(cnt_lout) <= dbg_lout_data(31 downto 0);
            lout_ctrl_hist(cnt_lout) <= dbg_lout_data(c_FLIT_WIDTH-1);
          end if;

          cnt_lout <= cnt_lout + 1;
        end if;

      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- STIMULUS + DIAGNOSTICS
  ---------------------------------------------------------------------------
  p_stim : process
    variable v_cnt : natural;
    procedure dump_state(tag : in string) is
    begin
      report "==================== " & tag & " ====================" severity note;

      report "AXI-W: AW(v/r)=" & std_logic'image(dbg_awvalid) & "/" & std_logic'image(dbg_awready) &
             "  W(v/r/last)=" & std_logic'image(dbg_wvalid) & "/" & std_logic'image(dbg_wready) & "/" & std_logic'image(dbg_wlast) &
             "  B(v/r)=" & std_logic'image(dbg_bvalid) & "/" & std_logic'image(dbg_bready) &
             "  BRESP=" & to_hstring(unsigned(dbg_bresp)) severity note;

      report "AXI-R: AR(v/r)=" & std_logic'image(dbg_arvalid) & "/" & std_logic'image(dbg_arready) &
             "  R(v/r/last)=" & std_logic'image(dbg_rvalid) & "/" & std_logic'image(dbg_rready) & "/" & std_logic'image(dbg_rlast) &
             "  RRESP=" & to_hstring(unsigned(dbg_rresp)) severity note;

      report "COUNTS: AW=" & integer'image(integer(cnt_aw)) &
             " W=" & integer'image(integer(cnt_w)) &
             " B=" & integer'image(integer(cnt_b)) &
             " AR=" & integer'image(integer(cnt_ar)) &
             " R=" & integer'image(integer(cnt_r)) severity note;

      report "NoC:  lin(v/ack)=" & std_logic'image(dbg_lin_val) & "/" & std_logic'image(dbg_lin_ack) &
             "  lout(v/ack)=" & std_logic'image(dbg_lout_val) & "/" & std_logic'image(dbg_lout_ack) severity note;

      report "NoC COUNTS: lin_flits=" & integer'image(integer(cnt_lin)) &
             "  lout_flits=" & integer'image(integer(cnt_lout)) severity note;

      report "LAST: AWADDR=" & to_hstring(unsigned(last_awaddr)) &
             "  WDATA=" & to_hstring(unsigned(last_wdata(last_wdata'left downto last_wdata'left-31))) &
             "  ARADDR=" & to_hstring(unsigned(last_araddr)) &
             "  RDATA=" & to_hstring(unsigned(last_rdata(last_rdata'left downto last_rdata'left-31))) severity note;

      report "LAST FLIT IN : ctrl=" & std_logic'image(last_lin_ctrl) &
             " word=" & to_hstring(unsigned(last_lin_word)) severity note;

      report "LAST FLIT OUT: ctrl=" & std_logic'image(last_lout_ctrl) &
             " word=" & to_hstring(unsigned(last_lout_word)) severity note;

      if o_corrupt_packet = '1' then
        report "NOTE: CORRUPT_PACKET=1 (manager flagged packet corruption)" severity warning;
      end if;

      report "Captured first request flits (lin):" severity note;
      for i in 0 to c_CAP_FLITS-1 loop
        if i < cnt_lin then
          report "  REQ[" & integer'image(i) & "]: ctrl=" & std_logic'image(lin_ctrl_hist(i)) &
                 " word=" & to_hstring(unsigned(lin_word_hist(i))) severity note;
        end if;
      end loop;

      report "Captured first response flits (lout):" severity note;
      for i in 0 to c_CAP_FLITS-1 loop
        if i < cnt_lout then
          report "  RSP[" & integer'image(i) & "]: ctrl=" & std_logic'image(lout_ctrl_hist(i)) &
                 " word=" & to_hstring(unsigned(lout_word_hist(i))) severity note;
        end if;
      end loop;

      report "============================================================" severity note;
    end procedure;

  begin
    -- defaults
    i_start_write <= '0';
    i_start_read  <= '0';

    -- pick a non-zero address + seed (same for write + read)
    i_address <= x"0000000000001000";
    i_seed    <= x"00000001";

    -- reset
    ARESETn <= '0';
    wait for 20*c_CLK_PERIOD;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    -------------------------------------------------------------------------
    -- WRITE PHASE
    -------------------------------------------------------------------------
    report "Starting WRITE phase..." severity note;

    -- hold start high until done (safe for both pulse and level-start designs)
    i_start_write <= '1';

    v_cnt := 0;
    while o_done_write /= '1' loop
      wait until rising_edge(ACLK);
      v_cnt := v_cnt + 1;

      if (v_cnt mod c_PRINT_EVERY_CYCLES) = 0 then
        report "WRITE progress @" & integer'image(integer(v_cnt)) &
               " cycles: AW=" & integer'image(integer(cnt_aw)) &
               " W=" & integer'image(integer(cnt_w)) &
               " B=" & integer'image(integer(cnt_b)) &
               " lin=" & integer'image(integer(cnt_lin)) &
               " lout=" & integer'image(integer(cnt_lout)) severity note;
        -- show immediate stall hints
        if cnt_aw = 0 then
          report "  HINT: AW never handshaked yet (check AWREADY/valid)" severity warning;
        elsif cnt_w = 0 then
          report "  HINT: AW handshaked but no W handshakes yet (check WREADY/valid)" severity warning;
        elsif cnt_b = 0 then
          report "  HINT: AW/W handshaked but no B response yet (BVALID never accepted)" severity warning;
        end if;

        if cnt_lin = 0 and cnt_aw > 0 then
          report "  HINT: AW accepted but no NoC request flits handshaked (lin_val/ack)" severity warning;
        elsif cnt_lin = 1 then
          report "  HINT: only 1 NoC request flit handshaked so far (often hdr0 only)" severity warning;
        end if;

        if o_corrupt_packet = '1' then
          report "  NOTE: CORRUPT_PACKET is high right now." severity warning;
        end if;
      end if;

      if v_cnt = c_TIMEOUT_CYCLES_WRITE then
        dump_state("WRITE TIMEOUT DUMP");
        assert false report "TIMEOUT waiting for o_done_write" severity failure;
      end if;
    end loop;

    i_start_write <= '0';
    dump_state("WRITE DONE (snapshot)");

    -- small gap
    for k in 0 to 9 loop
      wait until rising_edge(ACLK);
    end loop;

    -------------------------------------------------------------------------
    -- READ PHASE
    -------------------------------------------------------------------------
    report "Starting READ phase..." severity note;

    i_start_read <= '1';

    v_cnt := 0;
    while o_done_read /= '1' loop
      wait until rising_edge(ACLK);
      v_cnt := v_cnt + 1;

      if (v_cnt mod c_PRINT_EVERY_CYCLES) = 0 then
        report "READ progress @" & integer'image(integer(v_cnt)) &
               " cycles: AR=" & integer'image(integer(cnt_ar)) &
               " R=" & integer'image(integer(cnt_r)) &
               " lin=" & integer'image(integer(cnt_lin)) &
               " lout=" & integer'image(integer(cnt_lout)) severity note;

        if cnt_ar = 0 then
          report "  HINT: AR never handshaked yet (check ARREADY/valid)" severity warning;
        elsif cnt_r = 0 then
          report "  HINT: AR handshaked but no R beats yet (RVALID never accepted)" severity warning;
        end if;

        if o_mismatch = '1' then
          report "  NOTE: TM mismatch asserted (early). Expected=" & to_hstring(o_expected_value) severity warning;
        end if;

        if o_corrupt_packet = '1' then
          report "  NOTE: CORRUPT_PACKET is high right now." severity warning;
        end if;
      end if;

      if v_cnt = c_TIMEOUT_CYCLES_READ then
        dump_state("READ TIMEOUT DUMP");
        assert false report "TIMEOUT waiting for o_done_read" severity failure;
      end if;
    end loop;

    i_start_read <= '0';
    dump_state("READ DONE (snapshot)");

    -- final check
    assert o_mismatch = '0'
      report "TM mismatch detected at end. Expected=" &
             to_hstring(o_expected_value) &
             " ; LFSR(last)=" &
             to_hstring(o_lfsr_value)
      severity error;

    report "Simulation completed (write then read)." severity note;
    stop;
  end process;

end architecture;
