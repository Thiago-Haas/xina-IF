library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- Closed subordinate self-test top.
-- UART control/reporting is subordinate-specific to avoid pulling in the
-- larger manager OBS hierarchy for signals that do not exist here.
entity subordinate_tg_tm_lb_selftest_top is
  port (
    ACLK       : in  std_logic;
    ARESETn    : in  std_logic;
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic
  );
end entity;

architecture rtl of subordinate_tg_tm_lb_selftest_top is
  constant C_SELFTEST_ADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := x"00000100_00000000";
  constant C_SELFTEST_SEED : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := x"1ACEB00C";

  signal start_w   : std_logic;
  signal is_read_w : std_logic;
  signal done_w    : std_logic;
  signal tm_done_pulse_w : std_logic;

  signal mismatch_w       : std_logic;
  signal corrupt_packet_w : std_logic;

  signal uart_baud_div_w : std_logic_vector(15 downto 0);
  signal uart_parity_w   : std_logic;
  signal uart_rtscts_w   : std_logic;
  signal uart_tready_w   : std_logic;
  signal uart_tstart_w   : std_logic;
  signal uart_tdata_w    : std_logic_vector(7 downto 0);
  signal uart_tdone_w    : std_logic;
  signal uart_rready_w   : std_logic;
  signal uart_rdone_w    : std_logic;
  signal uart_rdata_w    : std_logic_vector(7 downto 0);
  signal uart_rerr_w     : std_logic;

  signal obs_tg_tmr_correct_w       : std_logic;
  signal obs_tg_ham_correct_w       : std_logic;
  signal obs_tm_tmr_correct_w       : std_logic;
  signal obs_tm_ham_correct_w       : std_logic;
  signal obs_tm_counter_correct_w   : std_logic;
  signal obs_tm_correct_counter_correct_w : std_logic;
  signal obs_lb_tmr_correct_w       : std_logic;
  signal obs_noc_lb_done_correct_w  : std_logic;
  signal obs_lb_payload_correct_w   : std_logic;
  signal obs_lb_rdata_correct_w     : std_logic;
  signal obs_lb_id_correct_w        : std_logic;
  signal obs_start_go_correct_w      : std_logic;
  signal obs_fe_status_correct_w    : std_logic;
  signal obs_sub_inj_buffer_correct_w : std_logic;
  signal obs_sub_inj_buffer_ctrl_correct_w : std_logic;
  signal obs_sub_inj_integrity_correct_w : std_logic;
  signal obs_sub_inj_flow_correct_w : std_logic;
  signal obs_sub_inj_pktz_correct_w : std_logic;
  signal obs_sub_rx_buffer_correct_w : std_logic;
  signal obs_sub_rx_buffer_ctrl_correct_w : std_logic;
  signal obs_rx_h_src_correct_w     : std_logic;
  signal obs_rx_h_interface_correct_w : std_logic;
  signal obs_rx_h_address_correct_w : std_logic;
  signal obs_sub_rx_integrity_correct_w : std_logic;
  signal obs_sub_rx_flow_correct_w : std_logic;
  signal obs_sub_rx_depktz_correct_w : std_logic;
  signal obs_uart_command_ctrl_error_w : std_logic;
  signal obs_uart_encode_critical_error_w : std_logic;
  signal obs_uart_rx_count_single_w : std_logic;
  signal obs_uart_rx_count_double_w : std_logic;
  signal obs_uart_correct_count_single_w : std_logic;
  signal obs_uart_correct_count_double_w : std_logic;
  signal obs_uart_flags_seen_single_w : std_logic;
  signal obs_uart_flags_seen_double_w : std_logic;
  signal obs_uart_event_flags_single_w : std_logic;
  signal obs_uart_event_flags_double_w : std_logic;
  signal obs_uart_report_flags_single_w : std_logic;
  signal obs_uart_report_flags_double_w : std_logic;

  signal obs_tg_tmr_error_w     : std_logic;
  signal obs_tg_lfsr_single_w   : std_logic;
  signal obs_tg_lfsr_double_w   : std_logic;
  signal obs_tm_tmr_error_w     : std_logic;
  signal obs_tm_state_single_w  : std_logic;
  signal obs_tm_state_double_w  : std_logic;
  signal obs_tm_counter_single_w : std_logic;
  signal obs_tm_counter_double_w : std_logic;
  signal obs_tm_correct_counter_single_w : std_logic;
  signal obs_tm_correct_counter_double_w : std_logic;
  signal obs_noc_lb_done_error_w : std_logic;
  signal tm_transaction_count_w : std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
  signal tm_correct_transaction_count_w : std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);

  signal obs_lb_tmr_error_w      : std_logic;
  signal obs_lb_payload_single_w : std_logic;
  signal obs_lb_payload_double_w : std_logic;
  signal obs_lb_rdata_single_w   : std_logic;
  signal obs_lb_rdata_double_w   : std_logic;
  signal obs_lb_id_single_w      : std_logic;
  signal obs_lb_id_double_w      : std_logic;

  signal obs_start_go_error_w        : std_logic;
  signal obs_status_tmr_error_w       : std_logic;
  signal obs_sub_inj_buffer_single_w   : std_logic;
  signal obs_sub_inj_buffer_double_w   : std_logic;
  signal obs_sub_inj_buffer_ctrl_error_w : std_logic;
  signal obs_sub_inj_integrity_single_w : std_logic;
  signal obs_sub_inj_integrity_double_w : std_logic;
  signal obs_sub_inj_flow_error_w      : std_logic;
  signal obs_sub_inj_pktz_error_w      : std_logic;
  signal obs_sub_rx_buffer_single_w    : std_logic;
  signal obs_sub_rx_buffer_double_w    : std_logic;
  signal obs_sub_rx_buffer_ctrl_error_w : std_logic;
  signal obs_rx_h_src_single_w        : std_logic;
  signal obs_rx_h_src_double_w        : std_logic;
  signal obs_rx_h_interface_single_w  : std_logic;
  signal obs_rx_h_interface_double_w  : std_logic;
  signal obs_rx_h_address_single_w    : std_logic;
  signal obs_rx_h_address_double_w    : std_logic;
  signal obs_sub_rx_integrity_single_w : std_logic;
  signal obs_sub_rx_integrity_double_w : std_logic;
  signal obs_sub_rx_flow_error_w       : std_logic;
  signal obs_sub_rx_depktz_error_w     : std_logic;

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of mismatch_w : signal is "TRUE";
  attribute DONT_TOUCH of corrupt_packet_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_command_ctrl_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_encode_critical_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_rx_count_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_rx_count_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_correct_count_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_correct_count_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_flags_seen_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_flags_seen_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_event_flags_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_event_flags_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_report_flags_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_uart_report_flags_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tg_tmr_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tg_lfsr_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tg_lfsr_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_tmr_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_state_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_state_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_counter_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_counter_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_correct_counter_correct_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_correct_counter_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_tm_correct_counter_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_noc_lb_done_error_w : signal is "TRUE";
  attribute DONT_TOUCH of tm_correct_transaction_count_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_tmr_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_payload_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_payload_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_rdata_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_rdata_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_id_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_lb_id_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_start_go_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_status_tmr_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_buffer_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_buffer_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_buffer_ctrl_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_integrity_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_integrity_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_flow_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_inj_pktz_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_buffer_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_buffer_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_buffer_ctrl_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_rx_h_src_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_rx_h_src_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_rx_h_interface_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_rx_h_interface_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_rx_h_address_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_rx_h_address_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_integrity_single_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_integrity_double_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_flow_error_w : signal is "TRUE";
  attribute DONT_TOUCH of obs_sub_rx_depktz_error_w : signal is "TRUE";
  attribute syn_preserve of mismatch_w : signal is true;
  attribute syn_preserve of corrupt_packet_w : signal is true;
  attribute syn_preserve of obs_uart_command_ctrl_error_w : signal is true;
  attribute syn_preserve of obs_uart_encode_critical_error_w : signal is true;
  attribute syn_preserve of obs_uart_rx_count_single_w : signal is true;
  attribute syn_preserve of obs_uart_rx_count_double_w : signal is true;
  attribute syn_preserve of obs_uart_correct_count_single_w : signal is true;
  attribute syn_preserve of obs_uart_correct_count_double_w : signal is true;
  attribute syn_preserve of obs_uart_flags_seen_single_w : signal is true;
  attribute syn_preserve of obs_uart_flags_seen_double_w : signal is true;
  attribute syn_preserve of obs_uart_event_flags_single_w : signal is true;
  attribute syn_preserve of obs_uart_event_flags_double_w : signal is true;
  attribute syn_preserve of obs_uart_report_flags_single_w : signal is true;
  attribute syn_preserve of obs_uart_report_flags_double_w : signal is true;
  attribute syn_preserve of obs_tg_tmr_error_w : signal is true;
  attribute syn_preserve of obs_tg_lfsr_single_w : signal is true;
  attribute syn_preserve of obs_tg_lfsr_double_w : signal is true;
  attribute syn_preserve of obs_tm_tmr_error_w : signal is true;
  attribute syn_preserve of obs_tm_state_single_w : signal is true;
  attribute syn_preserve of obs_tm_state_double_w : signal is true;
  attribute syn_preserve of obs_tm_counter_single_w : signal is true;
  attribute syn_preserve of obs_tm_counter_double_w : signal is true;
  attribute syn_preserve of obs_tm_correct_counter_correct_w : signal is true;
  attribute syn_preserve of obs_tm_correct_counter_single_w : signal is true;
  attribute syn_preserve of obs_tm_correct_counter_double_w : signal is true;
  attribute syn_preserve of obs_noc_lb_done_error_w : signal is true;
  attribute syn_preserve of tm_correct_transaction_count_w : signal is true;
  attribute syn_preserve of obs_lb_tmr_error_w : signal is true;
  attribute syn_preserve of obs_lb_payload_single_w : signal is true;
  attribute syn_preserve of obs_lb_payload_double_w : signal is true;
  attribute syn_preserve of obs_lb_rdata_single_w : signal is true;
  attribute syn_preserve of obs_lb_rdata_double_w : signal is true;
  attribute syn_preserve of obs_lb_id_single_w : signal is true;
  attribute syn_preserve of obs_lb_id_double_w : signal is true;
  attribute syn_preserve of obs_start_go_error_w : signal is true;
  attribute syn_preserve of obs_status_tmr_error_w : signal is true;
  attribute syn_preserve of obs_sub_inj_buffer_single_w : signal is true;
  attribute syn_preserve of obs_sub_inj_buffer_double_w : signal is true;
  attribute syn_preserve of obs_sub_inj_buffer_ctrl_error_w : signal is true;
  attribute syn_preserve of obs_sub_inj_integrity_single_w : signal is true;
  attribute syn_preserve of obs_sub_inj_integrity_double_w : signal is true;
  attribute syn_preserve of obs_sub_inj_flow_error_w : signal is true;
  attribute syn_preserve of obs_sub_inj_pktz_error_w : signal is true;
  attribute syn_preserve of obs_sub_rx_buffer_single_w : signal is true;
  attribute syn_preserve of obs_sub_rx_buffer_double_w : signal is true;
  attribute syn_preserve of obs_sub_rx_buffer_ctrl_error_w : signal is true;
  attribute syn_preserve of obs_rx_h_src_single_w : signal is true;
  attribute syn_preserve of obs_rx_h_src_double_w : signal is true;
  attribute syn_preserve of obs_rx_h_interface_single_w : signal is true;
  attribute syn_preserve of obs_rx_h_interface_double_w : signal is true;
  attribute syn_preserve of obs_rx_h_address_single_w : signal is true;
  attribute syn_preserve of obs_rx_h_address_double_w : signal is true;
  attribute syn_preserve of obs_sub_rx_integrity_single_w : signal is true;
  attribute syn_preserve of obs_sub_rx_integrity_double_w : signal is true;
  attribute syn_preserve of obs_sub_rx_flow_error_w : signal is true;
  attribute syn_preserve of obs_sub_rx_depktz_error_w : signal is true;
