library IEEE;
use IEEE.std_logic_1164.all;

-- Datapath fanout for UART-driven correct-error enables.
entity manager_uart_command_datapath is
  port (
    command_enable_i : in std_logic;

    OBS_TM_HAM_BUFFER_CORRECT_ERROR_o : out std_logic;
    OBS_TM_TMR_CTRL_CORRECT_ERROR_o   : out std_logic;
    OBS_TM_HAM_RECEIVED_COUNTER_CORRECT_ERROR_o : out std_logic;
    OBS_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_o  : out std_logic;

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
    OBS_UART_COMMAND_CTRL_TMR_CORRECT_ERROR_o : out std_logic;
    OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o : out std_logic
  );
end entity;

architecture rtl of manager_uart_command_datapath is
begin
  OBS_TM_HAM_BUFFER_CORRECT_ERROR_o <= command_enable_i;
  OBS_TM_TMR_CTRL_CORRECT_ERROR_o <= command_enable_i;
  OBS_TM_HAM_RECEIVED_COUNTER_CORRECT_ERROR_o <= command_enable_i;
  OBS_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_o <= command_enable_i;

  OBS_LB_HAM_BUFFER_CORRECT_ERROR_o <= command_enable_i;
  OBS_LB_TMR_CTRL_CORRECT_ERROR_o <= command_enable_i;

  OBS_TG_HAM_BUFFER_CORRECT_ERROR_o <= command_enable_i;
  OBS_TG_TMR_CTRL_CORRECT_ERROR_o <= command_enable_i;

  OBS_FE_INJ_META_HDR_CORRECT_ERROR_o <= command_enable_i;
  OBS_FE_INJ_ADDR_CORRECT_ERROR_o <= command_enable_i;

  OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o <= command_enable_i;

  OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o <= command_enable_i;
  OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o <= command_enable_i;
  OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o <= command_enable_i;
  OBS_UART_COMMAND_CTRL_TMR_CORRECT_ERROR_o <= command_enable_i;
  OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o <= command_enable_i;
end architecture;
