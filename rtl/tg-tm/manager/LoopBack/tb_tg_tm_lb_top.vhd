library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.env.all;

use work.xina_ni_ft_pkg.all;

entity tb_tg_tm_lb_top is
  port(
    -- TG correction enables
    i_obs_tg_ham_buffer_correct_error : in std_logic := '1';
    i_obs_tg_tmr_ctrl_correct_error   : in std_logic := '1';

    -- TM correction enables
    i_obs_tm_ham_buffer_correct_error : in std_logic := '1';
    i_obs_tm_tmr_ctrl_correct_error   : in std_logic := '1';

    -- Loopback correction enables
    i_obs_lb_ham_buffer_correct_error : in std_logic := '1';
    i_obs_lb_tmr_ctrl_correct_error   : in std_logic := '1';

    -- NI frontend correction enables
    i_obs_fe_inj_meta_hdr_correct_error : in std_logic := '1';
    i_obs_fe_inj_addr_correct_error     : in std_logic := '1';

    -- NI backend correction enables
    i_obs_be_inj_ham_buffer_correct_error    : in std_logic := '1';
    i_obs_be_inj_tmr_integrity_correct_error : in std_logic := '1';
    i_obs_be_inj_tmr_flow_ctrl_correct_error : in std_logic := '1';
    i_obs_be_inj_tmr_pktz_ctrl_correct_error : in std_logic := '1';
    i_obs_be_rx_ham_buffer_correct_error     : in std_logic := '1';
    i_obs_be_rx_tmr_integrity_correct_error  : in std_logic := '1';
    i_obs_be_rx_tmr_flow_ctrl_correct_error  : in std_logic := '1'
  );
end entity;

