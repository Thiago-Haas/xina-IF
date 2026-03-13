library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_ni_ft_pkg.all;

-- TMR wrapper for selftest_obs_uart_encode_critical.
entity selftest_obs_uart_encode_critical_tmr is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i        : in  std_logic;
    report_consume_i : in  std_logic;

    tm_done_rise_o      : out std_logic;
    period_report_due_o : out std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of selftest_obs_uart_encode_critical_tmr is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal tm_done_rise_w      : tmr_sl_t;
  signal period_report_due_w : tmr_sl_t;

  signal corr_tm_done_rise_w      : std_logic;
  signal corr_period_report_due_w : std_logic;

  signal err_tm_done_rise_w      : std_logic;
  signal err_period_report_due_w : std_logic;

  function maj3(a, b, c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  function dis3(a, b, c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;
begin
  gen_critical : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_uart_encode_critical : label is "TRUE";
    attribute syn_preserve of u_uart_encode_critical : label is true;
    attribute KEEP_HIERARCHY of u_uart_encode_critical : label is "TRUE";
  begin
    u_uart_encode_critical : entity work.selftest_obs_uart_encode_critical
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK                => ACLK,
        ARESETn             => ARESETn,
        tm_done_i           => tm_done_i,
        report_consume_i    => report_consume_i,
        tm_done_rise_o      => tm_done_rise_w(i),
        period_report_due_o => period_report_due_w(i)
      );
  end generate;

  corr_tm_done_rise_w      <= maj3(tm_done_rise_w(2), tm_done_rise_w(1), tm_done_rise_w(0));
  corr_period_report_due_w <= maj3(period_report_due_w(2), period_report_due_w(1), period_report_due_w(0));

  err_tm_done_rise_w      <= dis3(tm_done_rise_w(2), tm_done_rise_w(1), tm_done_rise_w(0));
  err_period_report_due_w <= dis3(period_report_due_w(2), period_report_due_w(1), period_report_due_w(0));

  error_o <= err_tm_done_rise_w or err_period_report_due_w;

  tm_done_rise_o      <= corr_tm_done_rise_w when correct_enable_i = '1' else tm_done_rise_w(0);
  period_report_due_o <= corr_period_report_due_w when correct_enable_i = '1' else period_report_due_w(0);
end architecture;
