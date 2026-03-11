library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- UART manager for closed-box self-test:
-- * encodes fault/status vector as labeled ASCII text + LF
-- * decodes UART RX commands to control experiment and OBS enables
entity tg_tm_lb_selftest_uart_encode_ctrl is
  generic (
    G_REPORT_PERIOD_PACKETS : positive := c_TM_UART_REPORT_PERIOD_PACKETS
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_tm_done : in std_logic;

    -- Observability inputs used for UART report
    i_tm_comparison_mismatch : in  std_logic;
    i_TM_TRANSACTION_COUNT   : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    i_TM_EXPECTED_VALUE      : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    i_NI_CORRUPT_PACKET      : in std_logic;

    i_OBS_TM_TMR_CTRL_ERROR : in std_logic;
    i_OBS_TM_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_TM_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_TM_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR : in std_logic;
    i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR : in std_logic;
    i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_LB_TMR_CTRL_ERROR : in std_logic;
    i_OBS_LB_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_LB_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_LB_HAM_BUFFER_ENC_DATA : in std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, c_ENABLE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_TG_TMR_CTRL_ERROR : in std_logic;
    i_OBS_TG_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_TG_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_TG_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_FE_INJ_META_HDR_SINGLE_ERR : in std_logic;
    i_OBS_FE_INJ_META_HDR_DOUBLE_ERR : in std_logic;
    i_OBS_FE_INJ_ADDR_SINGLE_ERR : in std_logic;
    i_OBS_FE_INJ_ADDR_DOUBLE_ERR : in std_logic;
    i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA : in std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_FE_INJ_HAM_ADDR_ENC_DATA : in std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR : in std_logic;
    i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR : in std_logic;
    i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR : in std_logic;

    i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_RX_INTEGRITY_CORRUPT : in std_logic;
    i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR : in std_logic;
    i_OBS_START_DONE_CTRL_TMR_ERROR : in std_logic;

    -- OBS enables (to DUT), controlled from UART commands
    o_OBS_TM_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_TM_TMR_CTRL_CORRECT_ERROR   : out std_logic;
    o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR : out std_logic;

    o_OBS_LB_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_LB_TMR_CTRL_CORRECT_ERROR   : out std_logic;

    o_OBS_TG_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_TG_TMR_CTRL_CORRECT_ERROR   : out std_logic;

    o_OBS_FE_INJ_META_HDR_CORRECT_ERROR : out std_logic;
    o_OBS_FE_INJ_ADDR_CORRECT_ERROR     : out std_logic;

    o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR : out std_logic;

    o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_START_DONE_CTRL_TMR_CORRECT_ERROR : out std_logic;

    -- Experiment control outputs
    o_experiment_run_enable  : out std_logic;
    o_experiment_reset_pulse : out std_logic;

    -- UART config
    o_uart_baud_div : out std_logic_vector(15 downto 0);
    o_uart_parity   : out std_logic;
    o_uart_rtscts   : out std_logic;

    -- UART TX interface
    i_uart_tready : in  std_logic;
    i_uart_tdone  : in  std_logic;
    o_uart_tstart : out std_logic;
    o_uart_tdata  : out std_logic_vector(7 downto 0);

    -- UART RX interface
    o_uart_rready : out std_logic;
    i_uart_rdone  : in  std_logic;
    i_uart_rdata  : in  std_logic_vector(7 downto 0);
    i_uart_rerr   : in  std_logic;

    -- Datapath interface
    i_dp_hex_char   : in  std_logic_vector(7 downto 0);
    i_dp_label_char : in  std_logic_vector(7 downto 0);
    o_dp_load_base  : out std_logic;
    o_dp_load_enc   : out std_logic;
    o_dp_tm_count   : out std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    o_dp_flags      : out std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
    o_dp_enc_src    : out std_logic_vector(3 downto 0);
    o_dp_enc_data   : out std_logic_vector(79 downto 0);
    o_dp_nibble_index : out unsigned(4 downto 0);
    o_dp_label_sel  : out std_logic_vector(2 downto 0);
    o_dp_label_index : out natural range 1 to 8
  );
end entity;

