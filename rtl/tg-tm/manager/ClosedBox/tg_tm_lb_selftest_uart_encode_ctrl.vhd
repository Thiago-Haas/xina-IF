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

  type t_tx_state is (S_IDLE, S_SEND_LABEL, S_SEND_HEX, S_SEND_LF, S_WAIT_DONE);
  type t_tx_phase is (
    PH_BASE_TM_LABEL,
    PH_BASE_TM_HEX,
    PH_BASE_FLAGS_LABEL,
    PH_BASE_FLAGS_HEX,
    PH_ENC_LABEL,
    PH_ENC_SRC_HEX,
    PH_ENC_DATA_LABEL,
    PH_ENC_DATA_HEX
  );
  type t_wait_source is (WS_LABEL, WS_HEX, WS_LF);

  signal r_tx_state      : t_tx_state := S_IDLE;
  signal r_tx_phase      : t_tx_phase := PH_BASE_TM_LABEL;
  signal r_wait_source   : t_wait_source := WS_LABEL;

  signal r_nibble_index    : unsigned(4 downto 0) := to_unsigned(C_BASE_TM_NIBBLE_START, 5);
  signal r_nibble_stop     : unsigned(4 downto 0) := to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
  signal r_label_index     : natural range 1 to 8 := 1;

  signal w_dp_label_sel    : std_logic_vector(2 downto 0);
  signal r_uart_tstart     : std_logic := '0';
  signal r_uart_tdata      : std_logic_vector(7 downto 0) := (others => '0');

  signal r_run_enable      : std_logic := '1';
  signal r_obs_enable      : std_logic := '1';
  signal r_reset_pulse     : std_logic := '0';

  signal r_tm_done_d       : std_logic := '0';
  signal w_tm_done_rise    : std_logic;
  signal w_any_error       : std_logic;
  signal r_pending_enc_line : std_logic := '0';
  signal r_dp_load_base    : std_logic := '0';
  signal r_dp_load_enc     : std_logic := '0';
  signal r_tm_count_payload : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0) := (others => '0');
  signal r_flags_payload    : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0) := (others => '0');
  signal r_enc_src_payload  : std_logic_vector(3 downto 0) := (others => '0');
  signal r_enc_data_payload : std_logic_vector(79 downto 0) := (others => '0');
  signal r_enc_src_pending  : std_logic_vector(3 downto 0) := (others => '0');
  signal r_enc_data_pending : std_logic_vector(79 downto 0) := (others => '0');
  signal r_report_has_flags : std_logic := '0';
  signal r_report_counter   : integer range 0 to G_REPORT_PERIOD_PACKETS - 1 := 0;
  signal r_period_report_due : std_logic := '0';

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

  o_uart_tstart <= r_uart_tstart;
  o_uart_tdata  <= r_uart_tdata;
  o_dp_load_base    <= r_dp_load_base;
  o_dp_load_enc     <= r_dp_load_enc;
  o_dp_tm_count     <= r_tm_count_payload;
  o_dp_flags        <= r_flags_payload;
  o_dp_enc_src      <= r_enc_src_payload;
  o_dp_enc_data     <= r_enc_data_payload;
  o_dp_nibble_index <= r_nibble_index;
  o_dp_label_sel    <= w_dp_label_sel;
  o_dp_label_index  <= r_label_index;

  o_experiment_run_enable  <= r_run_enable;
  o_experiment_reset_pulse <= r_reset_pulse;

  o_OBS_TM_HAM_BUFFER_CORRECT_ERROR <= r_obs_enable;
  o_OBS_TM_TMR_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR <= r_obs_enable;
  o_OBS_LB_HAM_BUFFER_CORRECT_ERROR <= r_obs_enable;
  o_OBS_LB_TMR_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_TG_HAM_BUFFER_CORRECT_ERROR <= r_obs_enable;
  o_OBS_TG_TMR_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_FE_INJ_META_HDR_CORRECT_ERROR <= r_obs_enable;
  o_OBS_FE_INJ_ADDR_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR <= r_obs_enable;
  o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR <= r_obs_enable;
  o_OBS_START_DONE_CTRL_TMR_CORRECT_ERROR <= r_obs_enable;

  w_tm_done_rise <= i_tm_done and (not r_tm_done_d);
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
  with r_tx_phase select
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
        r_tx_state     <= S_IDLE;
        r_tx_phase     <= PH_BASE_TM_LABEL;
        r_wait_source  <= WS_LABEL;
        r_dp_load_base <= '0';
        r_dp_load_enc  <= '0';
        r_tm_count_payload <= (others => '0');
        r_flags_payload <= (others => '0');
        r_enc_src_payload <= (others => '0');
        r_enc_data_payload <= (others => '0');
        r_enc_src_pending <= (others => '0');
        r_enc_data_pending <= (others => '0');
        r_nibble_index <= to_unsigned(C_BASE_TM_NIBBLE_START, 5);
        r_nibble_stop  <= to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
        r_label_index  <= 1;
        r_uart_tstart  <= '0';
        r_uart_tdata   <= (others => '0');
        r_run_enable   <= '1';
        r_obs_enable   <= '1';
        r_reset_pulse  <= '0';
        r_tm_done_d    <= '0';
        r_pending_enc_line <= '0';
        r_report_has_flags <= '0';
        r_report_counter   <= 0;
        r_period_report_due <= '0';
      else
        r_tm_done_d    <= i_tm_done;
        r_reset_pulse  <= '0';
        r_uart_tstart  <= '0';
        r_dp_load_base <= '0';
        r_dp_load_enc  <= '0';

        if w_tm_done_rise = '1' then
          if r_report_counter = G_REPORT_PERIOD_PACKETS - 1 then
            r_report_counter    <= 0;
            r_period_report_due <= '1';
          else
            r_report_counter <= r_report_counter + 1;
          end if;
        end if;

        if (i_uart_rdone = '1') and (i_uart_rerr = '0') then
          case i_uart_rdata is
            when x"53" => r_run_enable  <= '1'; -- S
            when x"50" => r_run_enable  <= '0'; -- P
            when x"52" => r_reset_pulse <= '1'; -- R
            when x"45" => r_obs_enable  <= '1'; -- E
            when x"44" => r_obs_enable  <= '0'; -- D
            when others => null;
          end case;
        end if;

        case r_tx_state is
          when S_IDLE =>
            v_is_event  := ((w_tm_done_rise = '1') and (w_any_error = '1'));
            v_do_report := (r_period_report_due = '1') or v_is_event;
            if v_do_report then
              r_period_report_due <= '0';

              -- Base status frame payload (assembled in datapath).
              r_tm_count_payload <= i_TM_TRANSACTION_COUNT;
              v_flags := (others => '0');
              if v_is_event then
                r_report_has_flags <= '1';
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
                r_report_has_flags <= '0';
              end if;
              r_flags_payload <= v_flags;
              r_dp_load_base <= '1';

              r_pending_enc_line <= '0';
              if v_is_event and ((i_OBS_TM_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_TM_HAM_BUFFER_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"1";
                r_enc_data_pending <= f_pack80(i_OBS_TM_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR = '1') or (i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"2";
                r_enc_data_pending <= f_pack80(i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA);
              elsif v_is_event and ((i_OBS_LB_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_LB_HAM_BUFFER_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"3";
                r_enc_data_pending <= f_pack80(i_OBS_LB_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_TG_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_TG_HAM_BUFFER_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"4";
                r_enc_data_pending <= f_pack80(i_OBS_TG_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_FE_INJ_META_HDR_SINGLE_ERR = '1') or (i_OBS_FE_INJ_META_HDR_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"5";
                r_enc_data_pending <= f_pack80(i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA);
              elsif v_is_event and ((i_OBS_FE_INJ_ADDR_SINGLE_ERR = '1') or (i_OBS_FE_INJ_ADDR_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"6";
                r_enc_data_pending <= f_pack80(i_OBS_FE_INJ_HAM_ADDR_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"7";
                r_enc_data_pending <= f_pack80(i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR = '1') or (i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"8";
                r_enc_data_pending <= f_pack80(i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"9";
                r_enc_data_pending <= f_pack80(i_OBS_BE_RX_HAM_BUFFER_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"A";
                r_enc_data_pending <= f_pack80(i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA);
              elsif v_is_event and ((i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR = '1')) then
                r_pending_enc_line <= '1';
                r_enc_src_pending  <= x"B";
                r_enc_data_pending <= f_pack80(i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA);
              end if;

              r_tx_phase    <= PH_BASE_TM_LABEL;
              r_label_index <= 1;
              r_tx_state    <= S_SEND_LABEL;
            end if;

          when S_SEND_LABEL =>
            if i_uart_tready = '1' then
              case r_tx_phase is
                when PH_BASE_TM_LABEL =>
                  r_uart_tdata <= i_dp_label_char;
                when PH_BASE_FLAGS_LABEL =>
                  r_uart_tdata <= i_dp_label_char;
                when PH_ENC_LABEL =>
                  r_uart_tdata <= i_dp_label_char;
                when PH_ENC_DATA_LABEL =>
                  r_uart_tdata <= i_dp_label_char;
                when others =>
                  r_uart_tdata <= x"3F"; -- '?'
              end case;
              r_uart_tstart <= '1';
              r_wait_source <= WS_LABEL;
              r_tx_state    <= S_WAIT_DONE;
            end if;

          when S_SEND_HEX =>
            if i_uart_tready = '1' then
              r_uart_tdata  <= i_dp_hex_char;
              r_uart_tstart <= '1';
              r_wait_source <= WS_HEX;
              r_tx_state    <= S_WAIT_DONE;
            end if;

          when S_SEND_LF =>
            if i_uart_tready = '1' then
              r_uart_tdata  <= x"0A";
              r_uart_tstart <= '1';
              r_wait_source <= WS_LF;
              r_tx_state    <= S_WAIT_DONE;
            end if;

          when S_WAIT_DONE =>
            if i_uart_tdone = '1' then
              case r_wait_source is
                when WS_LABEL =>
                  case r_tx_phase is
                    when PH_BASE_TM_LABEL =>
                      if r_label_index < C_LABEL_TM'length then
                        r_label_index <= r_label_index + 1;
                        r_tx_state    <= S_SEND_LABEL;
                      else
                        r_tx_phase    <= PH_BASE_TM_HEX;
                        r_nibble_index <= to_unsigned(C_BASE_TM_NIBBLE_START, 5);
                        r_nibble_stop  <= to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
                        r_tx_state    <= S_SEND_HEX;
                      end if;
                    when PH_BASE_FLAGS_LABEL =>
                      if r_label_index < C_LABEL_FLAGS'length then
                        r_label_index <= r_label_index + 1;
                        r_tx_state    <= S_SEND_LABEL;
                      else
                        r_tx_phase     <= PH_BASE_FLAGS_HEX;
                        r_nibble_index <= to_unsigned(C_BASE_FLAGS_NIBBLE_START, 5);
                        r_nibble_stop  <= to_unsigned(C_BASE_FLAGS_NIBBLE_STOP, 5);
                        r_tx_state     <= S_SEND_HEX;
                      end if;
                    when PH_ENC_LABEL =>
                      if r_label_index < C_LABEL_ENC'length then
                        r_label_index <= r_label_index + 1;
                        r_tx_state    <= S_SEND_LABEL;
                      else
                        r_tx_phase     <= PH_ENC_SRC_HEX;
                        r_nibble_index <= to_unsigned(C_ENC_SRC_NIBBLE_START, 5);
                        r_nibble_stop  <= to_unsigned(C_ENC_SRC_NIBBLE_STOP, 5);
                        r_tx_state     <= S_SEND_HEX;
                      end if;
                    when PH_ENC_DATA_LABEL =>
                      if r_label_index < C_LABEL_DATA'length then
                        r_label_index <= r_label_index + 1;
                        r_tx_state    <= S_SEND_LABEL;
                      else
                        r_tx_phase     <= PH_ENC_DATA_HEX;
                        r_nibble_index <= to_unsigned(C_ENC_DATA_NIBBLE_START, 5);
                        r_nibble_stop  <= to_unsigned(C_ENC_DATA_NIBBLE_STOP, 5);
                        r_tx_state     <= S_SEND_HEX;
                      end if;
                    when others =>
                      r_tx_state <= S_IDLE;
                  end case;

                when WS_HEX =>
                  if r_nibble_index /= r_nibble_stop then
                    r_nibble_index <= r_nibble_index - 1;
                    r_tx_state     <= S_SEND_HEX;
                  else
                    case r_tx_phase is
                      when PH_BASE_TM_HEX =>
                        if r_report_has_flags = '1' then
                          r_tx_phase    <= PH_BASE_FLAGS_LABEL;
                          r_label_index <= 1;
                          r_tx_state    <= S_SEND_LABEL;
                        else
                          r_tx_state <= S_SEND_LF;
                        end if;
                      when PH_BASE_FLAGS_HEX =>
                        r_tx_state <= S_SEND_LF;
                      when PH_ENC_SRC_HEX =>
                        r_tx_phase    <= PH_ENC_DATA_LABEL;
                        r_label_index <= 1;
                        r_tx_state    <= S_SEND_LABEL;
                      when PH_ENC_DATA_HEX =>
                        r_tx_state <= S_SEND_LF;
                      when others =>
                        r_tx_state <= S_IDLE;
                    end case;
                  end if;

                when WS_LF =>
                  if r_tx_phase = PH_BASE_FLAGS_HEX then
                    if r_pending_enc_line = '1' then
                      r_enc_src_payload  <= r_enc_src_pending;
                      r_enc_data_payload <= r_enc_data_pending;
                      r_dp_load_enc      <= '1';
                      r_pending_enc_line <= '0';
                      r_tx_phase         <= PH_ENC_LABEL;
                      r_label_index      <= 1;
                      r_tx_state         <= S_SEND_LABEL;
                    else
                      r_tx_state <= S_IDLE;
                    end if;
                  else
                    r_tx_state <= S_IDLE;
                  end if;
              end case;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
