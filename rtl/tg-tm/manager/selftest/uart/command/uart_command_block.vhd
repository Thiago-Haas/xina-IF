library IEEE;
use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

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
    OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o : out std_logic;
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
  constant C_CORRECTION_WIDTH : natural := 22;

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
      uart_command_ctrl_tmr_error_o => OBS_UART_COMMAND_CTRL_TMR_ERROR_o
    );

  OBS_TM_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(21);
  OBS_TM_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(20);
  OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o <= correction_vector_w(19);
  OBS_LB_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(18);
  OBS_LB_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(17);
  OBS_TG_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(16);
  OBS_TG_TMR_CTRL_CORRECT_ERROR_o <= correction_vector_w(15);
  OBS_FE_INJ_META_HDR_CORRECT_ERROR_o <= correction_vector_w(14);
  OBS_FE_INJ_ADDR_CORRECT_ERROR_o <= correction_vector_w(13);
  OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(12);
  OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_vector_w(11);
  OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_vector_w(10);
  OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_vector_w(9);
  OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o <= correction_vector_w(8);
  OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o <= correction_vector_w(7);
  OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_o <= correction_vector_w(6);
  OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o <= correction_vector_w(5);
  OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o <= correction_vector_w(4);
  OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o <= correction_vector_w(3);
  OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o <= correction_vector_w(2);
  OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o <= correction_vector_w(1);
  OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o <= correction_vector_w(0);
end architecture;
