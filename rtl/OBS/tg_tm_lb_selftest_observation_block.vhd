library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- Observation block used by closed-box self-test:
-- * generates TG/TM control vectors
-- * centralizes all DUT observation enables and observation outputs
entity tg_tm_lb_selftest_observation_block is
  generic (
    p_USE_OBS_START_DONE_CTRL_TMR : boolean := c_ENABLE_OBS_START_DONE_CTRL_TMR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- UART interface (to top-level UART)
    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;
    uart_tready_i   : in  std_logic;
    uart_tdone_i    : in  std_logic;
    uart_tstart_o   : out std_logic;
    uart_tdata_o    : out std_logic_vector(7 downto 0);
    uart_rready_o   : out std_logic;
    uart_rdone_i    : in  std_logic;
    uart_rdata_i    : in  std_logic_vector(7 downto 0);
    uart_rerr_i     : in  std_logic;

    -- TG/TM control interface to DUT
    tg_start_o : out std_logic;
    tg_done_i  : in  std_logic;
    tg_addr_o  : out std_logic_vector(63 downto 0);
    tg_seed_o  : out std_logic_vector(31 downto 0);

    tm_start_o : out std_logic;
    tm_done_i  : in  std_logic;
    tm_addr_o  : out std_logic_vector(63 downto 0);
    tm_seed_o  : out std_logic_vector(31 downto 0);

    tm_comparison_mismatch_i : in  std_logic;
    TM_TRANSACTION_COUNT_i : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    TM_EXPECTED_VALUE_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    NI_CORRUPT_PACKET_i    : in std_logic;

    -- OBS enables (to DUT)
    OBS_TM_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_TM_TMR_CTRL_CORRECT_ERROR_o   : out std_logic;
    OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o : out std_logic;

    OBS_LB_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_LB_TMR_CTRL_CORRECT_ERROR_o   : out std_logic;

    OBS_TG_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_TG_TMR_CTRL_CORRECT_ERROR_o   : out std_logic;

    OBS_FE_INJ_META_HDR_CORRECT_ERROR_o : out std_logic;
    OBS_FE_INJ_ADDR_CORRECT_ERROR_o     : out std_logic;

    OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o : out std_logic;
    OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o : out std_logic;

    OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o : out std_logic;

    -- OBS outputs (from DUT)
    OBS_TM_TMR_CTRL_ERROR_i : in std_logic;
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_LB_TMR_CTRL_ERROR_i : in std_logic;
    OBS_LB_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_LB_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_LB_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, c_ENABLE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_TG_TMR_CTRL_ERROR_i : in std_logic;
    OBS_TG_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_TG_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_TG_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_FE_INJ_META_HDR_SINGLE_ERR_i : in std_logic;
    OBS_FE_INJ_META_HDR_DOUBLE_ERR_i : in std_logic;
    OBS_FE_INJ_ADDR_SINGLE_ERR_i : in std_logic;
    OBS_FE_INJ_ADDR_DOUBLE_ERR_i : in std_logic;
    OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i : in std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_FE_INJ_HAM_ADDR_ENC_DATA_i : in std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i : in std_logic;

    OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_INTEGRITY_CORRUPT_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i : in std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_observation_block is
  signal experiment_run_enable_w  : std_logic;
  signal experiment_reset_pulse_w : std_logic;
  signal obs_start_done_ctrl_tmr_error_w : std_logic;
  signal obs_start_done_ctrl_tmr_correct_error_w : std_logic;
begin
  -- TG/TM sequencer+constants block: controls start/done handshake and provides constant addr/seed.
  b_tg_tm_sequencer_and_constants: block
  begin
    gen_obs_start_done_ctrl_plain : if not p_USE_OBS_START_DONE_CTRL_TMR generate
      u_tg_tm_start_done_controller: entity work.tg_tm_lb_selftest_obs_control
        port map(
          ACLK    => ACLK,
          ARESETn => ARESETn,
          experiment_run_enable_i  => experiment_run_enable_w,
          experiment_reset_pulse_i => experiment_reset_pulse_w,
          tg_done_i => tg_done_i,
          tm_done_i => tm_done_i,
          tg_start_o => tg_start_o,
          tm_start_o => tm_start_o
        );
      obs_start_done_ctrl_tmr_error_w <= '0';
    end generate;

    gen_obs_start_done_ctrl_tmr : if p_USE_OBS_START_DONE_CTRL_TMR generate
      u_tg_tm_start_done_controller_tmr: entity work.tg_tm_lb_selftest_obs_control_tmr
        port map(
          ACLK    => ACLK,
          ARESETn => ARESETn,
          experiment_run_enable_i  => experiment_run_enable_w,
          experiment_reset_pulse_i => experiment_reset_pulse_w,
          tg_done_i => tg_done_i,
          tm_done_i => tm_done_i,
          tg_start_o => tg_start_o,
          tm_start_o => tm_start_o,
          correct_enable_i => obs_start_done_ctrl_tmr_correct_error_w,
          error_o          => obs_start_done_ctrl_tmr_error_w
        );
    end generate;

    u_tg_tm_seed_and_addr_constants: entity work.tg_tm_lb_selftest_obs_datapath
      port map(
        tg_addr_o => tg_addr_o,
        tg_seed_o => tg_seed_o,
        tm_addr_o => tm_addr_o,
        tm_seed_o => tm_seed_o
      );
  end block;

  -- UART coding block
  u_obs_uart_encode_block: entity work.tg_tm_lb_selftest_uart_encode_block
    port map(
      ACLK                    => ACLK,
      ARESETn                 => ARESETn,
      tm_done_i               => tm_done_i,
      tm_comparison_mismatch_i => tm_comparison_mismatch_i,
      TM_TRANSACTION_COUNT_i   => TM_TRANSACTION_COUNT_i,
      TM_EXPECTED_VALUE_i      => TM_EXPECTED_VALUE_i,
      NI_CORRUPT_PACKET_i      => NI_CORRUPT_PACKET_i,
      OBS_TM_TMR_CTRL_ERROR_i => OBS_TM_TMR_CTRL_ERROR_i,
      OBS_TM_HAM_BUFFER_SINGLE_ERR_i => OBS_TM_HAM_BUFFER_SINGLE_ERR_i,
      OBS_TM_HAM_BUFFER_DOUBLE_ERR_i => OBS_TM_HAM_BUFFER_DOUBLE_ERR_i,
      OBS_TM_HAM_BUFFER_ENC_DATA_i => OBS_TM_HAM_BUFFER_ENC_DATA_i,
      OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i => OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i,
      OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i => OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i,
      OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i => OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i,
      OBS_LB_TMR_CTRL_ERROR_i => OBS_LB_TMR_CTRL_ERROR_i,
      OBS_LB_HAM_BUFFER_SINGLE_ERR_i => OBS_LB_HAM_BUFFER_SINGLE_ERR_i,
      OBS_LB_HAM_BUFFER_DOUBLE_ERR_i => OBS_LB_HAM_BUFFER_DOUBLE_ERR_i,
      OBS_LB_HAM_BUFFER_ENC_DATA_i => OBS_LB_HAM_BUFFER_ENC_DATA_i,
      OBS_TG_TMR_CTRL_ERROR_i => OBS_TG_TMR_CTRL_ERROR_i,
      OBS_TG_HAM_BUFFER_SINGLE_ERR_i => OBS_TG_HAM_BUFFER_SINGLE_ERR_i,
      OBS_TG_HAM_BUFFER_DOUBLE_ERR_i => OBS_TG_HAM_BUFFER_DOUBLE_ERR_i,
      OBS_TG_HAM_BUFFER_ENC_DATA_i => OBS_TG_HAM_BUFFER_ENC_DATA_i,
      OBS_FE_INJ_META_HDR_SINGLE_ERR_i => OBS_FE_INJ_META_HDR_SINGLE_ERR_i,
      OBS_FE_INJ_META_HDR_DOUBLE_ERR_i => OBS_FE_INJ_META_HDR_DOUBLE_ERR_i,
      OBS_FE_INJ_ADDR_SINGLE_ERR_i => OBS_FE_INJ_ADDR_SINGLE_ERR_i,
      OBS_FE_INJ_ADDR_DOUBLE_ERR_i => OBS_FE_INJ_ADDR_DOUBLE_ERR_i,
      OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i => OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i,
      OBS_FE_INJ_HAM_ADDR_ENC_DATA_i => OBS_FE_INJ_HAM_ADDR_ENC_DATA_i,
      OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i => OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i,
      OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i => OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i,
      OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i => OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i,
      OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i => OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i,
      OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i => OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i,
      OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i => OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i,
      OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i => OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i,
      OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i => OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i,
      OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i => OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i,
      OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i => OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i,
      OBS_BE_RX_HAM_BUFFER_ENC_DATA_i => OBS_BE_RX_HAM_BUFFER_ENC_DATA_i,
      OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i,
      OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i,
      OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i,
      OBS_BE_RX_INTEGRITY_CORRUPT_i => OBS_BE_RX_INTEGRITY_CORRUPT_i,
      OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i,
      OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i,
      OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i,
      OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i,
      OBS_START_DONE_CTRL_TMR_ERROR_i => obs_start_done_ctrl_tmr_error_w,
      OBS_TM_HAM_BUFFER_CORRECT_ERROR_o => OBS_TM_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_TM_TMR_CTRL_CORRECT_ERROR_o => OBS_TM_TMR_CTRL_CORRECT_ERROR_o,
      OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o => OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o,
      OBS_LB_HAM_BUFFER_CORRECT_ERROR_o => OBS_LB_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_LB_TMR_CTRL_CORRECT_ERROR_o => OBS_LB_TMR_CTRL_CORRECT_ERROR_o,
      OBS_TG_HAM_BUFFER_CORRECT_ERROR_o => OBS_TG_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_TG_TMR_CTRL_CORRECT_ERROR_o => OBS_TG_TMR_CTRL_CORRECT_ERROR_o,
      OBS_FE_INJ_META_HDR_CORRECT_ERROR_o => OBS_FE_INJ_META_HDR_CORRECT_ERROR_o,
      OBS_FE_INJ_ADDR_CORRECT_ERROR_o => OBS_FE_INJ_ADDR_CORRECT_ERROR_o,
      OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
      OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o,
      OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o,
      OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o,
      OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
      OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o,
      OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o,
      OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o,
      OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o => obs_start_done_ctrl_tmr_correct_error_w,
      experiment_run_enable_o => experiment_run_enable_w,
      experiment_reset_pulse_o => experiment_reset_pulse_w,
      uart_baud_div_o => uart_baud_div_o,
      uart_parity_o   => uart_parity_o,
      uart_rtscts_o   => uart_rtscts_o,
      uart_tready_i => uart_tready_i,
      uart_tdone_i  => uart_tdone_i,
      uart_tstart_o => uart_tstart_o,
      uart_tdata_o  => uart_tdata_o,
      uart_rready_o => uart_rready_o,
      uart_rdone_i  => uart_rdone_i,
      uart_rdata_i  => uart_rdata_i,
      uart_rerr_i   => uart_rerr_i
    );
end architecture;
