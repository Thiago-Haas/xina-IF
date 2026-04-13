library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_subordinate_ni_pkg.all;

-- Subordinate-only UART OBS block.
-- Hierarchy mirrors the manager shell, but only contains subordinate command
-- fanout and a compact subordinate report encoder.
entity subordinate_uart_obs_block is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := 100
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    TM_TRANSACTION_COUNT_i : in std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);

    mismatch_i : in std_logic;
    corrupt_packet_i : in std_logic;
    OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_i : in std_logic;
    OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_i : in std_logic;
    OBS_SUB_START_GO_CTRL_TMR_ERROR_i : in std_logic;
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
    OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_i : in std_logic;
    OBS_SUB_LB_TMR_CTRL_ERROR_i : in std_logic;
    OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_i : in std_logic;
    OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_i : in std_logic;
    OBS_SUB_TM_TMR_CTRL_ERROR_i : in std_logic;

    OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o : out std_logic;
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
    OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o : out std_logic;
    OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o : out std_logic;

    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;

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
  constant C_SUB_FLAGS_RESERVED_PAD : std_logic_vector(2 downto 0) := "000";

  signal flags_w : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of flags_w : signal is "TRUE";
  attribute syn_preserve of flags_w : signal is true;
begin
  uart_rready_o <= '1';

  -- Upper FLAGS bits are reserved so the UART report remains nibble-aligned.
  flags_w <= C_SUB_FLAGS_RESERVED_PAD &
             OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_i &
             OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_i &
             OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o &
             OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o &
             OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o &
             OBS_SUB_START_GO_CTRL_TMR_ERROR_i &
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
             OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_i &
             OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_i &
             OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_i &
             OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_i &
             OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_i &
             OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_i &
             OBS_SUB_LB_TMR_CTRL_ERROR_i &
             OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_i &
             OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_i &
             OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_i &
             OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_i &
             OBS_SUB_TM_TMR_CTRL_ERROR_i &
             corrupt_packet_i &
             mismatch_i;

  u_command: entity work.subordinate_uart_command_block
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      uart_rdone_i => uart_rdone_i,
      uart_rdata_i => uart_rdata_i,
      uart_rerr_i => uart_rerr_i,
      experiment_run_enable_o => experiment_run_enable_o,
      experiment_reset_pulse_o => experiment_reset_pulse_o,
      OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o => OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o,
      OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o => OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o,
      OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o => OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o,
      OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o => OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o,
      OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o => OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o,
      OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o => OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o,
      OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o => OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o,
      OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o => OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o,
      OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o => OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o,
      OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o => OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o,
      OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o => OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o,
      OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o => OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
      OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o,
      OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o => OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o,
      OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o => OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
      OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o => OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o,
      OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o => OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o,
      OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o => OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o,
      OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o,
      OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o => OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o => OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o,
      OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o => OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o
    );

  u_encode: entity work.subordinate_uart_encode_core_block
    generic map(
      G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
    )
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      tm_done_i => tm_done_i,
      TM_TRANSACTION_COUNT_i => TM_TRANSACTION_COUNT_i,
      flags_i => flags_w,
      OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i => OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i => OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i => OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i => OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o,
      uart_baud_div_o => uart_baud_div_o,
      uart_parity_o => uart_parity_o,
      uart_rtscts_o => uart_rtscts_o,
      uart_tready_i => uart_tready_i,
      uart_tdone_i => uart_tdone_i,
      uart_tstart_o => uart_tstart_o,
      uart_tdata_o => uart_tdata_o,
      OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o => OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o => OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o,
      OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o => OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o
    );
end architecture;
