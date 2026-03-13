library IEEE;
use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

-- Hierarchical UART command block:
-- * control: UART command decode and run/reset registers
-- * datapath: correct-error enable fanout toward the DUT
entity selftest_uart_command_block is
  generic (
    p_USE_UART_COMMAND_CTRL_TMR : boolean := c_ENABLE_OBS_UART_COMMAND_CTRL_TMR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    uart_rdone_i : in  std_logic;
    uart_rdata_i : in  std_logic_vector(7 downto 0);
    uart_rerr_i  : in  std_logic;

    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;

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
    OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o : out std_logic;
    OBS_UART_COMMAND_CTRL_TMR_ERROR_o       : out std_logic;
    OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o : out std_logic
  );
end entity;

architecture rtl of selftest_uart_command_block is
  signal command_enable_w : std_logic;
  signal uart_command_ctrl_tmr_error_w : std_logic;
  signal uart_command_ctrl_tmr_correct_enable_w : std_logic;
  signal uart_command_ctrl_tmr_correct_enable_gate_w : std_logic;
begin
  uart_command_ctrl_tmr_correct_enable_gate_w <= uart_command_ctrl_tmr_correct_enable_w when c_ENABLE_OBS_UART_COMMAND_CTRL_TMR_CORRECTION else '0';

  b_uart_command_control_plain : if not p_USE_UART_COMMAND_CTRL_TMR generate
  begin
    u_uart_command_control: entity work.selftest_uart_command_control
      port map(
        ACLK             => ACLK,
        ARESETn          => ARESETn,
        uart_rdone_i     => uart_rdone_i,
        uart_rdata_i     => uart_rdata_i,
        uart_rerr_i      => uart_rerr_i,
        run_enable_o     => experiment_run_enable_o,
        reset_pulse_o    => experiment_reset_pulse_o,
        command_enable_o => command_enable_w
      );
    uart_command_ctrl_tmr_error_w <= '0';
    uart_command_ctrl_tmr_correct_enable_w <= '0';
  end generate;

  b_uart_command_control_tmr : if p_USE_UART_COMMAND_CTRL_TMR generate
  begin
    u_uart_command_control_tmr: entity work.selftest_uart_command_control_tmr
      port map(
        ACLK             => ACLK,
        ARESETn          => ARESETn,
        uart_rdone_i     => uart_rdone_i,
        uart_rdata_i     => uart_rdata_i,
        uart_rerr_i      => uart_rerr_i,
        run_enable_o     => experiment_run_enable_o,
        reset_pulse_o    => experiment_reset_pulse_o,
        command_enable_o => command_enable_w,
        correct_enable_i => uart_command_ctrl_tmr_correct_enable_gate_w,
        error_o          => uart_command_ctrl_tmr_error_w
      );
  end generate;

  OBS_UART_COMMAND_CTRL_TMR_ERROR_o <= uart_command_ctrl_tmr_error_w;

  b_uart_command_datapath: block
  begin
    u_uart_command_datapath: entity work.selftest_uart_command_datapath
      port map(
        command_enable_i => command_enable_w,
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
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o,
        OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o,
        OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o,
        OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o,
        OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o => OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o,
        OBS_UART_COMMAND_CTRL_TMR_CORRECT_ERROR_o => uart_command_ctrl_tmr_correct_enable_w,
        OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o => OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o
      );
  end block;
end architecture;
