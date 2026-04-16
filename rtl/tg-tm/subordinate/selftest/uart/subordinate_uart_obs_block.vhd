library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_subordinate_ni_pkg.all;

-- Subordinate-only UART OBS block.
-- Hierarchy mirrors the manager shell, but only contains subordinate command
-- fanout and a compact subordinate report encoder.
entity subordinate_uart_obs_block is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := c_SUB_TM_UART_REPORT_PERIOD_PACKETS
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    TM_RECEIVED_COUNT_i : in std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    TM_CORRECT_COUNT_i  : in std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);

    mismatch_i : in std_logic;
    corrupt_packet_i : in std_logic;
    OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_i : in std_logic;
    OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_i : in std_logic;
    OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_i : in std_logic;
    OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_i : in std_logic;
    OBS_SUB_FE_INJ_TMR_STATUS_ERROR_i : in std_logic;
    OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_i : in std_logic;
    OBS_SUB_TG_TMR_CTRL_ERROR_i : in std_logic;
    OBS_SUB_NOC_LB_TMR_DONE_CTRL_ERROR_i : in std_logic;
    OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_i : in std_logic;
    OBS_SUB_LB_TMR_CTRL_ERROR_i : in std_logic;
    OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_i : in std_logic;
    OBS_SUB_TM_TMR_CTRL_ERROR_i : in std_logic;

    OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_NOC_LB_TMR_DONE_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_RX_COUNT_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_RX_COUNT_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_CORRECT_COUNT_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_CORRECT_COUNT_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o : out std_logic;
    OBS_SUB_START_GO_CTRL_TMR_ERROR_o : out std_logic;
    OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o : out std_logic;

    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;
    start_o                  : out std_logic;
    is_read_o                : out std_logic;

    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;
    uart_tready_i : in  std_logic;
    uart_tdone_i  : in  std_logic;
    uart_tstart_o : out std_logic;
    uart_tdata_o  : out std_logic_vector(7 downto 0);
    uart_rready_o : out std_logic;
    uart_rdone_i  : in  std_logic;
    uart_rdata_i  : in  std_logic_vector(7 downto 0);
    uart_rerr_i   : in  std_logic
  );
end entity;

architecture rtl of subordinate_uart_obs_block is
  constant C_CORRECTION_WIDTH : natural := 31;
  constant C_SUB_FLAGS_RESERVED_PAD : std_logic_vector(1 downto 0) := "00";

  signal flags_w : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);
  signal correction_vector_w : std_logic_vector(C_CORRECTION_WIDTH - 1 downto 0);
  signal obs_start_go_ctrl_error_w : std_logic;

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of flags_w : signal is "TRUE";
  attribute syn_preserve of flags_w : signal is true;
