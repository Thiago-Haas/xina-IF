library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- Closed-box self-test top:
--   Inputs: ACLK, ARESETn
--   Internally instantiates TG+TM+NI+loopback (tg_tm_lb_top)
--   and an observation block that is split into control/datapath.

entity tg_tm_lb_selftest_top is
  port (
    ACLK    : in std_logic;
    ARESETn : in std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_top is

  -- TG control
  signal tg_start : std_logic;
  signal tg_done  : std_logic;
  signal tg_addr  : std_logic_vector(63 downto 0);
  signal tg_seed  : std_logic_vector(31 downto 0);

  -- TM control
  signal tm_start : std_logic;
  signal tm_done  : std_logic;
  signal tm_addr  : std_logic_vector(63 downto 0);
  signal tm_seed  : std_logic_vector(31 downto 0);

  -- TM observability (kept internal; view in waves if needed)
  signal tm_lfsr_comparison_mismatch : std_logic;

  -- self-test status (kept internal)
  signal selftest_error : std_logic;

begin

  u_ctrl: entity work.tg_tm_lb_selftest_observation_block
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      o_tg_start => tg_start,
      i_tg_done  => tg_done,
      o_tg_addr  => tg_addr,
      o_tg_seed  => tg_seed,

      o_tm_start => tm_start,
      i_tm_done  => tm_done,
      o_tm_addr  => tm_addr,
      o_tm_seed  => tm_seed,

      i_tm_lfsr_comparison_mismatch => tm_lfsr_comparison_mismatch,
      o_error       => selftest_error
    );

  u_dut: entity work.tg_tm_lb_top
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start       => tg_start,
      o_tg_done        => tg_done,
      TG_INPUT_ADDRESS => tg_addr,
      TG_STARTING_SEED => tg_seed,

      i_tm_start       => tm_start,
      o_tm_done        => tm_done,
      TM_INPUT_ADDRESS => tm_addr,
      TM_STARTING_SEED => tm_seed,

      o_tm_lfsr_comparison_mismatch => tm_lfsr_comparison_mismatch,
      o_tm_expected_value => open,
      o_OBS_TM_TMR_CTRL_ERROR        => open,
      o_OBS_TM_HAM_BUFFER_SINGLE_ERR => open,
      o_OBS_TM_HAM_BUFFER_DOUBLE_ERR => open,
      o_OBS_TM_HAM_BUFFER_ENC_DATA   => open,
      o_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR => open,
      o_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR => open,
      o_OBS_TM_HAM_TXN_COUNTER_ENC_DATA   => open,
      o_TM_TRANSACTION_COUNT              => open,
      o_OBS_LB_TMR_CTRL_ERROR        => open,
      o_OBS_LB_HAM_BUFFER_SINGLE_ERR => open,
      o_OBS_LB_HAM_BUFFER_DOUBLE_ERR => open,
      o_OBS_LB_HAM_BUFFER_ENC_DATA   => open,

      o_OBS_TG_TMR_CTRL_ERROR        => open,
      o_OBS_TG_HAM_BUFFER_SINGLE_ERR => open,
      o_OBS_TG_HAM_BUFFER_DOUBLE_ERR => open,
      o_OBS_TG_HAM_BUFFER_ENC_DATA   => open,

      o_OBS_FE_INJ_META_HDR_SINGLE_ERR => open,
      o_OBS_FE_INJ_META_HDR_DOUBLE_ERR => open,
      o_OBS_FE_INJ_ADDR_SINGLE_ERR     => open,
      o_OBS_FE_INJ_ADDR_DOUBLE_ERR     => open,
      o_OBS_FE_INJ_HAM_META_HDR_ENC_DATA => open,
      o_OBS_FE_INJ_HAM_ADDR_ENC_DATA     => open,

      o_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR => open,
      o_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR => open,
      o_OBS_BE_INJ_HAM_BUFFER_ENC_DATA   => open,
      o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR => open,
      o_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR => open,
      o_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR => open,
      o_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA   => open,
      o_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR   => open,
      o_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR   => open,

      o_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR => open,
      o_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR => open,
      o_OBS_BE_RX_HAM_BUFFER_ENC_DATA   => open,
      o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR => open,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR => open,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR => open,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA   => open,
      o_OBS_BE_RX_INTEGRITY_CORRUPT     => open,
      o_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR => open,
      o_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR => open,
      o_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA   => open,
      o_OBS_BE_RX_TMR_FLOW_CTRL_ERROR   => open,

      o_NI_CORRUPT_PACKET => open
    );

end architecture;
