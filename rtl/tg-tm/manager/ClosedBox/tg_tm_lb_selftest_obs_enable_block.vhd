library IEEE;
use IEEE.std_logic_1164.all;

-- Hierarchical observation-enable block:
-- * control: command decode and run/reset registers
-- * datapath: OBS enable fanout
entity tg_tm_lb_selftest_obs_enable_block is
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
    OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_enable_block is
  signal obs_enable_w : std_logic;
begin
  b_obs_enable_ctrl: block
  begin
    u_obs_enable_ctrl: entity work.tg_tm_lb_selftest_obs_enable_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        uart_rdone_i => uart_rdone_i,
        uart_rdata_i => uart_rdata_i,
        uart_rerr_i  => uart_rerr_i,
        run_enable_o  => experiment_run_enable_o,
        reset_pulse_o => experiment_reset_pulse_o,
        obs_enable_o  => obs_enable_w
      );
  end block;

  b_obs_enable_datapath: block
  begin
    u_obs_enable_dp: entity work.tg_tm_lb_selftest_obs_enable_dp
      port map(
        obs_enable_i => obs_enable_w,
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
        OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o => OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_o
      );
  end block;
end architecture;
