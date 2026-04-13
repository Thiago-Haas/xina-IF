library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_obs_encode_core_generic is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := 100;
    G_TM_COUNT_WIDTH : positive := 32;
    G_FLAGS_WIDTH : positive := 52;
    G_PREFIX : string := "SUB TM=";
    G_MID    : string := " FLAGS=";
    p_USE_CTRL_TMR : boolean := true;
    p_USE_UART_TM_COUNT_HAMMING : boolean := true;
    p_USE_UART_FLAGS_SEEN_HAMMING : boolean := true;
    p_USE_UART_EVENT_FLAGS_HAMMING : boolean := true;
    p_USE_UART_REPORT_FLAGS_HAMMING : boolean := true;
    p_USE_UART_HAMMING_DOUBLE_DETECT : boolean := true;
    p_USE_UART_TM_COUNT_HAMMING_INJECT_ERROR : boolean := false;
    p_USE_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR : boolean := false;
    p_USE_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR : boolean := false;
    p_USE_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR : boolean := false
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    tm_count_i : in std_logic_vector(G_TM_COUNT_WIDTH - 1 downto 0);
    flags_i : in std_logic_vector(G_FLAGS_WIDTH - 1 downto 0);
    tm_count_correct_error_i : in std_logic := '1';
    flags_seen_correct_error_i : in std_logic := '1';
    event_flags_correct_error_i : in std_logic := '1';
    report_flags_correct_error_i : in std_logic := '1';

    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;
    uart_tready_i   : in  std_logic;
    uart_tdone_i    : in  std_logic;
    uart_tstart_o   : out std_logic;
    uart_tdata_o    : out std_logic_vector(7 downto 0);

    tm_count_single_err_o : out std_logic;
    tm_count_double_err_o : out std_logic;
    flags_seen_single_err_o : out std_logic;
    flags_seen_double_err_o : out std_logic;
    event_flags_single_err_o : out std_logic;
    event_flags_double_err_o : out std_logic;
    report_flags_single_err_o : out std_logic;
    report_flags_double_err_o : out std_logic;
    ctrl_tmr_error_o : out std_logic
  );
end entity;

architecture rtl of uart_obs_encode_core_generic is
  function f_char_index_width(line_len : positive) return natural is
    variable width_v : natural := 1;
    variable limit_v : natural := 2;
  begin
    while limit_v < line_len loop
      width_v := width_v + 1;
      limit_v := limit_v * 2;
    end loop;
    return width_v;
  end function;

  constant C_TM_HEX_DIGITS : natural := G_TM_COUNT_WIDTH / 4;
  constant C_FLAGS_HEX_DIGITS : natural := G_FLAGS_WIDTH / 4;
  constant C_LINE_LEN : natural := G_PREFIX'length + C_TM_HEX_DIGITS + G_MID'length + C_FLAGS_HEX_DIGITS + 1;
  constant C_CHAR_INDEX_WIDTH : natural := f_char_index_width(C_LINE_LEN);

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
  signal char_index_w : unsigned(C_CHAR_INDEX_WIDTH - 1 downto 0);
  signal tm_done_rise_w : std_logic;
  signal period_report_consume_w : std_logic;
  signal new_event_w : std_logic;
  signal latch_event_flags_w : std_logic;
  signal load_report_w : std_logic;
  signal select_event_flags_w : std_logic;