architecture rtl of tg_tm_lb_selftest_uart_encode_ctrl is
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

  signal w_dp_label_sel    : std_logic_vector(2 downto 0);
  signal uart_tstart_r     : std_logic := '0';
  signal uart_tdata_r      : std_logic_vector(7 downto 0) := (others => '0');

  signal run_enable_r      : std_logic := '1';
  signal obs_enable_r      : std_logic := '1';
  signal reset_pulse_r     : std_logic := '0';

  signal tm_done_d_r       : std_logic := '0';
  signal w_tm_done_rise    : std_logic;
  signal w_any_error       : std_logic;
  signal pending_enc_line_r : std_logic := '0';
  signal dp_load_base_r    : std_logic := '0';
  signal dp_load_enc_r     : std_logic := '0';
  signal tm_count_payload_r : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0) := (others => '0');
  signal flags_payload_r    : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0) := (others => '0');
  signal enc_src_payload_r  : std_logic_vector(3 downto 0) := (others => '0');
  signal enc_data_payload_r : std_logic_vector(79 downto 0) := (others => '0');
  signal enc_src_pending_r  : std_logic_vector(3 downto 0) := (others => '0');
  signal enc_data_pending_r : std_logic_vector(79 downto 0) := (others => '0');
  signal report_has_flags_r : std_logic := '0';
  signal report_counter_r   : integer range 0 to G_REPORT_PERIOD_PACKETS - 1 := 0;
  signal period_report_due_r : std_logic := '0';

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