begin
  u_uart: entity work.uart
    port map(
      baud_div_i => uart_baud_div_w,
      parity_i   => uart_parity_w,
      rtscts_i   => uart_rtscts_w,
      tready_o   => uart_tready_w,
      tstart_i   => uart_tstart_w,
      tdata_i    => uart_tdata_w,
      tdone_o    => uart_tdone_w,
      rready_i   => uart_rready_w,
      rdone_o    => uart_rdone_w,
      rdata_o    => uart_rdata_w,
      rerr_o     => uart_rerr_w,
      rstn_i     => ARESETn,
      clk_i      => ACLK,
      uart_rx_i  => uart_rx_i,
      uart_tx_o  => uart_tx_o,
      uart_cts_i => uart_cts_i,
      uart_rts_o => uart_rts_o
    );

  u_uart_obs: entity work.subordinate_uart_obs_block
    generic map(
      G_REPORT_PERIOD_PACKETS => c_SUB_TM_UART_REPORT_PERIOD_PACKETS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      tm_done_i => tm_done_pulse_w,
      TM_RECEIVED_COUNT_i => tm_transaction_count_w,
      TM_CORRECT_COUNT_i => tm_correct_transaction_count_w,
      mismatch_i => mismatch_w,
      corrupt_packet_i => corrupt_packet_w,
      OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_i => obs_uart_encode_critical_error_w,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_i => obs_sub_rx_depktz_error_w,
      OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_i => obs_sub_rx_flow_error_w,
      OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_i => obs_sub_rx_integrity_double_w,
      OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_i => obs_sub_rx_integrity_single_w,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_i => obs_sub_rx_buffer_ctrl_error_w,
      OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_i => obs_sub_rx_buffer_double_w,
      OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_i => obs_sub_rx_buffer_single_w,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_i => obs_sub_inj_pktz_error_w,
      OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_i => obs_sub_inj_flow_error_w,
      OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_i => obs_sub_inj_integrity_double_w,
      OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_i => obs_sub_inj_integrity_single_w,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i => obs_sub_inj_buffer_ctrl_error_w,
      OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_i => obs_sub_inj_buffer_double_w,
      OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_i => obs_sub_inj_buffer_single_w,
      OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_i => obs_rx_h_address_double_w,
      OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_i => obs_rx_h_address_single_w,
      OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_i => obs_rx_h_interface_double_w,
      OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_i => obs_rx_h_interface_single_w,
      OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_i => obs_rx_h_src_double_w,
      OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_i => obs_rx_h_src_single_w,
      OBS_SUB_FE_INJ_TMR_STATUS_ERROR_i => obs_status_tmr_error_w,
      OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_i => obs_tg_lfsr_double_w,
      OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_i => obs_tg_lfsr_single_w,
      OBS_SUB_TG_TMR_CTRL_ERROR_i => obs_tg_tmr_error_w,
      OBS_SUB_NOC_LB_TMR_DONE_CTRL_ERROR_i => obs_noc_lb_done_error_w,
      OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_i => obs_lb_id_double_w,
      OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_i => obs_lb_id_single_w,
      OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_i => obs_lb_rdata_double_w,
      OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_i => obs_lb_rdata_single_w,
      OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_i => obs_lb_payload_double_w,
      OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_i => obs_lb_payload_single_w,
      OBS_SUB_LB_TMR_CTRL_ERROR_i => obs_lb_tmr_error_w,
      OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_i => obs_tm_counter_double_w,
      OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_i => obs_tm_counter_single_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_i => obs_tm_correct_counter_double_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_i => obs_tm_correct_counter_single_w,
      OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_i => obs_tm_state_double_w,
      OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_i => obs_tm_state_single_w,
      OBS_SUB_TM_TMR_CTRL_ERROR_i => obs_tm_tmr_error_w,
      OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o => obs_tg_tmr_correct_w,
      OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o => obs_tg_ham_correct_w,
      OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o => obs_tm_tmr_correct_w,
      OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o => obs_tm_ham_correct_w,
      OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o => obs_tm_counter_correct_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_o => obs_tm_correct_counter_correct_w,
      OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o => obs_lb_tmr_correct_w,
      OBS_SUB_NOC_LB_TMR_DONE_CTRL_CORRECT_ERROR_o => obs_noc_lb_done_correct_w,
      OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o => obs_lb_payload_correct_w,
      OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o => obs_lb_rdata_correct_w,
      OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o => obs_lb_id_correct_w,
      OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o => obs_start_go_correct_w,
      OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o => obs_fe_status_correct_w,
      OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o => obs_sub_inj_buffer_correct_w,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => obs_sub_inj_buffer_ctrl_correct_w,
      OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o => obs_sub_inj_integrity_correct_w,
      OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o => obs_sub_inj_flow_correct_w,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o => obs_sub_inj_pktz_correct_w,
      OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o => obs_sub_rx_buffer_correct_w,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => obs_sub_rx_buffer_ctrl_correct_w,
      OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o => obs_rx_h_src_correct_w,
      OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o => obs_rx_h_interface_correct_w,
      OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o => obs_rx_h_address_correct_w,
      OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o => obs_sub_rx_integrity_correct_w,
      OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o => obs_sub_rx_flow_correct_w,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o => obs_sub_rx_depktz_correct_w,
      OBS_SUB_UART_HAM_RX_COUNT_SINGLE_ERR_o => obs_uart_rx_count_single_w,
      OBS_SUB_UART_HAM_RX_COUNT_DOUBLE_ERR_o => obs_uart_rx_count_double_w,
      OBS_SUB_UART_HAM_CORRECT_COUNT_SINGLE_ERR_o => obs_uart_correct_count_single_w,
      OBS_SUB_UART_HAM_CORRECT_COUNT_DOUBLE_ERR_o => obs_uart_correct_count_double_w,
      OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o => obs_uart_flags_seen_single_w,
      OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o => obs_uart_flags_seen_double_w,
      OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o => obs_uart_event_flags_single_w,
      OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o => obs_uart_event_flags_double_w,
      OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o => obs_uart_report_flags_single_w,
      OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o => obs_uart_report_flags_double_w,
      OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o => obs_uart_command_ctrl_error_w,
      OBS_SUB_START_GO_CTRL_TMR_ERROR_o => obs_start_go_error_w,
      OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o => obs_uart_encode_critical_error_w,
      experiment_run_enable_o => open,
      experiment_reset_pulse_o => open,
      start_o => start_w,
      is_read_o => is_read_w,
      uart_baud_div_o => uart_baud_div_w,
      uart_parity_o   => uart_parity_w,
      uart_rtscts_o   => uart_rtscts_w,
      uart_tready_i => uart_tready_w,
      uart_tdone_i  => uart_tdone_w,
      uart_tstart_o => uart_tstart_w,
      uart_tdata_o  => uart_tdata_w,
      uart_rready_o => uart_rready_w,
      uart_rdone_i  => uart_rdone_w,
      uart_rdata_i  => uart_rdata_w,
      uart_rerr_i   => uart_rerr_w
    );

  u_system: entity work.subordinate_tg_tm_lb_system_top
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      start_i => start_w,
      is_read_i => is_read_w,
      address_i => C_SELFTEST_ADDR,
      seed_i => C_SELFTEST_SEED,
      done_o => done_w,
      tm_done_pulse_o => tm_done_pulse_w,
      mismatch_o => mismatch_w,
      corrupt_packet_o => corrupt_packet_w,
      OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i => obs_tg_tmr_correct_w,
      OBS_SUB_TG_TMR_CTRL_ERROR_o => obs_tg_tmr_error_w,
      OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i => obs_tg_ham_correct_w,
      OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o => obs_tg_lfsr_single_w,
      OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o => obs_tg_lfsr_double_w,
      OBS_SUB_TG_HAM_LFSR_ENC_DATA_o => open,
      OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i => obs_tm_tmr_correct_w,
      OBS_SUB_TM_TMR_CTRL_ERROR_o => obs_tm_tmr_error_w,
      OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i => obs_tm_ham_correct_w,
      OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o => obs_tm_state_single_w,
      OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o => obs_tm_state_double_w,
      OBS_SUB_TM_HAM_LFSR_ENC_DATA_o => open,
      OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i => obs_tm_counter_correct_w,
      OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o => obs_tm_counter_single_w,
      OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o => obs_tm_counter_double_w,
      OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o => open,
      TM_TRANSACTION_COUNT_o => tm_transaction_count_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_i => obs_tm_correct_counter_correct_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_o => obs_tm_correct_counter_single_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_o => obs_tm_correct_counter_double_w,
      OBS_SUB_TM_HAM_CORRECT_COUNTER_ENC_DATA_o => open,
      TM_CORRECT_TRANSACTION_COUNT_o => tm_correct_transaction_count_w,
      OBS_SUB_NOC_LB_TMR_DONE_CTRL_CORRECT_ERROR_i => obs_noc_lb_done_correct_w,
      OBS_SUB_NOC_LB_TMR_DONE_CTRL_ERROR_o => obs_noc_lb_done_error_w,
      OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_i => obs_lb_tmr_correct_w,
      OBS_SUB_LB_TMR_CTRL_ERROR_o => obs_lb_tmr_error_w,
      OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i => obs_lb_payload_correct_w,
      OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o => obs_lb_payload_single_w,
      OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o => obs_lb_payload_double_w,
      OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o => open,
      OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i => obs_lb_rdata_correct_w,
      OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o => obs_lb_rdata_single_w,
      OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o => obs_lb_rdata_double_w,
      OBS_SUB_LB_HAM_RDATA_ENC_DATA_o => open,
      OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i => obs_lb_id_correct_w,
      OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o => obs_lb_id_single_w,
      OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o => obs_lb_id_double_w,
      OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o => open,
      OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_i => obs_fe_status_correct_w,
      OBS_SUB_FE_INJ_TMR_STATUS_ERROR_o => obs_status_tmr_error_w,
      OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i => obs_sub_inj_buffer_correct_w,
      OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o => obs_sub_inj_buffer_single_w,
      OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o => obs_sub_inj_buffer_double_w,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => obs_sub_inj_buffer_ctrl_correct_w,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o => obs_sub_inj_buffer_ctrl_error_w,
      OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => obs_sub_inj_integrity_correct_w,
      OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o => obs_sub_inj_integrity_single_w,
      OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o => obs_sub_inj_integrity_double_w,
      OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => obs_sub_inj_flow_correct_w,
      OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o => obs_sub_inj_flow_error_w,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => obs_sub_inj_pktz_correct_w,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o => obs_sub_inj_pktz_error_w,
      OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i => obs_sub_rx_buffer_correct_w,
      OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o => obs_sub_rx_buffer_single_w,
      OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o => obs_sub_rx_buffer_double_w,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => obs_sub_rx_buffer_ctrl_correct_w,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o => obs_sub_rx_buffer_ctrl_error_w,
      OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i => obs_rx_h_src_correct_w,
      OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o => obs_rx_h_src_single_w,
      OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o => obs_rx_h_src_double_w,
      OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o => open,
      OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i => obs_rx_h_interface_correct_w,
      OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o => obs_rx_h_interface_single_w,
      OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o => obs_rx_h_interface_double_w,
      OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o => open,
      OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i => obs_rx_h_address_correct_w,
      OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o => obs_rx_h_address_single_w,
      OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o => obs_rx_h_address_double_w,
      OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o => open,
      OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i => obs_sub_rx_integrity_correct_w,
      OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o => obs_sub_rx_integrity_single_w,
      OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o => obs_sub_rx_integrity_double_w,
      OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i => obs_sub_rx_flow_correct_w,
      OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o => obs_sub_rx_flow_error_w,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i => obs_sub_rx_depktz_correct_w,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o => obs_sub_rx_depktz_error_w
    );
end architecture;