begin
  uart_rready_o <= '1';

  -- Upper FLAGS bits are reserved so the UART report remains nibble-aligned.
  flags_w <= C_SUB_FLAGS_RESERVED_PAD &
             OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_i &
             OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o &
             OBS_SUB_UART_HAM_CORRECT_COUNT_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_CORRECT_COUNT_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_RX_COUNT_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_RX_COUNT_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o &
             obs_start_go_ctrl_error_w &
             OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_i &
             OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_i &
             OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_i &
             OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_i &
             OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_i &
             OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_i &
             OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_i &
             OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_i &
             OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_i &
             OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_i &
             OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_i &
             OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i &
             OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_i &
             OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_i &
             OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_i &
             OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_i &
             OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_i &
             OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_i &
             OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_i &
             OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_i &
             OBS_SUB_FE_INJ_TMR_STATUS_ERROR_i &
             OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_i &
             OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_i &
             OBS_SUB_TG_TMR_CTRL_ERROR_i &
             OBS_SUB_NOC_LB_TMR_DONE_CTRL_ERROR_i &
             OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_i &
             OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_i &
             OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_i &
             OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_i &
             OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_i &
             OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_i &
             OBS_SUB_LB_TMR_CTRL_ERROR_i &
             OBS_SUB_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_i &
             OBS_SUB_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_i &
             OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_i &
             OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_i &
             OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_i &
             OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_i &
             OBS_SUB_TM_TMR_CTRL_ERROR_i &
             corrupt_packet_i &
             mismatch_i;

  u_control: entity work.selftest_obs_control_generic
    generic map(
      G_CORRECTION_WIDTH => C_CORRECTION_WIDTH,
      G_USE_UART_COMMAND_CTRL_TMR => c_ENABLE_SUB_OBS_UART_COMMAND_CTRL_TMR,
      G_USE_START_GO_CTRL_TMR => c_ENABLE_SUB_OBS_START_GO_CTRL_TMR
    )
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      uart_rdone_i => uart_rdone_i,
      uart_rdata_i => uart_rdata_i,
      uart_rerr_i => uart_rerr_i,
      done_i => tm_done_i,
      start_go_correct_enable_i => correction_vector_w(19),
      experiment_run_enable_o => experiment_run_enable_o,
      experiment_reset_pulse_o => experiment_reset_pulse_o,
      correction_vector_o => correction_vector_w,
      start_o => start_o,
      is_read_o => is_read_o,
      uart_command_ctrl_tmr_error_o => OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o,
      start_go_ctrl_tmr_error_o => obs_start_go_ctrl_error_w
    );

  OBS_SUB_START_GO_CTRL_TMR_ERROR_o <= obs_start_go_ctrl_error_w;

  OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(30);
  OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o <= correction_vector_w(29);
  OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(28);
  OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o <= correction_vector_w(27);
  OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o <= correction_vector_w(26);
  OBS_SUB_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_o <= correction_vector_w(25);
  OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(24);
  OBS_SUB_NOC_LB_TMR_DONE_CTRL_CORRECT_ERROR_o <= correction_vector_w(23);
  OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o <= correction_vector_w(22);
  OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o <= correction_vector_w(21);
  OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o <= correction_vector_w(20);
  OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o <= correction_vector_w(19);
  OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o <= correction_vector_w(18);
  OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(17);
  OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_vector_w(16);
  OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_vector_w(15);
  OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_vector_w(14);
  OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o <= correction_vector_w(13);
  OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(12);
  OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_vector_w(11);
  OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o <= correction_vector_w(10);
  OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o <= correction_vector_w(9);
  OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o <= correction_vector_w(8);
  OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_vector_w(7);
  OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_vector_w(6);
  OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o <= correction_vector_w(5);

  u_encode: entity work.subordinate_uart_encode_core_block
    generic map(
      G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
    )
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      tm_done_i => tm_done_i,
      TM_RECEIVED_COUNT_i => TM_RECEIVED_COUNT_i,
      TM_CORRECT_COUNT_i => TM_CORRECT_COUNT_i,
      flags_i => flags_w,
      OBS_SUB_UART_HAM_RX_COUNT_CORRECT_ERROR_i => correction_vector_w(4),
      OBS_SUB_UART_HAM_CORRECT_COUNT_CORRECT_ERROR_i => correction_vector_w(3),
      OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i => correction_vector_w(2),
      OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i => correction_vector_w(1),
      OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i => correction_vector_w(0),
      uart_baud_div_o => uart_baud_div_o,
      uart_parity_o => uart_parity_o,
      uart_rtscts_o => uart_rtscts_o,
      uart_tready_i => uart_tready_i,
      uart_tdone_i => uart_tdone_i,
      uart_tstart_o => uart_tstart_o,
      uart_tdata_o => uart_tdata_o,
      OBS_SUB_UART_HAM_RX_COUNT_SINGLE_ERR_o => OBS_SUB_UART_HAM_RX_COUNT_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_RX_COUNT_DOUBLE_ERR_o => OBS_SUB_UART_HAM_RX_COUNT_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_CORRECT_COUNT_SINGLE_ERR_o => OBS_SUB_UART_HAM_CORRECT_COUNT_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_CORRECT_COUNT_DOUBLE_ERR_o => OBS_SUB_UART_HAM_CORRECT_COUNT_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o,
      OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o => OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o
    );
end architecture;
