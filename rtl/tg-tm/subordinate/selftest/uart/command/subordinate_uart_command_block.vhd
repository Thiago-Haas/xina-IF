library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_subordinate_ni_pkg.all;

entity subordinate_uart_command_block is
  generic(
    p_USE_UART_COMMAND_CTRL_TMR : boolean := c_ENABLE_SUB_OBS_UART_COMMAND_CTRL_TMR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    uart_rdone_i : in  std_logic;
    uart_rdata_i : in  std_logic_vector(7 downto 0);
    uart_rerr_i  : in  std_logic;

    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;

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
    OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_command_block is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
  signal correction_enable_w : std_logic;
begin
  gen_command_plain : if not p_USE_UART_COMMAND_CTRL_TMR generate
    attribute DONT_TOUCH of u_control : label is "TRUE";
    attribute syn_preserve of u_control : label is true;
    attribute KEEP_HIERARCHY of u_control : label is "TRUE";
  begin
    u_control: entity work.subordinate_uart_command_control
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        uart_rdone_i => uart_rdone_i,
        uart_rdata_i => uart_rdata_i,
        uart_rerr_i => uart_rerr_i,
        run_enable_o => experiment_run_enable_o,
        reset_pulse_o => experiment_reset_pulse_o,
        correction_enable_o => correction_enable_w
      );
    OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o <= '0';
  end generate;

  gen_command_tmr : if p_USE_UART_COMMAND_CTRL_TMR generate
  begin
    u_control_tmr: entity work.subordinate_uart_command_control_tmr
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        uart_rdone_i => uart_rdone_i,
        uart_rdata_i => uart_rdata_i,
        uart_rerr_i => uart_rerr_i,
        run_enable_o => experiment_run_enable_o,
        reset_pulse_o => experiment_reset_pulse_o,
        correction_enable_o => correction_enable_w,
        correct_enable_i => '1',
        error_o => OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o
      );
  end generate;

  u_datapath: entity work.subordinate_uart_command_datapath
    port map(
      correction_enable_i => correction_enable_w,
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
      OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o
    );
end architecture;
