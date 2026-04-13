library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_subordinate_ni_pkg.all;
use work.hamming_pkg.all;

-- Compact subordinate UART report datapath.
-- Line format: "SUB TM=<8 hex> FLAGS=<13 hex>\n"
entity subordinate_uart_encode_datapath is
  generic(
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
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    tm_done_rise_i : in std_logic;
    latch_event_flags_i : in std_logic;
    load_report_i : in std_logic;
    select_event_flags_i : in std_logic;
    tm_count_i : in std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    flags_i    : in std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);
    OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i : in std_logic := '1';
    OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i : in std_logic := '1';
    OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i : in std_logic := '1';
    OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i : in std_logic := '1';
    char_index_i : in unsigned(5 downto 0);
    new_event_o : out std_logic;
    OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o : out std_logic := '0';
    OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o : out std_logic := '0';
    tx_data_o  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of subordinate_uart_encode_datapath is
  function f_char(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;

  function f_hex(n : std_logic_vector(3 downto 0)) return std_logic_vector is
  begin
    case n is
      when x"0" => return x"30";
      when x"1" => return x"31";
      when x"2" => return x"32";
      when x"3" => return x"33";
      when x"4" => return x"34";
      when x"5" => return x"35";
      when x"6" => return x"36";
      when x"7" => return x"37";
      when x"8" => return x"38";
      when x"9" => return x"39";
      when x"A" => return x"41";
      when x"B" => return x"42";
      when x"C" => return x"43";
      when x"D" => return x"44";
      when x"E" => return x"45";
      when others => return x"46";
    end case;
  end function;

  function f_nibble(data : std_logic_vector; index_from_msb : natural) return std_logic_vector is
    variable lo_v : natural;
  begin
    lo_v := 4 * ((data'length / 4) - 1 - index_from_msb);
    return data(lo_v + 3 downto lo_v);
  end function;

  constant C_PREFIX : string := "SUB TM=";
  constant C_MID    : string := " FLAGS=";

  signal tm_count_r : std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
  signal event_flags_seen_r : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);
  signal event_flags_r : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);
  signal flags_r    : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);
  signal new_event_w : std_logic;
  signal tm_count_we_w : std_logic;
  signal tm_count_single_err_w : std_logic;
  signal tm_count_double_err_w : std_logic;
  signal tm_count_enc_w : std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH + get_ecc_size(c_SUB_TM_TRANSACTION_COUNTER_WIDTH, p_USE_UART_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal event_flags_seen_single_err_w : std_logic;
  signal event_flags_seen_double_err_w : std_logic;
  signal event_flags_seen_enc_w : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH + get_ecc_size(c_SUB_TM_UART_FLAGS_WIDTH, p_USE_UART_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal event_flags_single_err_w : std_logic;
  signal event_flags_double_err_w : std_logic;
  signal event_flags_enc_w : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH + get_ecc_size(c_SUB_TM_UART_FLAGS_WIDTH, p_USE_UART_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal report_flags_single_err_w : std_logic;
  signal report_flags_double_err_w : std_logic;
  signal report_flags_enc_w : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH + get_ecc_size(c_SUB_TM_UART_FLAGS_WIDTH, p_USE_UART_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal report_flags_data_w : std_logic_vector(c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0);

  function f_has_new_error_flags(
    current_flags  : std_logic_vector;
    previous_flags : std_logic_vector
  ) return std_logic is
  begin
    for i in current_flags'range loop
      if (current_flags(i) = '1') and (previous_flags(i) = '0') then
        return '1';
      end if;
    end loop;
    return '0';
  end function;

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of tm_count_r : signal is "TRUE";
  attribute DONT_TOUCH of event_flags_seen_r : signal is "TRUE";
  attribute DONT_TOUCH of event_flags_r : signal is "TRUE";
  attribute DONT_TOUCH of flags_r : signal is "TRUE";
  attribute syn_preserve of tm_count_r : signal is true;
  attribute syn_preserve of event_flags_seen_r : signal is true;
  attribute syn_preserve of event_flags_r : signal is true;
  attribute syn_preserve of flags_r : signal is true;
begin
  new_event_w <= f_has_new_error_flags(flags_i, event_flags_seen_r);
  new_event_o <= new_event_w;
  tm_count_we_w <= load_report_i;
  report_flags_data_w <= flags_i when select_event_flags_i = '0' else
                         flags_i when latch_event_flags_i = '1' else
                         event_flags_r;

  u_tm_count_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_SUB_TM_TRANSACTION_COUNTER_WIDTH,
      HAMMING_ENABLE => p_USE_UART_TM_COUNT_HAMMING,
      DETECT_DOUBLE  => p_USE_UART_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_UART_TM_COUNT_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_UART_HAM_TM_COUNT_CORRECT_ERROR_i,
      write_en_i   => tm_count_we_w,
      data_i       => tm_count_i,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => tm_count_single_err_w,
      double_err_o => tm_count_double_err_w,
      enc_data_o   => tm_count_enc_w,
      data_o       => tm_count_r
    );

  u_event_flags_seen_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_SUB_TM_UART_FLAGS_WIDTH,
      HAMMING_ENABLE => p_USE_UART_FLAGS_SEEN_HAMMING,
      DETECT_DOUBLE  => p_USE_UART_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_UART_HAM_FLAGS_SEEN_CORRECT_ERROR_i,
      write_en_i   => tm_done_rise_i,
      data_i       => flags_i,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => event_flags_seen_single_err_w,
      double_err_o => event_flags_seen_double_err_w,
      enc_data_o   => event_flags_seen_enc_w,
      data_o       => event_flags_seen_r
    );

  u_event_flags_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_SUB_TM_UART_FLAGS_WIDTH,
      HAMMING_ENABLE => p_USE_UART_EVENT_FLAGS_HAMMING,
      DETECT_DOUBLE  => p_USE_UART_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_UART_HAM_EVENT_FLAGS_CORRECT_ERROR_i,
      write_en_i   => latch_event_flags_i,
      data_i       => flags_i,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => event_flags_single_err_w,
      double_err_o => event_flags_double_err_w,
      enc_data_o   => event_flags_enc_w,
      data_o       => event_flags_r
    );

  u_report_flags_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_SUB_TM_UART_FLAGS_WIDTH,
      HAMMING_ENABLE => p_USE_UART_REPORT_FLAGS_HAMMING,
      DETECT_DOUBLE  => p_USE_UART_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_SUB_TM_UART_FLAGS_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_UART_HAM_REPORT_FLAGS_CORRECT_ERROR_i,
      write_en_i   => load_report_i,
      data_i       => report_flags_data_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => report_flags_single_err_w,
      double_err_o => report_flags_double_err_w,
      enc_data_o   => report_flags_enc_w,
      data_o       => flags_r
    );

  OBS_SUB_UART_HAM_TM_COUNT_SINGLE_ERR_o <= tm_count_single_err_w;
  OBS_SUB_UART_HAM_TM_COUNT_DOUBLE_ERR_o <= tm_count_double_err_w;
  OBS_SUB_UART_HAM_FLAGS_SEEN_SINGLE_ERR_o <= event_flags_seen_single_err_w;
  OBS_SUB_UART_HAM_FLAGS_SEEN_DOUBLE_ERR_o <= event_flags_seen_double_err_w;
  OBS_SUB_UART_HAM_EVENT_FLAGS_SINGLE_ERR_o <= event_flags_single_err_w;
  OBS_SUB_UART_HAM_EVENT_FLAGS_DOUBLE_ERR_o <= event_flags_double_err_w;
  OBS_SUB_UART_HAM_REPORT_FLAGS_SINGLE_ERR_o <= report_flags_single_err_w;
  OBS_SUB_UART_HAM_REPORT_FLAGS_DOUBLE_ERR_o <= report_flags_double_err_w;

  process(tm_count_r, flags_r, char_index_i)
    variable idx_v : natural;
  begin
    idx_v := to_integer(char_index_i);
    tx_data_o <= x"0A";

    if idx_v < C_PREFIX'length then
      tx_data_o <= f_char(C_PREFIX(idx_v + 1));
    elsif idx_v < C_PREFIX'length + 8 then
      tx_data_o <= f_hex(f_nibble(tm_count_r, idx_v - C_PREFIX'length));
    elsif idx_v < C_PREFIX'length + 8 + C_MID'length then
      tx_data_o <= f_char(C_MID(idx_v - C_PREFIX'length - 8 + 1));
    elsif idx_v < C_PREFIX'length + 8 + C_MID'length + (c_SUB_TM_UART_FLAGS_WIDTH / 4) then
      tx_data_o <= f_hex(f_nibble(flags_r, idx_v - C_PREFIX'length - 8 - C_MID'length));
    end if;
  end process;
end architecture;
