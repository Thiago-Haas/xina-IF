library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for subordinate_uart_encode_critical.
entity subordinate_uart_encode_critical_tmr is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := 100
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    report_consume_i : in std_logic;

    tm_done_rise_o : out std_logic;
    period_report_due_o : out std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_encode_critical_tmr is
  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal tm_done_rise_w : tmr_sl_t;
  signal period_report_due_w : tmr_sl_t;
  signal voter_a_w : std_logic_vector(1 downto 0);
  signal voter_b_w : std_logic_vector(1 downto 0);
  signal voter_c_w : std_logic_vector(1 downto 0);
  signal corrected_w : std_logic_vector(1 downto 0);
  signal error_bits_w : std_logic_vector(1 downto 0);

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
begin
  gen_critical : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_critical : label is "TRUE";
    attribute syn_preserve of u_critical : label is true;
    attribute KEEP_HIERARCHY of u_critical : label is "TRUE";
  begin
    u_critical: entity work.subordinate_uart_encode_critical
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        tm_done_i => tm_done_i,
        report_consume_i => report_consume_i,
        tm_done_rise_o => tm_done_rise_w(i),
        period_report_due_o => period_report_due_w(i)
      );
  end generate;

  voter_a_w <= period_report_due_w(0) & tm_done_rise_w(0);
  voter_b_w <= period_report_due_w(1) & tm_done_rise_w(1);
  voter_c_w <= period_report_due_w(2) & tm_done_rise_w(2);

  u_voter: entity work.tmr_voter_block
    generic map(
      p_WIDTH => 2
    )
    port map(
      A_i => voter_a_w,
      B_i => voter_b_w,
      C_i => voter_c_w,
      correct_enable_i => correct_enable_i,
      corrected_o => corrected_w,
      error_bits_o => error_bits_w,
      error_o => error_o
    );

  tm_done_rise_o <= corrected_w(0);
  period_report_due_o <= corrected_w(1);
end architecture;
