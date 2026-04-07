library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

-- UART manager for closed-box self-test:
-- * encodes fault/status vector as labeled ASCII text + LF
-- * decodes UART RX commands to control experiment and OBS enables
entity selftest_obs_uart_encode_block is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;

    -- Observability inputs used for UART report
    tm_comparison_mismatch_i : in  std_logic;
    TM_TRANSACTION_COUNT_i   : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    TM_EXPECTED_VALUE_i      : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    NI_CORRUPT_PACKET_i      : in std_logic;

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
    OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_i : in std_logic;
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_INTEGRITY_CORRUPT_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_START_DONE_CTRL_TMR_ERROR_i : in std_logic;

    -- OBS enables (to DUT), controlled from UART commands
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
    OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o : out std_logic;
    OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o : out std_logic;

    -- Experiment control outputs
    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;

    -- UART config
    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;

    -- UART TX interface
    uart_tready_i : in  std_logic;
    uart_tdone_i  : in  std_logic;
    uart_tstart_o : out std_logic;
    uart_tdata_o  : out std_logic_vector(7 downto 0);

    -- UART RX interface
    uart_rready_o : out std_logic;
    uart_rdone_i  : in  std_logic;
    uart_rdata_i  : in  std_logic_vector(7 downto 0);
    uart_rerr_i   : in  std_logic
  );
end entity;

architecture rtl of selftest_obs_uart_encode_block is
  signal uart_command_ctrl_tmr_error_w : std_logic;
  signal uart_encode_critical_tmr_correct_error_w : std_logic;
begin
  uart_rready_o <= '1';

  b_obs_enable_block: block
  begin
    u_obs_enable_block: entity work.selftest_uart_command_block
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        uart_rdone_i => uart_rdone_i,
        uart_rdata_i => uart_rdata_i,
        uart_rerr_i  => uart_rerr_i,
        experiment_run_enable_o  => experiment_run_enable_o,
        experiment_reset_pulse_o => experiment_reset_pulse_o,
        OBS_TM_HAM_BUFFER_CORRECT_ERROR_o => OBS_TM_HAM_BUFFER_CORRECT_ERROR_o,
        OBS_TM_TMR_CTRL_CORRECT_ERROR_o   => OBS_TM_TMR_CTRL_CORRECT_ERROR_o,
        OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o => OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o,
        OBS_LB_HAM_BUFFER_CORRECT_ERROR_o => OBS_LB_HAM_BUFFER_CORRECT_ERROR_o,
        OBS_LB_TMR_CTRL_CORRECT_ERROR_o   => OBS_LB_TMR_CTRL_CORRECT_ERROR_o,
        OBS_TG_HAM_BUFFER_CORRECT_ERROR_o => OBS_TG_HAM_BUFFER_CORRECT_ERROR_o,
        OBS_TG_TMR_CTRL_CORRECT_ERROR_o   => OBS_TG_TMR_CTRL_CORRECT_ERROR_o,
        OBS_FE_INJ_META_HDR_CORRECT_ERROR_o => OBS_FE_INJ_META_HDR_CORRECT_ERROR_o,
        OBS_FE_INJ_ADDR_CORRECT_ERROR_o     => OBS_FE_INJ_ADDR_CORRECT_ERROR_o,
        OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o,
        OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
        OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o,
        OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o,
        OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o,
        OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o,
        OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o,
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
        OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o,
        OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o,
        OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o,
        OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o => OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o,
        OBS_UART_COMMAND_CTRL_TMR_ERROR_o       => uart_command_ctrl_tmr_error_w,
        OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o => uart_encode_critical_tmr_correct_error_w
      );
  end block;

  b_uart_encode_core: block
  begin
    u_uart_encode_core: entity work.selftest_obs_uart_encode_core_block
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        tm_done_i => tm_done_i,
        tm_comparison_mismatch_i => tm_comparison_mismatch_i,
        TM_TRANSACTION_COUNT_i => TM_TRANSACTION_COUNT_i,
        TM_EXPECTED_VALUE_i    => TM_EXPECTED_VALUE_i,
        NI_CORRUPT_PACKET_i    => NI_CORRUPT_PACKET_i,
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
        OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_i => OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_i,
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i,
        OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i,
        OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i,
        OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i,
        OBS_BE_RX_INTEGRITY_CORRUPT_i => OBS_BE_RX_INTEGRITY_CORRUPT_i,
        OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i,
        OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i,
        OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i,
        OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i,
        OBS_START_DONE_CTRL_TMR_ERROR_i => OBS_START_DONE_CTRL_TMR_ERROR_i,
        OBS_UART_COMMAND_CTRL_TMR_ERROR_i => uart_command_ctrl_tmr_error_w,
        OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_i => uart_encode_critical_tmr_correct_error_w,
        uart_baud_div_o => uart_baud_div_o,
        uart_parity_o   => uart_parity_o,
        uart_rtscts_o   => uart_rtscts_o,
        uart_tready_i => uart_tready_i,
        uart_tdone_i  => uart_tdone_i,
        uart_tstart_o => uart_tstart_o,
        uart_tdata_o  => uart_tdata_o
      );
  end block;
end architecture;
