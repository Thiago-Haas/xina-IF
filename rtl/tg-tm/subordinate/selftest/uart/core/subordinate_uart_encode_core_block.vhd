library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_subordinate_ni_pkg.all;

entity subordinate_uart_encode_core_block is
  generic(
    G_REPORT_PERIOD_PACKETS : positive := c_SUB_TM_UART_REPORT_PERIOD_PACKETS;
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
begin
  u_encode_generic: entity work.uart_obs_encode_core_generic
    generic map(
      G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS,
      G_TM_COUNT_WIDTH => c_SUB_TM_TRANSACTION_COUNTER_WIDTH,
      G_FLAGS_WIDTH => c_SUB_TM_UART_FLAGS_WIDTH,
      G_PREFIX => "SUB TM=",
      G_MID => " FLAGS=",
      p_USE_CTRL_TMR => p_USE_UART_ENCODE_CRITICAL_TMR,
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
      tm_done_i => tm_done_i,
      tm_count_i => TM_TRANSACTION_COUNT_i,
      flags_i => flags_i,
      tm_count_correct_error_i => OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i,
      flags_seen_correct_error_i => OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i,
      event_flags_correct_error_i => OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i,
      report_flags_correct_error_i => OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i,
      uart_baud_div_o => uart_baud_div_o,
      uart_parity_o => uart_parity_o,
      uart_rtscts_o => uart_rtscts_o,
      uart_tready_i => uart_tready_i,
      uart_tdone_i => uart_tdone_i,
      uart_tstart_o => uart_tstart_o,
      uart_tdata_o => uart_tdata_o,
      tm_count_single_err_o => OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o,
      tm_count_double_err_o => OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o,
      flags_seen_single_err_o => OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o,
      flags_seen_double_err_o => OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o,
      event_flags_single_err_o => OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o,
      event_flags_double_err_o => OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o,
      report_flags_single_err_o => OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o,
      report_flags_double_err_o => OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o,
      ctrl_tmr_error_o => OBS_SUB_UART_ENCODE_CRITICAL_TMR_ERROR_o
    );
end architecture;
