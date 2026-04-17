library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

entity manager_uart_encode_ctrl is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_i : in std_logic;
    tm_done_rise_i : in std_logic;
    period_report_due_i : in std_logic;
    period_report_consume_o : out std_logic;

    tm_comparison_mismatch_i : in  std_logic;
    TM_RECEIVED_COUNT_i      : in std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0);
    TM_CORRECT_COUNT_i       : in std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0);
    TM_EXPECTED_VALUE_i      : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    NI_CORRUPT_PACKET_i      : in std_logic;

    OBS_TM_TMR_CTRL_ERROR_i : in std_logic;
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_BUFFER_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_RECEIVED_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_RECEIVED_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_RECEIVED_COUNTER_ENC_DATA_i : in std_logic_vector(c_TM_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_i : in std_logic;
    OBS_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_i : in std_logic;
    OBS_TM_HAM_CORRECT_COUNTER_ENC_DATA_i : in std_logic_vector(c_TM_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

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
    OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_i : in std_logic;
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_INTEGRITY_CORRUPT_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i : in std_logic;
    OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i : in std_logic;
    OBS_START_DONE_CTRL_TMR_ERROR_i : in std_logic;
    OBS_UART_COMMAND_CTRL_TMR_ERROR_i : in std_logic;
    OBS_UART_ENCODE_CRITICAL_TMR_ERROR_i : in std_logic;

    uart_baud_div_o : out std_logic_vector(15 downto 0);
    uart_parity_o   : out std_logic;
    uart_rtscts_o   : out std_logic;
    uart_tready_i : in  std_logic;
    uart_tdone_i  : in  std_logic;
    uart_tstart_o : out std_logic;
    uart_tdata_o  : out std_logic_vector(7 downto 0);

    dp_hex_char_i   : in  std_logic_vector(7 downto 0);
    dp_label_char_i : in  std_logic_vector(7 downto 0);
    dp_load_base_o  : out std_logic;
    dp_load_enc_o   : out std_logic;
    dp_event_report_o : out std_logic;
    dp_event_enc_valid_o : out std_logic;
    dp_pending_enc_line_i : in std_logic;
    dp_report_has_flags_i : in std_logic;
    dp_rx_count_o   : out std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0);
    dp_ok_count_o   : out std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0);
    dp_flags_o      : out std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
    dp_enc_src_o    : out std_logic_vector(3 downto 0);
    dp_enc_data_o   : out std_logic_vector(79 downto 0);
    dp_nibble_index_o : out unsigned(4 downto 0);
    dp_label_sel_o  : out std_logic_vector(2 downto 0);
    dp_label_index_o : out natural range 1 to 8
  );
end entity;

