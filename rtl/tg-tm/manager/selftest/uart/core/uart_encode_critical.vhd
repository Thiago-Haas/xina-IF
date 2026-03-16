library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- Critical timing/state block for UART periodic reporting.
-- Keeps only the registers that decide when a report is triggered.
entity selftest_obs_uart_encode_critical is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;
    tm_done_i : in std_logic;
    report_consume_i : in std_logic;

    tm_done_rise_o    : out std_logic;
    period_report_due_o : out std_logic
  );
end entity;

architecture rtl of selftest_obs_uart_encode_critical is
  signal tm_done_d_r        : std_logic := '0';
  function f_counter_width(max_value : positive) return natural is
    variable width_v : natural := 1;
    variable limit_v : natural := 2;
  begin
    while limit_v < max_value loop
      width_v := width_v + 1;
      limit_v := limit_v * 2;
    end loop;
    return width_v;
  end function;

  constant C_REPORT_COUNTER_WIDTH : natural := f_counter_width(G_REPORT_PERIOD_PACKETS);

  signal report_counter_r   : std_logic_vector(C_REPORT_COUNTER_WIDTH - 1 downto 0) := (others => '0');
  signal period_report_due_r : std_logic := '0';

  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of tm_done_d_r : signal is "TRUE";
  attribute DONT_TOUCH of report_counter_r : signal is "TRUE";
  attribute DONT_TOUCH of period_report_due_r : signal is "TRUE";
  attribute syn_preserve : boolean;
  attribute syn_preserve of tm_done_d_r : signal is true;
  attribute syn_preserve of report_counter_r : signal is true;
  attribute syn_preserve of period_report_due_r : signal is true;
begin
  tm_done_rise_o      <= tm_done_i and (not tm_done_d_r);
  period_report_due_o <= period_report_due_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        tm_done_d_r         <= '0';
        report_counter_r    <= (others => '0');
        period_report_due_r <= '0';
      else
        tm_done_d_r <= tm_done_i;

        if report_consume_i = '1' then
          period_report_due_r <= '0';
        end if;

        if (tm_done_i = '1') and (tm_done_d_r = '0') then
          if unsigned(report_counter_r) = to_unsigned(G_REPORT_PERIOD_PACKETS - 1, C_REPORT_COUNTER_WIDTH) then
            report_counter_r    <= (others => '0');
            period_report_due_r <= '1';
          else
            report_counter_r <= std_logic_vector(unsigned(report_counter_r) + 1);
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
