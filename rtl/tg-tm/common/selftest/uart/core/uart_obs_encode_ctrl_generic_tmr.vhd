library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- TMR wrapper for uart_obs_encode_ctrl_generic.
entity uart_obs_encode_ctrl_generic_tmr is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := 100;
    G_CHAR_INDEX_WIDTH      : positive := 6;
    G_LINE_LEN              : positive := 29
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    new_event_i : in std_logic;
    uart_tready_i : in std_logic;
    uart_tdone_i  : in std_logic;

    period_report_consume_o : out std_logic;
    latch_event_flags_o : out std_logic;
    load_report_o : out std_logic;
    select_event_flags_o : out std_logic;
    tm_done_rise_o : out std_logic;
    char_index_o : out unsigned(G_CHAR_INDEX_WIDTH - 1 downto 0);
    uart_tstart_o : out std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of uart_obs_encode_ctrl_generic_tmr is
  type t_u_array is array (2 downto 0) of unsigned(G_CHAR_INDEX_WIDTH - 1 downto 0);
  type t_sl_array is array (2 downto 0) of std_logic;

  signal period_report_consume_w : t_sl_array;
  signal latch_event_flags_w     : t_sl_array;
  signal load_report_w           : t_sl_array;
  signal select_event_flags_w    : t_sl_array;
  signal tm_done_rise_w          : t_sl_array;
  signal char_index_w            : t_u_array;
  signal uart_tstart_w           : t_sl_array;

  constant C_VOTER_WIDTH : natural := 5 + G_CHAR_INDEX_WIDTH + 1;
  signal voter_a_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_b_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_c_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal corrected_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal error_bits_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_ctrl : label is "TRUE";
    attribute syn_preserve of u_ctrl : label is true;
    attribute KEEP_HIERARCHY of u_ctrl : label is "TRUE";
  begin
    u_ctrl: entity work.uart_obs_encode_ctrl_generic
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS,
        G_CHAR_INDEX_WIDTH => G_CHAR_INDEX_WIDTH,
        G_LINE_LEN => G_LINE_LEN
      )
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        tm_done_i => tm_done_i,
        new_event_i => new_event_i,
        uart_tready_i => uart_tready_i,
        uart_tdone_i => uart_tdone_i,
        period_report_consume_o => period_report_consume_w(i),
        latch_event_flags_o => latch_event_flags_w(i),
        load_report_o => load_report_w(i),
        select_event_flags_o => select_event_flags_w(i),
        tm_done_rise_o => tm_done_rise_w(i),
        char_index_o => char_index_w(i),
        uart_tstart_o => uart_tstart_w(i)
      );
  end generate;

  voter_a_w <= period_report_consume_w(0) &
               latch_event_flags_w(0) &
               load_report_w(0) &
               select_event_flags_w(0) &
               tm_done_rise_w(0) &
               std_logic_vector(char_index_w(0)) &
               uart_tstart_w(0);
  voter_b_w <= period_report_consume_w(1) &
               latch_event_flags_w(1) &
               load_report_w(1) &
               select_event_flags_w(1) &
               tm_done_rise_w(1) &
               std_logic_vector(char_index_w(1)) &
               uart_tstart_w(1);
  voter_c_w <= period_report_consume_w(2) &
               latch_event_flags_w(2) &
               load_report_w(2) &
               select_event_flags_w(2) &
               tm_done_rise_w(2) &
               std_logic_vector(char_index_w(2)) &
               uart_tstart_w(2);

  u_voter: entity work.tmr_voter_block
    generic map(
      p_WIDTH => C_VOTER_WIDTH
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

  period_report_consume_o <= corrected_w(C_VOTER_WIDTH - 1);
  latch_event_flags_o <= corrected_w(C_VOTER_WIDTH - 2);
  load_report_o <= corrected_w(C_VOTER_WIDTH - 3);
  select_event_flags_o <= corrected_w(C_VOTER_WIDTH - 4);
  tm_done_rise_o <= corrected_w(C_VOTER_WIDTH - 5);
  char_index_o <= unsigned(corrected_w(C_VOTER_WIDTH - 6 downto 1));
  uart_tstart_o <= corrected_w(0);
end architecture;