begin
  uart_baud_div_o <= x"0001";
  uart_parity_o <= '0';
  uart_rtscts_o <= '0';

  gen_ctrl_plain : if not p_USE_CTRL_TMR generate
    attribute DONT_TOUCH of u_ctrl : label is "TRUE";
    attribute syn_preserve of u_ctrl : label is true;
    attribute KEEP_HIERARCHY of u_ctrl : label is "TRUE";
  begin
    u_ctrl: entity work.uart_obs_encode_ctrl_generic
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS,
        G_CHAR_INDEX_WIDTH => C_CHAR_INDEX_WIDTH,
        G_LINE_LEN => C_LINE_LEN
      )
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        tm_done_i => tm_done_i,
        new_event_i => new_event_w,
        uart_tready_i => uart_tready_i,
        uart_tdone_i => uart_tdone_i,
        period_report_consume_o => period_report_consume_w,
        latch_event_flags_o => latch_event_flags_w,
        load_report_o => load_report_w,
        select_event_flags_o => select_event_flags_w,
        tm_done_rise_o => tm_done_rise_w,
        char_index_o => char_index_w,
        uart_tstart_o => uart_tstart_o
      );
    ctrl_tmr_error_o <= '0';
  end generate;

  gen_ctrl_tmr : if p_USE_CTRL_TMR generate
  begin
    u_ctrl_tmr: entity work.uart_obs_encode_ctrl_generic_tmr
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS,
        G_CHAR_INDEX_WIDTH => C_CHAR_INDEX_WIDTH,
        G_LINE_LEN => C_LINE_LEN
      )
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        tm_done_i => tm_done_i,
        new_event_i => new_event_w,
        uart_tready_i => uart_tready_i,
        uart_tdone_i => uart_tdone_i,
        period_report_consume_o => period_report_consume_w,
        latch_event_flags_o => latch_event_flags_w,
        load_report_o => load_report_w,
        select_event_flags_o => select_event_flags_w,
        tm_done_rise_o => tm_done_rise_w,
        char_index_o => char_index_w,
        uart_tstart_o => uart_tstart_o,
        correct_enable_i => '1',
        error_o => ctrl_tmr_error_o
      );
  end generate;

  u_datapath: entity work.uart_obs_encode_datapath_generic
    generic map(
      G_TM_COUNT_WIDTH => G_TM_COUNT_WIDTH,
      G_FLAGS_WIDTH => G_FLAGS_WIDTH,
      G_PREFIX => G_PREFIX,
      G_MID => G_MID,
      p_USE_UART_TM_COUNT_HAMMING => p_USE_UART_TM_COUNT_HAMMING,
      p_USE_UART_FLAGS_SEEN_HAMMING => p_USE_UART_FLAGS_SEEN_HAMMING,
      p_USE_UART_EVENT_FLAGS_HAMMING => p_USE_UART_EVENT_FLAGS_HAMMING,
      p_USE_UART_REPORT_FLAGS_HAMMING => p_USE_UART_REPORT_FLAGS_HAMMING,
      p_USE_UART_HAMMING_DOUBLE_DETECT => p_USE_UART_HAMMING_DOUBLE_DETECT,
      p_USE_UART_TM_COUNT_HAMMING_INJECT_ERROR => p_USE_UART_TM_COUNT_HAMMING_INJECT_ERROR,
      p_USE_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR => p_USE_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR,
      p_USE_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR => p_USE_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR,
      p_USE_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR => p_USE_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      tm_done_rise_i => tm_done_rise_w,
      latch_event_flags_i => latch_event_flags_w,
      load_report_i => load_report_w,
      select_event_flags_i => select_event_flags_w,
      tm_count_i => tm_count_i,
      flags_i => flags_i,
      tm_count_correct_error_i => tm_count_correct_error_i,
      flags_seen_correct_error_i => flags_seen_correct_error_i,
      event_flags_correct_error_i => event_flags_correct_error_i,
      report_flags_correct_error_i => report_flags_correct_error_i,
      char_index_i => resize(char_index_w, 6),
      new_event_o => new_event_w,
      tm_count_single_err_o => tm_count_single_err_o,
      tm_count_double_err_o => tm_count_double_err_o,
      flags_seen_single_err_o => flags_seen_single_err_o,
      flags_seen_double_err_o => flags_seen_double_err_o,
      event_flags_single_err_o => event_flags_single_err_o,
      event_flags_double_err_o => event_flags_double_err_o,
      report_flags_single_err_o => report_flags_single_err_o,
      report_flags_double_err_o => report_flags_double_err_o,
      tx_data_o => uart_tdata_o
    );
end architecture;
