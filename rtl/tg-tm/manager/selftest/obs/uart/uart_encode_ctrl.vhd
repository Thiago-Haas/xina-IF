library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- UART manager for closed-box self-test:
-- * encodes fault/status vector as labeled ASCII text + LF
-- * decodes UART RX commands to control experiment and OBS enables
entity selftest_obs_uart_encode_ctrl is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;

    -- Observability inputs used for UART report
    tm_comparison_mismatch_i : in  std_logic;
    TM_TRANSACTION_COUNT_i   : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    TM_EXPECTED_VALUE_i      : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    NI_CORRUPT_PACKET_i      : in std_logic;

    OBS_TM_TMR_CTRL_ERROR_i : in std_logic;
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_LB_TMR_CTRL_ERROR_i : in std_logic;
    OBS_LB_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_LB_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_LB_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, c_ENABLE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_TG_TMR_CTRL_ERROR_i : in std_logic;
    OBS_TG_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_TG_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_TG_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_FE_INJ_META_HDR_SINGLE_ERR_i : in std_logic;
    OBS_FE_INJ_META_HDR_DOUBLE_ERR_i : in std_logic;
    OBS_FE_INJ_ADDR_SINGLE_ERR_i : in std_logic;
    OBS_FE_INJ_ADDR_DOUBLE_ERR_i : in std_logic;
    OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i : in std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_FE_INJ_HAM_ADDR_ENC_DATA_i : in std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i : in std_logic;

    OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_INTEGRITY_CORRUPT_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_START_DONE_CTRL_TMR_ERROR_i : in std_logic;

    -- UART config
    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;

    -- UART TX interface
    uart_tready_i : in  std_logic;
    uart_tdone_i  : in  std_logic;
    uart_tstart_o : out std_logic;
    uart_tdata_o  : out std_logic_vector(7 downto 0);

    -- Datapath interface
    dp_hex_char_i   : in  std_logic_vector(7 downto 0);
    dp_label_char_i : in  std_logic_vector(7 downto 0);
    dp_load_base_o  : out std_logic;
    dp_load_enc_o   : out std_logic;
    dp_event_report_o : out std_logic;
    dp_event_enc_valid_o : out std_logic;
    dp_pending_enc_line_i : in std_logic;
    dp_report_has_flags_i : in std_logic;
    dp_tm_count_o   : out std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    dp_flags_o      : out std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
    dp_enc_src_o    : out std_logic_vector(3 downto 0);
    dp_enc_data_o   : out std_logic_vector(79 downto 0);
    dp_nibble_index_o : out unsigned(4 downto 0);
    dp_label_sel_o  : out std_logic_vector(2 downto 0);
    dp_label_index_o : out natural range 1 to 8
  );
end entity;

