library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- Core UART encode hierarchy:
-- * critical timing/report trigger block
-- * encode controller
-- * encode datapath
entity selftest_obs_uart_encode_core_block is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS;
    p_USE_UART_ENCODE_CRITICAL_TMR : boolean := c_ENABLE_OBS_UART_ENCODE_CRITICAL_TMR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
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
    OBS_UART_COMMAND_CTRL_TMR_ERROR_i : in std_logic;
    OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_i : in std_logic;

    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;
    uart_tready_i   : in  std_logic;
    uart_tdone_i    : in  std_logic;
    uart_tstart_o   : out std_logic;
    uart_tdata_o    : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of selftest_obs_uart_encode_core_block is
  signal critical_tm_done_rise_w    : std_logic;
  signal critical_period_due_w      : std_logic;
  signal critical_report_consume_w  : std_logic;
  signal uart_encode_critical_tmr_error_w : std_logic;
  signal uart_encode_critical_tmr_correct_enable_w : std_logic;
  signal dp_load_base_w  : std_logic;
  signal dp_load_enc_w   : std_logic;
  signal dp_event_report_w : std_logic;
  signal dp_event_enc_valid_w : std_logic;
  signal dp_pending_enc_line_w : std_logic;
  signal dp_report_has_flags_w : std_logic;
  signal dp_tm_count_w   : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
  signal dp_flags_w      : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
  signal dp_enc_src_w    : std_logic_vector(3 downto 0);
  signal dp_enc_data_w   : std_logic_vector(79 downto 0);
  signal dp_nibble_index_w : unsigned(4 downto 0);
  signal dp_label_sel_w   : std_logic_vector(2 downto 0);
  signal dp_label_index_w : natural range 1 to 8;
  signal dp_hex_char_w    : std_logic_vector(7 downto 0);
  signal dp_label_char_w  : std_logic_vector(7 downto 0);
begin
  -- Keep the UART critical encode trigger protected independently from the
  -- OBS enable commands so fault reporting itself remains robust.
  uart_encode_critical_tmr_correct_enable_w <= '1';

  gen_uart_encode_critical_plain : if not p_USE_UART_ENCODE_CRITICAL_TMR generate
  begin
    u_uart_encode_critical: entity work.selftest_obs_uart_encode_critical
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK                => ACLK,
        ARESETn             => ARESETn,
        tm_done_i           => tm_done_i,
        report_consume_i    => critical_report_consume_w,
        tm_done_rise_o      => critical_tm_done_rise_w,
        period_report_due_o => critical_period_due_w
      );
    uart_encode_critical_tmr_error_w <= '0';
  end generate;

  gen_uart_encode_critical_tmr : if p_USE_UART_ENCODE_CRITICAL_TMR generate
  begin
    u_uart_encode_critical_tmr: entity work.selftest_obs_uart_encode_critical_tmr
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK                => ACLK,
        ARESETn             => ARESETn,
        tm_done_i           => tm_done_i,
        report_consume_i    => critical_report_consume_w,
        tm_done_rise_o      => critical_tm_done_rise_w,
        period_report_due_o => critical_period_due_w,
        correct_enable_i    => uart_encode_critical_tmr_correct_enable_w,
        error_o             => uart_encode_critical_tmr_error_w
      );
  end generate;

  u_selftest_obs_uart_encode_ctrl: entity work.selftest_obs_uart_encode_ctrl
    generic map(
      G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      tm_done_i => tm_done_i,
      tm_done_rise_i => critical_tm_done_rise_w,
      period_report_due_i => critical_period_due_w,
      period_report_consume_o => critical_report_consume_w,
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
      OBS_UART_COMMAND_CTRL_TMR_ERROR_i => OBS_UART_COMMAND_CTRL_TMR_ERROR_i,
      OBS_UART_ENCODE_CRITICAL_TMR_ERROR_i => uart_encode_critical_tmr_error_w,
      uart_baud_div_o => uart_baud_div_o,
      uart_parity_o   => uart_parity_o,
      uart_rtscts_o   => uart_rtscts_o,
      uart_tready_i => uart_tready_i,
      uart_tdone_i  => uart_tdone_i,
      uart_tstart_o => uart_tstart_o,
      uart_tdata_o  => uart_tdata_o,
      dp_hex_char_i   => dp_hex_char_w,
      dp_label_char_i => dp_label_char_w,
      dp_load_base_o  => dp_load_base_w,
      dp_load_enc_o   => dp_load_enc_w,
      dp_event_report_o => dp_event_report_w,
      dp_event_enc_valid_o => dp_event_enc_valid_w,
      dp_pending_enc_line_i => dp_pending_enc_line_w,
      dp_report_has_flags_i => dp_report_has_flags_w,
      dp_tm_count_o   => dp_tm_count_w,
      dp_flags_o      => dp_flags_w,
      dp_enc_src_o    => dp_enc_src_w,
      dp_enc_data_o   => dp_enc_data_w,
      dp_nibble_index_o => dp_nibble_index_w,
      dp_label_sel_o  => dp_label_sel_w,
      dp_label_index_o => dp_label_index_w
    );

  u_uart_encode_datapath: entity work.selftest_obs_uart_encode_datapath
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      load_base_i  => dp_load_base_w,
      load_enc_i   => dp_load_enc_w,
      event_report_i => dp_event_report_w,
      event_enc_valid_i => dp_event_enc_valid_w,
      tm_count_i   => dp_tm_count_w,
      flags_i      => dp_flags_w,
      enc_src_i    => dp_enc_src_w,
      enc_data_i   => dp_enc_data_w,
      nibble_index_i => dp_nibble_index_w,
      label_sel_i    => dp_label_sel_w,
      label_index_i  => dp_label_index_w,
      pending_enc_line_o => dp_pending_enc_line_w,
      report_has_flags_o => dp_report_has_flags_w,
      hex_char_o     => dp_hex_char_w,
      label_char_o   => dp_label_char_w
    );
end architecture;
