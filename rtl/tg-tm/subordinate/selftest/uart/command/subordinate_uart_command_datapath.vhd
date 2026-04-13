library IEEE;
use IEEE.std_logic_1164.all;

-- Fanout for UART-controlled subordinate correction enables.
entity subordinate_uart_command_datapath is
  port(
    correction_enable_i : in std_logic;

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
    OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_command_datapath is
begin
  OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o <= correction_enable_i;
  OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o <= correction_enable_i;
end architecture;