architecture rtl of selftest_obs_uart_encode_ctrl is
  constant C_FLAGS_WIDTH             : natural := c_TM_UART_FLAGS_WIDTH;
  constant C_BASE_TM_LSB             : natural := C_FLAGS_WIDTH;
  constant C_BASE_TM_MSB             : natural := C_BASE_TM_LSB + c_TM_TRANSACTION_COUNTER_WIDTH - 1;
  constant C_BASE_TM_NIBBLE_START    : natural := C_BASE_TM_MSB / 4;
  constant C_BASE_TM_NIBBLE_STOP     : natural := C_BASE_TM_LSB / 4;
  constant C_BASE_FLAGS_NIBBLE_START : natural := (C_FLAGS_WIDTH / 4) - 1;
  constant C_BASE_FLAGS_NIBBLE_STOP  : natural := 0;
  constant C_ENC_SRC_NIBBLE_START    : natural := 20;
  constant C_ENC_SRC_NIBBLE_STOP     : natural := 20;
  constant C_ENC_DATA_NIBBLE_START   : natural := 19;
  constant C_ENC_DATA_NIBBLE_STOP    : natural := 0;

  constant C_LABEL_TM    : string := "TM=";
  constant C_LABEL_FLAGS : string := " FLAGS=";
  constant C_LABEL_ENC   : string := "ENC SRC=";
  constant C_LABEL_DATA  : string := " DATA=";

  constant S_IDLE       : std_logic_vector(2 downto 0) := "000";
  constant S_SEND_LABEL : std_logic_vector(2 downto 0) := "001";
  constant S_SEND_HEX   : std_logic_vector(2 downto 0) := "010";
  constant S_SEND_LF    : std_logic_vector(2 downto 0) := "011";
  constant S_WAIT_DONE  : std_logic_vector(2 downto 0) := "100";

  constant PH_BASE_TM_LABEL    : std_logic_vector(2 downto 0) := "000";
  constant PH_BASE_TM_HEX      : std_logic_vector(2 downto 0) := "001";
  constant PH_BASE_FLAGS_LABEL : std_logic_vector(2 downto 0) := "010";
  constant PH_BASE_FLAGS_HEX   : std_logic_vector(2 downto 0) := "011";
  constant PH_ENC_LABEL        : std_logic_vector(2 downto 0) := "100";
  constant PH_ENC_SRC_HEX      : std_logic_vector(2 downto 0) := "101";
  constant PH_ENC_DATA_LABEL   : std_logic_vector(2 downto 0) := "110";
  constant PH_ENC_DATA_HEX     : std_logic_vector(2 downto 0) := "111";

  constant WS_LABEL : std_logic_vector(1 downto 0) := "00";
  constant WS_HEX   : std_logic_vector(1 downto 0) := "01";
  constant WS_LF    : std_logic_vector(1 downto 0) := "10";

  signal tx_state_r      : std_logic_vector(2 downto 0) := S_IDLE;
  signal tx_phase_r      : std_logic_vector(2 downto 0) := PH_BASE_TM_LABEL;
  signal wait_source_r   : std_logic_vector(1 downto 0) := WS_LABEL;

  signal nibble_index_r    : unsigned(4 downto 0) := to_unsigned(C_BASE_TM_NIBBLE_START, 5);
  signal nibble_stop_r     : unsigned(4 downto 0) := to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
  signal label_index_r     : natural range 1 to 8 := 1;

  signal dp_label_sel_w    : std_logic_vector(2 downto 0);
  signal uart_tstart_r     : std_logic := '0';
  signal uart_tdata_r      : std_logic_vector(7 downto 0) := (others => '0');

  signal tm_done_d_r       : std_logic := '0';
  signal tm_done_rise_w    : std_logic;
  signal any_error_w       : std_logic;
  signal dp_load_base_r    : std_logic := '0';
  signal dp_load_enc_r     : std_logic := '0';
  signal dp_event_report_r : std_logic := '0';
  signal report_counter_r   : integer range 0 to G_REPORT_PERIOD_PACKETS - 1 := 0;
  signal period_report_due_r : std_logic := '0';
  signal event_flags_w      : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
  signal event_enc_valid_w  : std_logic;
  signal event_enc_src_w    : std_logic_vector(3 downto 0);
  signal event_enc_data_w   : std_logic_vector(79 downto 0);

  function f_pack80(src : std_logic_vector) return std_logic_vector is
    variable v : std_logic_vector(79 downto 0) := (others => '0');
    variable n : natural;

  begin
    if src'length >= 80 then
      v := src(79 downto 0);
    else
      n := src'length;
      v(n - 1 downto 0) := src;
    end if;
    return v;
  end function;

  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of dp_load_base_r : signal is "TRUE";
  attribute DONT_TOUCH of dp_load_enc_r : signal is "TRUE";
  attribute DONT_TOUCH of dp_event_report_r : signal is "TRUE";
  attribute DONT_TOUCH of label_index_r : signal is "TRUE";
  attribute DONT_TOUCH of nibble_index_r : signal is "TRUE";
  attribute DONT_TOUCH of nibble_stop_r : signal is "TRUE";
  attribute DONT_TOUCH of period_report_due_r : signal is "TRUE";
  attribute DONT_TOUCH of report_counter_r : signal is "TRUE";
  attribute DONT_TOUCH of tm_done_d_r : signal is "TRUE";
  attribute DONT_TOUCH of tx_phase_r : signal is "TRUE";
  attribute DONT_TOUCH of tx_state_r : signal is "TRUE";
  attribute DONT_TOUCH of uart_tdata_r : signal is "TRUE";
  attribute DONT_TOUCH of uart_tstart_r : signal is "TRUE";
  attribute DONT_TOUCH of wait_source_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of dp_load_base_r : signal is true;
  attribute syn_preserve of dp_load_enc_r : signal is true;
  attribute syn_preserve of dp_event_report_r : signal is true;
  attribute syn_preserve of label_index_r : signal is true;
  attribute syn_preserve of nibble_index_r : signal is true;
  attribute syn_preserve of nibble_stop_r : signal is true;
  attribute syn_preserve of period_report_due_r : signal is true;
  attribute syn_preserve of report_counter_r : signal is true;
  attribute syn_preserve of tm_done_d_r : signal is true;
  attribute syn_preserve of tx_phase_r : signal is true;
  attribute syn_preserve of tx_state_r : signal is true;
  attribute syn_preserve of uart_tdata_r : signal is true;
  attribute syn_preserve of uart_tstart_r : signal is true;
  attribute syn_preserve of wait_source_r : signal is true;
