library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for tg_tm_lb_selftest_obs_control.
-- Same style used by other control TMR blocks in TG/TM/LB:
-- * 3 replicas
-- * majority vote on outputs
-- * disagreement flag (error_o)
-- * optional correction bypass via correct_enable_i
entity tg_tm_lb_selftest_obs_control_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    experiment_run_enable_i  : in  std_logic;
    experiment_reset_pulse_i : in  std_logic;
    tg_done_i : in  std_logic;
    tm_done_i : in  std_logic;

    tg_start_o : out std_logic;
    tm_start_o : out std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_control_tmr is
  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal tg_start_w : tmr_sl_t;
  signal tm_start_w : tmr_sl_t;

  signal corr_tg_start_w : std_logic;
  signal corr_tm_start_w : std_logic;

  signal err_tg_start_w : std_logic;
  signal err_tm_start_w : std_logic;

  function maj3(a, b, c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  function dis3(a, b, c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;
begin
  gen_ctrl : for i in 0 to 2 generate
  begin
    u_obs_ctrl : entity work.tg_tm_lb_selftest_obs_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        experiment_run_enable_i  => experiment_run_enable_i,
        experiment_reset_pulse_i => experiment_reset_pulse_i,
        tg_done_i => tg_done_i,
        tm_done_i => tm_done_i,
        tg_start_o => tg_start_w(i),
        tm_start_o => tm_start_w(i)
      );
  end generate;

  corr_tg_start_w <= maj3(tg_start_w(2), tg_start_w(1), tg_start_w(0));
  corr_tm_start_w <= maj3(tm_start_w(2), tm_start_w(1), tm_start_w(0));

  err_tg_start_w <= dis3(tg_start_w(2), tg_start_w(1), tg_start_w(0));
  err_tm_start_w <= dis3(tm_start_w(2), tm_start_w(1), tm_start_w(0));

  error_o <= err_tg_start_w or err_tm_start_w;

  tg_start_o <= corr_tg_start_w when correct_enable_i = '1' else tg_start_w(0);
  tm_start_o <= corr_tm_start_w when correct_enable_i = '1' else tm_start_w(0);
end architecture;
