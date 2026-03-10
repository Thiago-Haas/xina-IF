library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- UART manager for closed-box self-test:
-- * encodes fault/status vector as labeled ASCII text + LF
-- * decodes UART RX commands to control experiment and OBS enables
entity tg_tm_lb_selftest_uart_encode_block is
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
    i_uart_rerr   : in  std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_uart_encode_block is
  constant C_BASE_TM_NIBBLE_START    : natural := 12;
  constant C_BASE_TM_NIBBLE_STOP     : natural := 7;
  constant C_BASE_FLAGS_NIBBLE_START : natural := 6;
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

  signal r_fault_data      : std_logic_vector(83 downto 0) := (others => '0');
  signal r_nibble_index    : unsigned(4 downto 0) := to_unsigned(C_BASE_TM_NIBBLE_START, 5);
  signal r_nibble_stop     : unsigned(4 downto 0) := to_unsigned(C_BASE_TM_NIBBLE_STOP, 5);
  signal r_label_index     : natural range 1 to 8 := 1;

  signal w_nibble_data     : std_logic_vector(3 downto 0);
  signal w_utf_data        : std_logic_vector(7 downto 0);
  signal r_uart_tstart     : std_logic := '0';
  signal r_uart_tdata      : std_logic_vector(7 downto 0) := (others => '0');

  signal r_run_enable      : std_logic := '1';
  signal r_obs_enable      : std_logic := '1';
  signal r_reset_pulse     : std_logic := '0';

  signal r_tm_done_d       : std_logic := '0';
  signal w_tm_done_rise    : std_logic;
  signal w_any_error       : std_logic;
  signal r_pending_enc_line : std_logic := '0';
  signal r_enc_line_data    : std_logic_vector(83 downto 0) := (others => '0');
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

  function f_char_to_slv8(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
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
    i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR;

  -- nibble mux (MS nibble first)
  with to_integer(r_nibble_index) select
    w_nibble_data <=
      r_fault_data(83 downto 80) when 20,
      r_fault_data(79 downto 76) when 19,
      r_fault_data(75 downto 72) when 18,
      r_fault_data(71 downto 68) when 17,
      r_fault_data(67 downto 64) when 16,
      r_fault_data(63 downto 60) when 15,
      r_fault_data(59 downto 56) when 14,
      r_fault_data(55 downto 52) when 13,
      r_fault_data(51 downto 48) when 12,
      r_fault_data(47 downto 44) when 11,
      r_fault_data(43 downto 40) when 10,
      r_fault_data(39 downto 36) when 9,
      r_fault_data(35 downto 32) when 8,
      r_fault_data(31 downto 28) when 7,
      r_fault_data(27 downto 24) when 6,
      r_fault_data(23 downto 20) when 5,
      r_fault_data(19 downto 16) when 4,
      r_fault_data(15 downto 12) when 3,
      r_fault_data(11 downto 8)  when 2,
      r_fault_data(7 downto 4)   when 1,
      r_fault_data(3 downto 0)   when others;

  u_utf8_hex: entity work.utf8_hex
    port map(
      ctl_writelf_i => '0',
      data_i        => w_nibble_data,
      utf_data_o    => w_utf_data
    );

  process(ACLK)
    variable v_do_report : boolean;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_tx_state     <= S_IDLE;
        r_tx_phase     <= PH_BASE_TM_LABEL;
        r_wait_source  <= WS_LABEL;
        r_fault_data   <= (others => '0');
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
        r_enc_line_data    <= (others => '0');
        r_report_counter   <= 0;
        r_period_report_due <= '0';
      else
        r_tm_done_d    <= i_tm_done;
        r_reset_pulse  <= '0';
        r_uart_tstart  <= '0';

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
            v_do_report := (r_period_report_due = '1') or ((w_tm_done_rise = '1') and (w_any_error = '1'));
            if v_do_report then
              r_period_report_due <= '0';

              -- base status/fault frame (TM expected value intentionally removed)
              r_fault_data(83 downto 52) <= (others => '0');
              r_fault_data(51 downto 28) <= i_TM_TRANSACTION_COUNT(23 downto 0);
              r_fault_data(27) <= i_tm_comparison_mismatch;
              r_fault_data(26) <= i_NI_CORRUPT_PACKET;
              r_fault_data(25) <= i_OBS_TM_TMR_CTRL_ERROR;
              r_fault_data(24) <= i_OBS_TM_HAM_BUFFER_SINGLE_ERR;
              r_fault_data(23) <= i_OBS_TM_HAM_BUFFER_DOUBLE_ERR;
              r_fault_data(22) <= i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR;
              r_fault_data(21) <= i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR;
              r_fault_data(20) <= i_OBS_LB_TMR_CTRL_ERROR;
              r_fault_data(19) <= i_OBS_LB_HAM_BUFFER_SINGLE_ERR;
              r_fault_data(18) <= i_OBS_LB_HAM_BUFFER_DOUBLE_ERR;
              r_fault_data(17) <= i_OBS_TG_TMR_CTRL_ERROR;
              r_fault_data(16) <= i_OBS_TG_HAM_BUFFER_SINGLE_ERR;
              r_fault_data(15) <= i_OBS_TG_HAM_BUFFER_DOUBLE_ERR;
              r_fault_data(14) <= i_OBS_FE_INJ_META_HDR_SINGLE_ERR;
              r_fault_data(13) <= i_OBS_FE_INJ_META_HDR_DOUBLE_ERR;
              r_fault_data(12) <= i_OBS_FE_INJ_ADDR_SINGLE_ERR;
              r_fault_data(11) <= i_OBS_FE_INJ_ADDR_DOUBLE_ERR;
              r_fault_data(10) <= i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR;
              r_fault_data(9)  <= i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR;
              r_fault_data(8)  <= i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR;
              r_fault_data(7)  <= i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR;
              r_fault_data(6)  <= i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR;
              r_fault_data(5)  <= i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR;
              r_fault_data(4)  <= i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR;
              r_fault_data(3)  <= i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR;
              r_fault_data(2)  <= i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR;
              r_fault_data(1)  <= i_OBS_BE_RX_INTEGRITY_CORRUPT;
              r_fault_data(0)  <= i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR;

              r_pending_enc_line <= '0';
              r_enc_line_data    <= (others => '0');
              if (i_OBS_TM_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_TM_HAM_BUFFER_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"1";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_TM_HAM_BUFFER_ENC_DATA);
              elsif (i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR = '1') or (i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"2";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA);
              elsif (i_OBS_LB_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_LB_HAM_BUFFER_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"3";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_LB_HAM_BUFFER_ENC_DATA);
              elsif (i_OBS_TG_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_TG_HAM_BUFFER_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"4";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_TG_HAM_BUFFER_ENC_DATA);
              elsif (i_OBS_FE_INJ_META_HDR_SINGLE_ERR = '1') or (i_OBS_FE_INJ_META_HDR_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"5";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA);
              elsif (i_OBS_FE_INJ_ADDR_SINGLE_ERR = '1') or (i_OBS_FE_INJ_ADDR_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"6";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_FE_INJ_HAM_ADDR_ENC_DATA);
              elsif (i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"7";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA);
              elsif (i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR = '1') or (i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"8";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA);
              elsif (i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"9";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_BE_RX_HAM_BUFFER_ENC_DATA);
              elsif (i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"A";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA);
              elsif (i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR = '1') or (i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR = '1') then
                r_pending_enc_line <= '1';
                r_enc_line_data(83 downto 80) <= x"B";
                r_enc_line_data(79 downto 0)  <= f_pack80(i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA);
              end if;

              r_tx_phase    <= PH_BASE_TM_LABEL;
              r_label_index <= 1;
              r_tx_state    <= S_SEND_LABEL;
            end if;

          when S_SEND_LABEL =>
            if i_uart_tready = '1' then
              case r_tx_phase is
                when PH_BASE_TM_LABEL =>
                  r_uart_tdata <= f_char_to_slv8(C_LABEL_TM(r_label_index));
                when PH_BASE_FLAGS_LABEL =>
                  r_uart_tdata <= f_char_to_slv8(C_LABEL_FLAGS(r_label_index));
                when PH_ENC_LABEL =>
                  r_uart_tdata <= f_char_to_slv8(C_LABEL_ENC(r_label_index));
                when PH_ENC_DATA_LABEL =>
                  r_uart_tdata <= f_char_to_slv8(C_LABEL_DATA(r_label_index));
                when others =>
                  r_uart_tdata <= x"3F"; -- '?'
              end case;
              r_uart_tstart <= '1';
              r_wait_source <= WS_LABEL;
              r_tx_state    <= S_WAIT_DONE;
            end if;

          when S_SEND_HEX =>
            if i_uart_tready = '1' then
              r_uart_tdata  <= w_utf_data;
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
                        r_tx_phase    <= PH_BASE_FLAGS_LABEL;
                        r_label_index <= 1;
                        r_tx_state    <= S_SEND_LABEL;
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
                      r_fault_data       <= r_enc_line_data;
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