architecture rtl of manager_uart_encode_ctrl is
  constant C_MANAGER_FLAGS_RESERVED_PAD : std_logic_vector(4 downto 0) := "00000";

  constant C_LABEL_RX    : string := "RX=";
  constant C_LABEL_OK    : string := " OK=";
  constant C_LABEL_FLAGS : string := " FLAGS=";

  constant PH_RX_LABEL    : std_logic_vector(2 downto 0) := "000";
  constant PH_RX_HEX      : std_logic_vector(2 downto 0) := "001";
  constant PH_OK_LABEL    : std_logic_vector(2 downto 0) := "010";
  constant PH_OK_HEX      : std_logic_vector(2 downto 0) := "011";
  constant PH_FLAGS_LABEL : std_logic_vector(2 downto 0) := "100";
  constant PH_FLAGS_HEX   : std_logic_vector(2 downto 0) := "101";
  constant PH_LF          : std_logic_vector(2 downto 0) := "110";

  constant ST_IDLE      : std_logic_vector(1 downto 0) := "00";
  constant ST_SEND      : std_logic_vector(1 downto 0) := "01";
  constant ST_WAIT_DONE : std_logic_vector(1 downto 0) := "10";

  signal state_r : std_logic_vector(1 downto 0) := ST_IDLE;
  signal phase_r : std_logic_vector(2 downto 0) := PH_RX_LABEL;
  signal label_index_r : natural range 1 to 8 := 1;
  signal nibble_index_r : unsigned(4 downto 0) := (others => '0');
  signal tx_start_r : std_logic := '0';
  signal tx_data_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal load_base_r : std_logic := '0';
  signal event_report_r : std_logic := '0';
  signal event_pending_r : std_logic := '0';
  signal flags_seen_r : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0) := (others => '0');
  signal flags_latched_r : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0) := (others => '0');
  signal event_flags_w : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);

  function f_has_new_error_flags(
    current_flags  : std_logic_vector;
    previous_flags : std_logic_vector
  ) return boolean is
  begin
    for i in current_flags'range loop
      if (current_flags(i) = '1') and (previous_flags(i) = '0') then
        return true;
      end if;
    end loop;
    return false;
  end function;

  function f_hex_digits(width : natural) return natural is
  begin
    return (width + 3) / 4;
  end function;

  procedure p_set_hex_window(
    signal nibble_index_o : out unsigned(4 downto 0);
    constant count_width : in natural
  ) is
    variable digits_v : natural;
  begin
    digits_v := f_hex_digits(count_width);
    nibble_index_o <= to_unsigned(digits_v - 1, nibble_index_o'length);
  end procedure;
begin
  uart_baud_div_o <= x"0001";
  uart_parity_o   <= '0';
  uart_rtscts_o   <= '0';

  uart_tstart_o <= tx_start_r;
  uart_tdata_o  <= tx_data_r;
  dp_load_base_o <= load_base_r;
  dp_load_enc_o <= '0';
  dp_event_report_o <= event_report_r;
  dp_event_enc_valid_o <= '0';
  dp_rx_count_o <= TM_RECEIVED_COUNT_i;
  dp_ok_count_o <= TM_CORRECT_COUNT_i;
  dp_flags_o <= flags_latched_r when event_report_r = '1' else event_flags_w;
  dp_enc_src_o <= (others => '0');
  dp_enc_data_o <= (others => '0');
  dp_nibble_index_o <= nibble_index_r;
  dp_label_index_o <= label_index_r;
  period_report_consume_o <= load_base_r;

  with phase_r select
    dp_label_sel_o <=
      "000" when PH_RX_LABEL,
      "000" when PH_RX_HEX,
      "001" when PH_OK_LABEL,
      "001" when PH_OK_HEX,
      "010" when PH_FLAGS_LABEL,
      "010" when others;

  event_flags_w <=
    C_MANAGER_FLAGS_RESERVED_PAD &
    OBS_UART_ENCODE_CRITICAL_TMR_ERROR_i &
    OBS_UART_COMMAND_CTRL_TMR_ERROR_i &
    OBS_START_DONE_CTRL_TMR_ERROR_i &
    tm_comparison_mismatch_i &
    NI_CORRUPT_PACKET_i &
    OBS_TM_TMR_CTRL_ERROR_i &
    OBS_TM_HAM_BUFFER_SINGLE_ERR_i &
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_i &
    OBS_TM_HAM_RECEIVED_COUNTER_SINGLE_ERR_i &
    OBS_TM_HAM_RECEIVED_COUNTER_DOUBLE_ERR_i &
    OBS_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_i &
    OBS_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_i &
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
    OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_i &
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i &
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i &
    OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i &
    OBS_BE_RX_INTEGRITY_CORRUPT_i &
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i &
    OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i &
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      tx_start_r <= '0';
      load_base_r <= '0';

      if ARESETn = '0' then
        state_r <= ST_IDLE;
        phase_r <= PH_RX_LABEL;
        label_index_r <= 1;
        nibble_index_r <= (others => '0');
        event_pending_r <= '0';
        event_report_r <= '0';
        flags_seen_r <= (others => '0');
        flags_latched_r <= (others => '0');
      else
        if tm_done_rise_i = '1' then
          if f_has_new_error_flags(event_flags_w, flags_seen_r) then
            event_pending_r <= '1';
            flags_latched_r <= event_flags_w;
          end if;
          flags_seen_r <= event_flags_w;
        end if;

        case state_r is
          when ST_IDLE =>
            if (period_report_due_i = '1') or (event_pending_r = '1') then
              event_report_r <= event_pending_r;
              event_pending_r <= '0';
              load_base_r <= '1';
              phase_r <= PH_RX_LABEL;
              label_index_r <= 1;
              state_r <= ST_SEND;
            end if;

          when ST_SEND =>
            if uart_tready_i = '1' then
              if phase_r = PH_LF then
                tx_data_r <= x"0A";
              elsif (phase_r = PH_RX_LABEL) or (phase_r = PH_OK_LABEL) or (phase_r = PH_FLAGS_LABEL) then
                tx_data_r <= dp_label_char_i;
              else
                tx_data_r <= dp_hex_char_i;
              end if;
              tx_start_r <= '1';
              state_r <= ST_WAIT_DONE;
            end if;

          when ST_WAIT_DONE =>
            if uart_tdone_i = '1' then
              case phase_r is
                when PH_RX_LABEL =>
                  if label_index_r < C_LABEL_RX'length then
                    label_index_r <= label_index_r + 1;
                  else
                    phase_r <= PH_RX_HEX;
                    p_set_hex_window(nibble_index_r, c_TM_COUNTER_WIDTH);
                  end if;
                  state_r <= ST_SEND;

                when PH_RX_HEX =>
                  if nibble_index_r = 0 then
                    phase_r <= PH_OK_LABEL;
                    label_index_r <= 1;
                  else
                    nibble_index_r <= nibble_index_r - 1;
                  end if;
                  state_r <= ST_SEND;

                when PH_OK_LABEL =>
                  if label_index_r < C_LABEL_OK'length then
                    label_index_r <= label_index_r + 1;
                  else
                    phase_r <= PH_OK_HEX;
                    p_set_hex_window(nibble_index_r, c_TM_COUNTER_WIDTH);
                  end if;
                  state_r <= ST_SEND;

                when PH_OK_HEX =>
                  if nibble_index_r = 0 then
                    phase_r <= PH_FLAGS_LABEL;
                    label_index_r <= 1;
                  else
                    nibble_index_r <= nibble_index_r - 1;
                  end if;
                  state_r <= ST_SEND;

                when PH_FLAGS_LABEL =>
                  if label_index_r < C_LABEL_FLAGS'length then
                    label_index_r <= label_index_r + 1;
                    state_r <= ST_SEND;
                  else
                    phase_r <= PH_FLAGS_HEX;
                    nibble_index_r <= to_unsigned((c_TM_UART_FLAGS_WIDTH / 4) - 1, nibble_index_r'length);
                    state_r <= ST_SEND;
                  end if;

                when PH_LF =>
                  state_r <= ST_IDLE;

                when others =>
                  if nibble_index_r = 0 then
                    phase_r <= PH_LF;
                    state_r <= ST_SEND;
                  else
                    nibble_index_r <= nibble_index_r - 1;
                    state_r <= ST_SEND;
                  end if;
              end case;
            end if;

          when others =>
            state_r <= ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