begin
  -- static UART configuration
  uart_baud_div_o <= x"0001";
  uart_parity_o   <= '0';
  uart_rtscts_o   <= '0';

  uart_tstart_o <= uart_tstart_r;
  uart_tdata_o  <= uart_tdata_r;
  dp_load_base_o    <= dp_load_base_r;
  dp_load_enc_o     <= dp_load_enc_r;
  dp_event_report_o <= dp_event_report_r;
  dp_event_enc_valid_o <= event_enc_valid_w;
  dp_tm_count_o     <= TM_TRANSACTION_COUNT_i;
  dp_flags_o        <= event_flags_w;
  dp_enc_src_o      <= event_enc_src_w;
  dp_enc_data_o     <= event_enc_data_w;
  dp_nibble_index_o <= nibble_index_r;
  dp_label_sel_o    <= dp_label_sel_w;
  dp_label_index_o  <= label_index_r;

  tm_done_rise_w <= tm_done_i and (not tm_done_d_r);
  any_error_w <=
    tm_comparison_mismatch_i or NI_CORRUPT_PACKET_i or
    OBS_TM_TMR_CTRL_ERROR_i or
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i or OBS_TM_HAM_BUFFER_DOUBLE_ERR_i or
    OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i or OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i or
    OBS_LB_TMR_CTRL_ERROR_i or OBS_LB_HAM_BUFFER_SINGLE_ERR_i or OBS_LB_HAM_BUFFER_DOUBLE_ERR_i or
    OBS_TG_TMR_CTRL_ERROR_i or OBS_TG_HAM_BUFFER_SINGLE_ERR_i or OBS_TG_HAM_BUFFER_DOUBLE_ERR_i or
    OBS_FE_INJ_META_HDR_SINGLE_ERR_i or OBS_FE_INJ_META_HDR_DOUBLE_ERR_i or
    OBS_FE_INJ_ADDR_SINGLE_ERR_i or OBS_FE_INJ_ADDR_DOUBLE_ERR_i or
    OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i or OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i or
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i or
    OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i or OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i or
    OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i or OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i or
    OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i or OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i or
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i or OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i or
    OBS_BE_RX_INTEGRITY_CORRUPT_i or
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i or OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i or
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i or
    OBS_START_DONE_CTRL_TMR_ERROR_i;

  event_flags_w <=
    (31 downto 29 => '0') &
    OBS_START_DONE_CTRL_TMR_ERROR_i &
    tm_comparison_mismatch_i &
    NI_CORRUPT_PACKET_i &
    OBS_TM_TMR_CTRL_ERROR_i &
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i &
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_i &
    OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i &
    OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i &
    OBS_LB_TMR_CTRL_ERROR_i &
    OBS_LB_HAM_BUFFER_SINGLE_ERR_i &
    OBS_LB_HAM_BUFFER_DOUBLE_ERR_i &
    OBS_TG_TMR_CTRL_ERROR_i &
    OBS_TG_HAM_BUFFER_SINGLE_ERR_i &
    OBS_TG_HAM_BUFFER_DOUBLE_ERR_i &
    OBS_FE_INJ_META_HDR_SINGLE_ERR_i &
    OBS_FE_INJ_META_HDR_DOUBLE_ERR_i &
    OBS_FE_INJ_ADDR_SINGLE_ERR_i &
    OBS_FE_INJ_ADDR_DOUBLE_ERR_i &
    OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i &
    OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i &
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i &
    OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i &
    OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i &
    OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i &
    OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i &
    OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i &
    OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i &
    OBS_BE_RX_INTEGRITY_CORRUPT_i &
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i;

  process(
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i, OBS_TM_HAM_BUFFER_DOUBLE_ERR_i, OBS_TM_HAM_BUFFER_ENC_DATA_i,
    OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i, OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i, OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i,
    OBS_LB_HAM_BUFFER_SINGLE_ERR_i, OBS_LB_HAM_BUFFER_DOUBLE_ERR_i, OBS_LB_HAM_BUFFER_ENC_DATA_i,
    OBS_TG_HAM_BUFFER_SINGLE_ERR_i, OBS_TG_HAM_BUFFER_DOUBLE_ERR_i, OBS_TG_HAM_BUFFER_ENC_DATA_i,
    OBS_FE_INJ_META_HDR_SINGLE_ERR_i, OBS_FE_INJ_META_HDR_DOUBLE_ERR_i, OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i,
    OBS_FE_INJ_ADDR_SINGLE_ERR_i, OBS_FE_INJ_ADDR_DOUBLE_ERR_i, OBS_FE_INJ_HAM_ADDR_ENC_DATA_i,
    OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i, OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i, OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i,
    OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i, OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i, OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i,
    OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i, OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i, OBS_BE_RX_HAM_BUFFER_ENC_DATA_i,
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i, OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i, OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i,
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i, OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i, OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i
  )
  begin
    event_enc_valid_w <= '0';
    event_enc_src_w   <= (others => '0');
    event_enc_data_w  <= (others => '0');

    if (OBS_TM_HAM_BUFFER_SINGLE_ERR_i = '1') or (OBS_TM_HAM_BUFFER_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"1";
      event_enc_data_w  <= f_pack80(OBS_TM_HAM_BUFFER_ENC_DATA_i);
    elsif (OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i = '1') or (OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"2";
      event_enc_data_w  <= f_pack80(OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i);
    elsif (OBS_LB_HAM_BUFFER_SINGLE_ERR_i = '1') or (OBS_LB_HAM_BUFFER_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"3";
      event_enc_data_w  <= f_pack80(OBS_LB_HAM_BUFFER_ENC_DATA_i);
    elsif (OBS_TG_HAM_BUFFER_SINGLE_ERR_i = '1') or (OBS_TG_HAM_BUFFER_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"4";
      event_enc_data_w  <= f_pack80(OBS_TG_HAM_BUFFER_ENC_DATA_i);
    elsif (OBS_FE_INJ_META_HDR_SINGLE_ERR_i = '1') or (OBS_FE_INJ_META_HDR_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"5";
      event_enc_data_w  <= f_pack80(OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i);
    elsif (OBS_FE_INJ_ADDR_SINGLE_ERR_i = '1') or (OBS_FE_INJ_ADDR_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"6";
      event_enc_data_w  <= f_pack80(OBS_FE_INJ_HAM_ADDR_ENC_DATA_i);
    elsif (OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i = '1') or (OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"7";
      event_enc_data_w  <= f_pack80(OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i);
    elsif (OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i = '1') or (OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"8";
      event_enc_data_w  <= f_pack80(OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i);
    elsif (OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i = '1') or (OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"9";
      event_enc_data_w  <= f_pack80(OBS_BE_RX_HAM_BUFFER_ENC_DATA_i);
    elsif (OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i = '1') or (OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"A";
      event_enc_data_w  <= f_pack80(OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i);
    elsif (OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i = '1') or (OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i = '1') then
      event_enc_valid_w <= '1';
      event_enc_src_w   <= x"B";
      event_enc_data_w  <= f_pack80(OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i);
    end if;
  end process;

  -- Datapath/control split:
  -- * this module keeps controller FSM
  -- * datapath module generates label and hex bytes
  with tx_phase_r select
    dp_label_sel_w <=
      "001" when PH_BASE_TM_LABEL,
      "010" when PH_BASE_FLAGS_LABEL,
      "011" when PH_ENC_LABEL,
      "100" when PH_ENC_DATA_LABEL,
      "111" when others;

  process(ACLK)
    variable v_do_report : boolean;
    variable v_is_event  : boolean;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        tx_state_r     <= S_IDLE;
        tx_phase_r     <= PH_BASE_TM_LABEL;
        wait_source_r  <= WS_LABEL;
        dp_load_base_r <= '0';
        dp_load_enc_r  <= '0';
        dp_event_report_r <= '0';
        nibble_index_r <= to_unsigned(C_BASE_TM_NIBBLE_START, 5);
        nibble_stop_r  <= to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
        label_index_r  <= 1;
        uart_tstart_r  <= '0';
        uart_tdata_r   <= (others => '0');
        tm_done_d_r    <= '0';
        report_counter_r   <= 0;
        period_report_due_r <= '0';
      else
        tm_done_d_r    <= tm_done_i;
        uart_tstart_r  <= '0';
        dp_load_base_r <= '0';
        dp_load_enc_r  <= '0';
        dp_event_report_r <= '0';

        if tm_done_rise_w = '1' then
          if report_counter_r = G_REPORT_PERIOD_PACKETS - 1 then
            report_counter_r    <= 0;
            period_report_due_r <= '1';
          else
            report_counter_r <= report_counter_r + 1;
          end if;
        end if;

        case tx_state_r is
          when S_IDLE =>
            v_is_event  := ((tm_done_rise_w = '1') and (any_error_w = '1'));
            v_do_report := (period_report_due_r = '1') or v_is_event;
            if v_do_report then
              period_report_due_r <= '0';
              if v_is_event then
                dp_event_report_r <= '1';
              else
                dp_event_report_r <= '0';
              end if;
              dp_load_base_r <= '1';

              tx_phase_r    <= PH_BASE_TM_LABEL;
              label_index_r <= 1;
              tx_state_r    <= S_SEND_LABEL;
            end if;

          when S_SEND_LABEL =>
            if uart_tready_i = '1' then
              case tx_phase_r is
                when PH_BASE_TM_LABEL =>
                  uart_tdata_r <= dp_label_char_i;
                when PH_BASE_FLAGS_LABEL =>
                  uart_tdata_r <= dp_label_char_i;
                when PH_ENC_LABEL =>
                  uart_tdata_r <= dp_label_char_i;
                when PH_ENC_DATA_LABEL =>
                  uart_tdata_r <= dp_label_char_i;
                when others =>
                  uart_tdata_r <= x"3F"; -- '?'
              end case;
              uart_tstart_r <= '1';
              wait_source_r <= WS_LABEL;
              tx_state_r    <= S_WAIT_DONE;
            end if;

          when S_SEND_HEX =>
            if uart_tready_i = '1' then
              uart_tdata_r  <= dp_hex_char_i;
              uart_tstart_r <= '1';
              wait_source_r <= WS_HEX;
              tx_state_r    <= S_WAIT_DONE;
            end if;

          when S_SEND_LF =>
            if uart_tready_i = '1' then
              uart_tdata_r  <= x"0A";
              uart_tstart_r <= '1';
              wait_source_r <= WS_LF;
              tx_state_r    <= S_WAIT_DONE;
            end if;

          when S_WAIT_DONE =>
            if uart_tdone_i = '1' then
              case wait_source_r is
                when WS_LABEL =>
                  case tx_phase_r is
                    when PH_BASE_TM_LABEL =>
                      if label_index_r < C_LABEL_TM'length then
                        label_index_r <= label_index_r + 1;
                        tx_state_r    <= S_SEND_LABEL;
                      else
                        tx_phase_r    <= PH_BASE_TM_HEX;
                        nibble_index_r <= to_unsigned(C_BASE_TM_NIBBLE_START, 5);
                        nibble_stop_r  <= to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
                        tx_state_r    <= S_SEND_HEX;
                      end if;
                    when PH_BASE_FLAGS_LABEL =>
                      if label_index_r < C_LABEL_FLAGS'length then
                        label_index_r <= label_index_r + 1;
                        tx_state_r    <= S_SEND_LABEL;
                      else
                        tx_phase_r     <= PH_BASE_FLAGS_HEX;
                        nibble_index_r <= to_unsigned(C_BASE_FLAGS_NIBBLE_START, 5);
                        nibble_stop_r  <= to_unsigned(C_BASE_FLAGS_NIBBLE_STOP, 5);
                        tx_state_r     <= S_SEND_HEX;
                      end if;
                    when PH_ENC_LABEL =>
                      if label_index_r < C_LABEL_ENC'length then
                        label_index_r <= label_index_r + 1;
                        tx_state_r    <= S_SEND_LABEL;
                      else
                        tx_phase_r     <= PH_ENC_SRC_HEX;
                        nibble_index_r <= to_unsigned(C_ENC_SRC_NIBBLE_START, 5);
                        nibble_stop_r  <= to_unsigned(C_ENC_SRC_NIBBLE_STOP, 5);
                        tx_state_r     <= S_SEND_HEX;
                      end if;
                    when PH_ENC_DATA_LABEL =>
                      if label_index_r < C_LABEL_DATA'length then
                        label_index_r <= label_index_r + 1;
                        tx_state_r    <= S_SEND_LABEL;
                      else
                        tx_phase_r     <= PH_ENC_DATA_HEX;
                        nibble_index_r <= to_unsigned(C_ENC_DATA_NIBBLE_START, 5);
                        nibble_stop_r  <= to_unsigned(C_ENC_DATA_NIBBLE_STOP, 5);
                        tx_state_r     <= S_SEND_HEX;
                      end if;
                    when others =>
                      tx_state_r <= S_IDLE;
                  end case;

                when WS_HEX =>
                  if nibble_index_r /= nibble_stop_r then
                    nibble_index_r <= nibble_index_r - 1;
                    tx_state_r     <= S_SEND_HEX;
                  else
                    case tx_phase_r is
                      when PH_BASE_TM_HEX =>
                        if dp_report_has_flags_i = '1' then
                          tx_phase_r    <= PH_BASE_FLAGS_LABEL;
                          label_index_r <= 1;
                          tx_state_r    <= S_SEND_LABEL;
                        else
                          tx_state_r <= S_SEND_LF;
                        end if;
                      when PH_BASE_FLAGS_HEX =>
                        tx_state_r <= S_SEND_LF;
                      when PH_ENC_SRC_HEX =>
                        tx_phase_r    <= PH_ENC_DATA_LABEL;
                        label_index_r <= 1;
                        tx_state_r    <= S_SEND_LABEL;
                      when PH_ENC_DATA_HEX =>
                        tx_state_r <= S_SEND_LF;
                      when others =>
                        tx_state_r <= S_IDLE;
                    end case;
                  end if;

                when WS_LF =>
                  if tx_phase_r = PH_BASE_FLAGS_HEX then
                    if dp_pending_enc_line_i = '1' then
                      dp_load_enc_r      <= '1';
                      tx_phase_r         <= PH_ENC_LABEL;
                      label_index_r      <= 1;
                      tx_state_r         <= S_SEND_LABEL;
                    else
                      tx_state_r <= S_IDLE;
                    end if;
                  else
                    tx_state_r <= S_IDLE;
                  end if;
                when others =>
                  tx_state_r <= S_IDLE;
              end case;
            end if;
          when others =>
            tx_state_r <= S_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
