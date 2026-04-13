library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_subordinate_ni_pkg.all;

entity subordinate_uart_encode_core_block is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := 100;
    p_USE_UART_ENCODE_CRITICAL_TMR : boolean := c_ENABLE_SUB_OBS_UART_ENCODE_CRITICAL_TMR;
    p_USE_UART_TM_COUNT_HAMMING : boolean := c_ENABLE_SUB_OBS_UART_TM_COUNT_HAMMING;
    p_USE_UART_FLAGS_SEEN_HAMMING : boolean := c_ENABLE_SUB_OBS_UART_FLAGS_SEEN_HAMMING;
    p_USE_UART_EVENT_FLAGS_HAMMING : boolean := c_ENABLE_SUB_OBS_UART_EVENT_FLAGS_HAMMING;
    p_USE_UART_REPORT_FLAGS_HAMMING : boolean := c_ENABLE_SUB_OBS_UART_REPORT_FLAGS_HAMMING;
    p_USE_UART_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_SUB_OBS_UART_HAMMING_DOUBLE_DETECT;
    p_USE_UART_TM_COUNT_HAMMING_INJECT_ERROR : boolean := c_ENABLE_SUB_OBS_UART_TM_COUNT_HAMMING_INJECT_ERROR;
    p_USE_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR : boolean := c_ENABLE_SUB_OBS_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR;
    p_USE_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR : boolean := c_ENABLE_SUB_OBS_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR;
    p_USE_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR : boolean := c_ENABLE_SUB_OBS_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    TM_TRANSACTION_COUNT_i : in std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    flags_i : in std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);
    OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i : in std_logic := '1';
    OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i : in std_logic := '1';
    OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i : in std_logic := '1';
    OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i : in std_logic := '1';

    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;
    uart_tready_i   : in  std_logic;
    uart_tdone_i    : in  std_logic;
    uart_tstart_o   : out std_logic;
    uart_tdata_o    : out std_logic_vector(7 downto 0);
    OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o : out std_logic;
    OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o : out std_logic;
    OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_encode_core_block is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
  signal char_index_w : unsigned(5 downto 0);
  signal tm_done_rise_w : std_logic;
  signal period_report_due_w : std_logic;
  signal period_report_consume_w : std_logic;
  signal new_event_w : std_logic;
  signal latch_event_flags_w : std_logic;
  signal load_report_w : std_logic;
  signal select_event_flags_w : std_logic;
begin
  uart_baud_div_o <= x"0001";
  uart_parity_o <= '0';
  uart_rtscts_o <= '0';

  gen_critical_plain : if not p_USE_UART_ENCODE_CRITICAL_TMR generate
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
        report_consume_i => period_report_consume_w,
        tm_done_rise_o => tm_done_rise_w,
        period_report_due_o => period_report_due_w
      );
    OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o <= '0';
  end generate;

  gen_critical_tmr : if p_USE_UART_ENCODE_CRITICAL_TMR generate
  begin
    u_critical_tmr: entity work.subordinate_uart_encode_critical_tmr
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        tm_done_i => tm_done_i,
        report_consume_i => period_report_consume_w,
        tm_done_rise_o => tm_done_rise_w,
        period_report_due_o => period_report_due_w,
        correct_enable_i => '1',
        error_o => OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o
      );
  end generate;

  u_control: entity work.subordinate_uart_encode_ctrl
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      tm_done_rise_i => tm_done_rise_w,
      period_report_due_i => period_report_due_w,
      new_event_i => new_event_w,
      uart_tready_i => uart_tready_i,
      uart_tdone_i => uart_tdone_i,
      period_report_consume_o => period_report_consume_w,
      latch_event_flags_o => latch_event_flags_w,
      load_report_o => load_report_w,
      select_event_flags_o => select_event_flags_w,
      char_index_o => char_index_w,
      uart_tstart_o => uart_tstart_o
    );

  u_datapath: entity work.subordinate_uart_encode_datapath
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      tm_done_rise_i => tm_done_rise_w,
      latch_event_flags_i => latch_event_flags_w,
      load_report_i => load_report_w,
      select_event_flags_i => select_event_flags_w,
      tm_count_i => TM_TRANSACTION_COUNT_i,
      flags_i => flags_i,
      OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i => OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i,
      OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i => OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i,
      OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i => OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i,
      OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i => OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i,
      char_index_i => char_index_w,
      new_event_o => new_event_w,
      OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o => OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o => OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o => OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o => OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o,
      OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o => OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o,
      tx_data_o => uart_tdata_o
    );
end architecture;