begin
  -- static UART configuration
  o_uart_baud_div <= x"0001";
  o_uart_parity   <= '0';
  o_uart_rtscts   <= '0';

  -- always ready to receive commands
  o_uart_rready <= '1';

  o_uart_tstart <= uart_tstart_r;
  o_uart_tdata  <= uart_tdata_r;
  o_dp_load_base    <= dp_load_base_r;
  o_dp_load_enc     <= dp_load_enc_r;
  o_dp_tm_count     <= tm_count_payload_r;
  o_dp_flags        <= flags_payload_r;
  o_dp_enc_src      <= enc_src_payload_r;
  o_dp_enc_data     <= enc_data_payload_r;
  o_dp_nibble_index <= nibble_index_r;
  o_dp_label_sel    <= w_dp_label_sel;
  o_dp_label_index  <= label_index_r;

  o_experiment_run_enable  <= run_enable_r;
  o_experiment_reset_pulse <= reset_pulse_r;

  o_OBS_TM_HAM_BUFFER_CORRECT_ERROR <= obs_enable_r;
  o_OBS_TM_TMR_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR <= obs_enable_r;
  o_OBS_LB_HAM_BUFFER_CORRECT_ERROR <= obs_enable_r;
  o_OBS_LB_TMR_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_TG_HAM_BUFFER_CORRECT_ERROR <= obs_enable_r;
  o_OBS_TG_TMR_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_FE_INJ_META_HDR_CORRECT_ERROR <= obs_enable_r;
  o_OBS_FE_INJ_ADDR_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR <= obs_enable_r;
  o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR <= obs_enable_r;
  o_OBS_START_DONE_CTRL_TMR_CORRECT_ERROR <= obs_enable_r;

  w_tm_done_rise <= i_tm_done and (not tm_done_d_r);
  w_any_error <=
    i_tm_comparison_mismatch or i_NI_CORRUPT_PACKET or
    i_OBS_TM_TMR_CTRL_ERROR or
    i_OBS_TM_HAM_BUFFER_SINGLE_ERR or i_OBS_TM_HAM_BUFFER_DOUBLE_ERR or
    i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR or i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR or
    i_OBS_LB_TMR_CTRL_ERROR or i_OBS_LB_HAM_BUFFER_SINGLE_ERR or i_OBS_LB_HAM_BUFFER_DOUBLE_ERR or
    i_OBS_TG_TMR_CTRL_ERROR or i_OBS_TG_HAM_BUFFER_SINGLE_ERR or i_OBS_TG_HAM_BUFFER_DOUBLE_ERR or
    i_OBS_FE_INJ_META_HDR_SINGLE_ERR or i_OBS_FE_INJ_META_HDR_DOUBLE_ERR or
    i_OBS_FE_INJ_ADDR_SINGLE_ERR or i_OBS_FE_INJ_ADDR_DOUBLE_ERR or
    i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR or i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR or
    i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR or
    i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR or i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR or
    i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR or i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR or
    i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR or i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR or
    i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR or i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR or
    i_OBS_BE_RX_INTEGRITY_CORRUPT or
    i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR or i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR or
    i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR or
    i_OBS_START_DONE_CTRL_TMR_ERROR;

  -- Datapath/control split:
  -- * this module keeps controller FSM
  -- * datapath module generates label and hex bytes
  with tx_phase_r select
    w_dp_label_sel <=
      "001" when PH_BASE_TM_LABEL,
      "010" when PH_BASE_FLAGS_LABEL,
      "011" when PH_ENC_LABEL,
      "100" when PH_ENC_DATA_LABEL,
      "111" when others;

  process(ACLK)
    variable v_do_report : boolean;
    variable v_is_event  : boolean;
    variable v_flags     : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        tx_state_r     <= S_IDLE;
        tx_phase_r     <= PH_BASE_TM_LABEL;
        wait_source_r  <= WS_LABEL;
        dp_load_base_r <= '0';
        dp_load_enc_r  <= '0';
        tm_count_payload_r <= (others => '0');
        flags_payload_r <= (others => '0');
        enc_src_payload_r <= (others => '0');
        enc_data_payload_r <= (others => '0');
        enc_src_pending_r <= (others => '0');
        enc_data_pending_r <= (others => '0');
        nibble_index_r <= to_unsigned(C_BASE_TM_NIBBLE_START, 5);
        nibble_stop_r  <= to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
        label_index_r  <= 1;
        uart_tstart_r  <= '0';
        uart_tdata_r   <= (others => '0');
        run_enable_r   <= '1';
        obs_enable_r   <= '1';
        reset_pulse_r  <= '0';
        tm_done_d_r    <= '0';
        pending_enc_line_r <= '0';
        report_has_flags_r <= '0';
        report_counter_r   <= 0;
        period_report_due_r <= '0';
      else
        tm_done_d_r    <= i_tm_done;
        reset_pulse_r  <= '0';
        uart_tstart_r  <= '0';
        dp_load_base_r <= '0';
        dp_load_enc_r  <= '0';

        if w_tm_done_rise = '1' then
          if report_counter_r = G_REPORT_PERIOD_PACKETS - 1 then
            report_counter_r    <= 0;
            period_report_due_r <= '1';
          else
            report_counter_r <= report_counter_r + 1;
          end if;
        end if;

        if (i_uart_rdone = '1') and (i_uart_rerr = '0') then
          case i_uart_rdata is
            when x"53" => run_enable_r  <= '1'; -- S
            when x"50" => run_enable_r  <= '0'; -- P
            when x"52" => reset_pulse_r <= '1'; -- R
            when x"45" => obs_enable_r  <= '1'; -- E
            when x"44" => obs_enable_r  <= '0'; -- D
            when others => null;
          end case;
        end if;

        case tx_state_r is
          when S_IDLE =>
            v_is_event  := ((w_tm_done_rise = '1') and (w_any_error = '1'));
            v_do_report := (period_report_due_r = '1') or v_is_event;
            if v_do_report then
              period_report_due_r <= '0';

              -- Base status frame payload (assembled in datapath).
              tm_count_payload_r <= i_TM_TRANSACTION_COUNT;
              v_flags := (others => '0');
              if v_is_event then
                report_has_flags_r <= '1';
                v_flags(27) := i_tm_comparison_mismatch;
                v_flags(26) := i_NI_CORRUPT_PACKET;
                v_flags(25) := i_OBS_TM_TMR_CTRL_ERROR;
                v_flags(24) := i_OBS_TM_HAM_BUFFER_SINGLE_ERR;
                v_flags(23) := i_OBS_TM_HAM_BUFFER_DOUBLE_ERR;
                v_flags(22) := i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR;
                v_flags(21) := i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR;
                v_flags(20) := i_OBS_LB_TMR_CTRL_ERROR;
                v_flags(19) := i_OBS_LB_HAM_BUFFER_SINGLE_ERR;
                v_flags(18) := i_OBS_LB_HAM_BUFFER_DOUBLE_ERR;
                v_flags(17) := i_OBS_TG_TMR_CTRL_ERROR;
                v_flags(16) := i_OBS_TG_HAM_BUFFER_SINGLE_ERR;
                v_flags(15) := i_OBS_TG_HAM_BUFFER_DOUBLE_ERR;
                v_flags(14) := i_OBS_FE_INJ_META_HDR_SINGLE_ERR;
                v_flags(13) := i_OBS_FE_INJ_META_HDR_DOUBLE_ERR;
                v_flags(12) := i_OBS_FE_INJ_ADDR_SINGLE_ERR;
                v_flags(11) := i_OBS_FE_INJ_ADDR_DOUBLE_ERR;
                v_flags(10) := i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR;
                v_flags(9)  := i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR;
                v_flags(8)  := i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR;
                v_flags(7)  := i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR;
                v_flags(6)  := i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR;
                v_flags(5)  := i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR;
                v_flags(4)  := i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR;
                v_flags(3)  := i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR;
                v_flags(2)  := i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR;
                v_flags(1)  := i_OBS_BE_RX_INTEGRITY_CORRUPT;
                v_flags(0)  := i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR;
                v_flags(28) := i_OBS_START_DONE_CTRL_TMR_ERROR;
              else
                report_has_flags_r <= '0';
              end if;
              flags_payload_r <= v_flags;
              dp_load_base_r <= '1';

              pending_enc_line_r <= '0';
              if v_is_event and ((i_OBS_TM_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_TM_HAM_BUFFER_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"1";
                enc_data_pending_r <= f_pack80(i_OBS_TM_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR = '1') or (i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"2";
                enc_data_pending_r <= f_pack80(i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA);
              elsif v_is_event and ((i_OBS_LB_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_LB_HAM_BUFFER_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"3";
                enc_data_pending_r <= f_pack80(i_OBS_LB_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_TG_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_TG_HAM_BUFFER_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"4";
                enc_data_pending_r <= f_pack80(i_OBS_TG_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_FE_INJ_META_HDR_SINGLE_ERR = '1') or (i_OBS_FE_INJ_META_HDR_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"5";
                enc_data_pending_r <= f_pack80(i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA);
              elsif v_is_event and ((i_OBS_FE_INJ_ADDR_SINGLE_ERR = '1') or (i_OBS_FE_INJ_ADDR_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"6";
                enc_data_pending_r <= f_pack80(i_OBS_FE_INJ_HAM_ADDR_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"7";
                enc_data_pending_r <= f_pack80(i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR = '1') or (i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"8";
                enc_data_pending_r <= f_pack80(i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"9";
                enc_data_pending_r <= f_pack80(i_OBS_BE_RX_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"A";
                enc_data_pending_r <= f_pack80(i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR = '1')) then
                pending_enc_line_r <= '1';
                enc_src_pending_r  <= x"B";
                enc_data_pending_r <= f_pack80(i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA);
              end if;

              tx_phase_r    <= PH_BASE_TM_LABEL;
              label_index_r <= 1;
              tx_state_r    <= S_SEND_LABEL;
            end if;

          when S_SEND_LABEL =>
            if i_uart_tready = '1' then
              case tx_phase_r is
                when PH_BASE_TM_LABEL =>
                  uart_tdata_r <= i_dp_label_char;
                when PH_BASE_FLAGS_LABEL =>
                  uart_tdata_r <= i_dp_label_char;
                when PH_ENC_LABEL =>
                  uart_tdata_r <= i_dp_label_char;
                when PH_ENC_DATA_LABEL =>
                  uart_tdata_r <= i_dp_label_char;
                when others =>
                  uart_tdata_r <= x"3F"; -- '?'
              end case;
              uart_tstart_r <= '1';
              wait_source_r <= WS_LABEL;
              tx_state_r    <= S_WAIT_DONE;
            end if;

          when S_SEND_HEX =>
            if i_uart_tready = '1' then
              uart_tdata_r  <= i_dp_hex_char;
              uart_tstart_r <= '1';
              wait_source_r <= WS_HEX;
              tx_state_r    <= S_WAIT_DONE;
            end if;

          when S_SEND_LF =>
            if i_uart_tready = '1' then
              uart_tdata_r  <= x"0A";
              uart_tstart_r <= '1';
              wait_source_r <= WS_LF;
              tx_state_r    <= S_WAIT_DONE;
            end if;

          when S_WAIT_DONE =>
            if i_uart_tdone = '1' then
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
                        if report_has_flags_r = '1' then
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
                    if pending_enc_line_r = '1' then
                      enc_src_payload_r  <= enc_src_pending_r;
                      enc_data_payload_r <= enc_data_pending_r;
                      dp_load_enc_r      <= '1';
                      pending_enc_line_r <= '0';
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