architecture tb of tb_tg_tm_lb_top is

  constant c_CLK_PERIOD : time := 10 ns;

  -- number of iterations
  constant c_NUM_ITERS : natural := 200;

  -- step between base addresses (bytes) each iter
  constant c_ADDR_STEP : unsigned(63 downto 0) := to_unsigned(16, 64); -- 0x10

  constant c_BASE_ADDR_INIT : std_logic_vector(63 downto 0) := x"00000000_00000100";
  constant c_SEED_INIT      : std_logic_vector(31 downto 0) := x"1ACEB00C";

  -- ECC
  constant c_DETECT_DOUBLE : boolean := TRUE;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;

  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;

  signal tg_addr  : std_logic_vector(63 downto 0) := c_BASE_ADDR_INIT;
  signal tm_addr  : std_logic_vector(63 downto 0) := c_BASE_ADDR_INIT;

  signal tg_seed  : std_logic_vector(31 downto 0) := c_SEED_INIT;
  signal tm_seed  : std_logic_vector(31 downto 0) := c_SEED_INIT;

  signal tm_mismatch : std_logic;
  signal tm_expected : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- TG/TM observation + correction enables (wired at TB top)
  signal tg_ctrl_tmr_err   : std_logic;
  signal tg_ham_single_err : std_logic;
  signal tg_ham_double_err : std_logic;

  signal tm_ctrl_tmr_err   : std_logic;
  signal tm_ham_single_err : std_logic;
  signal tm_ham_double_err : std_logic;

  -- LB observation + correction enables (NEW, wired at TB top like TG)
  signal lb_ctrl_tmr_err   : std_logic;
  signal lb_ham_single_err : std_logic;
  signal lb_ham_double_err : std_logic;

  -- AXI write (TG -> NI)
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal awlen   : std_logic_vector(7 downto 0);
  signal awburst : std_logic_vector(1 downto 0);
  signal awvalid : std_logic;
  signal awready : std_logic;

  signal wvalid  : std_logic;
  signal wready  : std_logic;
  signal wdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal wlast   : std_logic;

  signal bid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal bvalid : std_logic;
  signal bready : std_logic;

  -- AXI read (NI -> TM)
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen   : std_logic_vector(7 downto 0);
  signal arburst : std_logic_vector(1 downto 0);
  signal arvalid : std_logic;
  signal arready : std_logic;

  signal rvalid : std_logic;
  signal rready : std_logic;
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- NI <-> Loopback NoC signals
  signal lin_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic;

  signal lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lout_val  : std_logic;
  signal lout_ack  : std_logic;

  -- NI ECC ports (top-level)
  signal inj_single_err    : std_logic;
  signal inj_double_err    : std_logic;
  signal rx_single_err     : std_logic;
  signal rx_double_err     : std_logic;

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- TG
  u_tg: entity work.tg_write_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => tg_start,
      o_done  => tg_done,

      INPUT_ADDRESS => tg_addr,
      STARTING_SEED => tg_seed,

      -- Write request channel
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,
      AWVALID => awvalid,
      AWREADY => awready,

      -- Write data channel
      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      -- Write response channel
      BID    => bid,
      BRESP  => bresp,
      BVALID => bvalid,
      BREADY => bready,

      -- observation/correction
      i_OBS_TG_HAM_BUFFER_CORRECT_ERROR => i_obs_tg_ham_buffer_correct_error,
      i_OBS_TG_TMR_CTRL_CORRECT_ERROR   => i_obs_tg_tmr_ctrl_correct_error,

      o_OBS_TG_TMR_CTRL_ERROR        => tg_ctrl_tmr_err,
      o_OBS_TG_HAM_BUFFER_SINGLE_ERR => tg_ham_single_err,
      o_OBS_TG_HAM_BUFFER_DOUBLE_ERR => tg_ham_double_err
    );

  -- TM
  u_tm: entity work.tm_read_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => tm_start,
      o_done  => tm_done,

      INPUT_ADDRESS => tm_addr,
      STARTING_SEED => tm_seed,

      -- Read address channel
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,
      ARVALID => arvalid,
      ARREADY => arready,

      -- Read data channel
      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,

      RID    => rid,
      RRESP  => rresp,

      -- compare/debug
      o_mismatch       => tm_mismatch,
      o_expected_value => tm_expected,

      -- observation
      i_OBS_TM_HAM_BUFFER_CORRECT_ERROR => i_obs_tm_ham_buffer_correct_error,
      i_OBS_TM_TMR_CTRL_CORRECT_ERROR   => i_obs_tm_tmr_ctrl_correct_error,
      o_OBS_TM_TMR_CTRL_ERROR           => tm_ctrl_tmr_err,
      o_OBS_TM_HAM_BUFFER_SINGLE_ERR    => tm_ham_single_err,
      o_OBS_TM_HAM_BUFFER_DOUBLE_ERR    => tm_ham_double_err
    );

  -- NI manager
  u_ni: entity work.top_manager
    generic map(
      DETECT_DOUBLE => c_DETECT_DOUBLE
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write
      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BVALID  => bvalid,
      BREADY  => bready,
      BID     => bid,
      BRESP   => bresp,

      -- Read
      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      -- NoC-side ports
      l_in_data_i  => lin_data,
      l_in_val_i   => lin_val,
      l_in_ack_o   => lin_ack,

      l_out_data_o => lout_data,
      l_out_val_o  => lout_val,
      l_out_ack_i  => lout_ack,

      corrupt_packet => open,

      -- Observability/ECC ports
      o_OBS_FE_INJ_META_HDR_SINGLE_ERR => open,
      o_OBS_FE_INJ_META_HDR_DOUBLE_ERR => open,
      o_OBS_FE_INJ_ADDR_SINGLE_ERR     => open,
      o_OBS_FE_INJ_ADDR_DOUBLE_ERR     => open,
      i_OBS_FE_INJ_META_HDR_CORRECT_ERROR => i_obs_fe_inj_meta_hdr_correct_error,
      i_OBS_FE_INJ_ADDR_CORRECT_ERROR     => i_obs_fe_inj_addr_correct_error,

      i_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR => i_obs_be_inj_ham_buffer_correct_error,
      o_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR    => inj_single_err,
      o_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR    => inj_double_err,
      i_OBS_BE_INJ_TMR_INTEGRITY_CORRECT_ERROR => i_obs_be_inj_tmr_integrity_correct_error,
      i_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR => i_obs_be_inj_tmr_flow_ctrl_correct_error,
      i_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR => i_obs_be_inj_tmr_pktz_ctrl_correct_error,

      o_OBS_BE_INJ_TMR_INTEGRITY_ERROR => open,
      o_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR => open,
      o_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR => open,

      i_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR => i_obs_be_rx_ham_buffer_correct_error,
      o_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR    => rx_single_err,
      o_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR    => rx_double_err,
      i_OBS_BE_RX_TMR_INTEGRITY_CORRECT_ERROR => i_obs_be_rx_tmr_integrity_correct_error,
      i_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR => i_obs_be_rx_tmr_flow_ctrl_correct_error,

      o_OBS_BE_RX_TMR_INTEGRITY_ERROR => open,
      o_OBS_BE_RX_INTEGRITY_CORRUPT   => open,
      o_OBS_BE_RX_TMR_FLOW_CTRL_ERROR => open
    );

  -- Loopback
  u_lb: entity work.lb_top
    generic map(
      p_MEM_ADDR_BITS => 10
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_data_i => lin_data,
      lin_val_i  => lin_val,
      lin_ack_o  => lin_ack,

      lout_data_o => lout_data,
      lout_val_o  => lout_val,
      lout_ack_i  => lout_ack,

      -- NEW: ECC observation/correction ports for loopback (same style as TG/TM)
      i_OBS_LB_HAM_BUFFER_CORRECT_ERROR => i_obs_lb_ham_buffer_correct_error,
      i_OBS_LB_TMR_CTRL_CORRECT_ERROR   => i_obs_lb_tmr_ctrl_correct_error,

      o_OBS_LB_TMR_CTRL_ERROR        => lb_ctrl_tmr_err,
      o_OBS_LB_HAM_BUFFER_SINGLE_ERR => lb_ham_single_err,
      o_OBS_LB_HAM_BUFFER_DOUBLE_ERR => lb_ham_double_err
    );

  -- reset + stimulus
  stim: process
    variable base_addr : unsigned(63 downto 0);
    variable seed      : unsigned(31 downto 0);
  begin
    ARESETn <= '0';
    tg_start <= '0';
    tm_start <= '0';

    wait for 50 ns;
    ARESETn <= '1';
    wait for 50 ns;

    base_addr := unsigned(c_BASE_ADDR_INIT);
    seed      := unsigned(c_SEED_INIT);

    for it in 0 to integer(c_NUM_ITERS-1) loop
      tg_addr <= std_logic_vector(base_addr);
      tm_addr <= std_logic_vector(base_addr);

      tg_seed <= std_logic_vector(seed);
      tm_seed <= std_logic_vector(seed);

      -- TG
      tg_start <= '1';
      wait until rising_edge(ACLK);
      tg_start <= '0';
      wait until tg_done = '1';

      -- TM
      tm_start <= '1';
      wait until rising_edge(ACLK);
      tm_start <= '0';
      wait until tm_done = '1';

      base_addr := base_addr + c_ADDR_STEP;
      seed      := seed + 1;
      wait for 20 ns;
    end loop;

    std.env.stop;
    wait;
  end process;

end architecture;
