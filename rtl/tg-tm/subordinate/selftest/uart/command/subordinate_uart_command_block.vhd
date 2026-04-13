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
    OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o : out std_logic;
    OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_command_block is
  constant C_CORRECTION_WIDTH : natural := 29;
  signal correction_vector_w : std_logic_vector(C_CORRECTION_WIDTH - 1 downto 0);
begin
  u_command_generic: entity work.uart_obs_command_block_generic
    generic map(
      G_CORRECTION_WIDTH => C_CORRECTION_WIDTH,
      p_USE_UART_COMMAND_CTRL_TMR => p_USE_UART_COMMAND_CTRL_TMR
    )
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      uart_rdone_i => uart_rdone_i,
      uart_rdata_i => uart_rdata_i,
      uart_rerr_i => uart_rerr_i,
      experiment_run_enable_o => experiment_run_enable_o,
      experiment_reset_pulse_o => experiment_reset_pulse_o,
      correction_vector_o => correction_vector_w,
      uart_command_ctrl_tmr_error_o => OBS_SUB_UART_COMMAND_CTRL_TMR_ERROR_o
    );

  OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(28);
  OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_o <= correction_vector_w(27);
  OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(26);
  OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_o <= correction_vector_w(25);
  OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_o <= correction_vector_w(24);
  OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(23);
  OBS_SUB_NOC_LB_TMR_DONE_CTRL_CORRECT_ERROR_o <= correction_vector_w(22);
  OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_o <= correction_vector_w(21);
  OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_o <= correction_vector_w(20);
  OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_o <= correction_vector_w(19);
  OBS_SUB_START_GO_CTRL_TMR_CORRECT_ERROR_o <= correction_vector_w(18);
  OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_o <= correction_vector_w(17);
  OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(16);
  OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_vector_w(15);
  OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_vector_w(14);
  OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_vector_w(13);
  OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o <= correction_vector_w(12);
  OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(11);
  OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_vector_w(10);
  OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_o <= correction_vector_w(9);
  OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_o <= correction_vector_w(8);
  OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_o <= correction_vector_w(7);
  OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_vector_w(6);
  OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_vector_w(5);
  OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o <= correction_vector_w(4);
  OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_o <= correction_vector_w(3);
  OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_o <= correction_vector_w(2);
  OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_o <= correction_vector_w(1);
  OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_o <= correction_vector_w(0);
end architecture;
