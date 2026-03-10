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
  signal w_dp_fault_data  : std_logic_vector(83 downto 0);
  signal w_dp_nibble_index : unsigned(4 downto 0);
  signal w_dp_label_sel   : std_logic_vector(2 downto 0);
  signal w_dp_label_index : natural range 1 to 8;
  signal w_dp_hex_char    : std_logic_vector(7 downto 0);
  signal w_dp_label_char  : std_logic_vector(7 downto 0);
begin
  b_uart_encode_control: block
  begin
    u_uart_encode_ctrl: entity work.tg_tm_lb_selftest_uart_encode_ctrl
      generic map(
        G_REPORT_PERIOD_PACKETS => G_REPORT_PERIOD_PACKETS
      )
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        i_tm_done => i_tm_done,
        i_tm_comparison_mismatch => i_tm_comparison_mismatch,
        i_TM_TRANSACTION_COUNT => i_TM_TRANSACTION_COUNT,
        i_TM_EXPECTED_VALUE    => i_TM_EXPECTED_VALUE,
        i_NI_CORRUPT_PACKET    => i_NI_CORRUPT_PACKET,
        i_OBS_TM_TMR_CTRL_ERROR => i_OBS_TM_TMR_CTRL_ERROR,
        i_OBS_TM_HAM_BUFFER_SINGLE_ERR => i_OBS_TM_HAM_BUFFER_SINGLE_ERR,
        i_OBS_TM_HAM_BUFFER_DOUBLE_ERR => i_OBS_TM_HAM_BUFFER_DOUBLE_ERR,
        i_OBS_TM_HAM_BUFFER_ENC_DATA => i_OBS_TM_HAM_BUFFER_ENC_DATA,
        i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR => i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR,
        i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR => i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR,
        i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA => i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA,
        i_OBS_LB_TMR_CTRL_ERROR => i_OBS_LB_TMR_CTRL_ERROR,
        i_OBS_LB_HAM_BUFFER_SINGLE_ERR => i_OBS_LB_HAM_BUFFER_SINGLE_ERR,
        i_OBS_LB_HAM_BUFFER_DOUBLE_ERR => i_OBS_LB_HAM_BUFFER_DOUBLE_ERR,
        i_OBS_LB_HAM_BUFFER_ENC_DATA => i_OBS_LB_HAM_BUFFER_ENC_DATA,
        i_OBS_TG_TMR_CTRL_ERROR => i_OBS_TG_TMR_CTRL_ERROR,
        i_OBS_TG_HAM_BUFFER_SINGLE_ERR => i_OBS_TG_HAM_BUFFER_SINGLE_ERR,
        i_OBS_TG_HAM_BUFFER_DOUBLE_ERR => i_OBS_TG_HAM_BUFFER_DOUBLE_ERR,
        i_OBS_TG_HAM_BUFFER_ENC_DATA => i_OBS_TG_HAM_BUFFER_ENC_DATA,
        i_OBS_FE_INJ_META_HDR_SINGLE_ERR => i_OBS_FE_INJ_META_HDR_SINGLE_ERR,
        i_OBS_FE_INJ_META_HDR_DOUBLE_ERR => i_OBS_FE_INJ_META_HDR_DOUBLE_ERR,
        i_OBS_FE_INJ_ADDR_SINGLE_ERR => i_OBS_FE_INJ_ADDR_SINGLE_ERR,
        i_OBS_FE_INJ_ADDR_DOUBLE_ERR => i_OBS_FE_INJ_ADDR_DOUBLE_ERR,
        i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA => i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA,
        i_OBS_FE_INJ_HAM_ADDR_ENC_DATA => i_OBS_FE_INJ_HAM_ADDR_ENC_DATA,
        i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR => i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR,
        i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR => i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR,
        i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA => i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA,
        i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR => i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR,
        i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR => i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR,
        i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR => i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR,
        i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA => i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA,
        i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR => i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR,
        i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR => i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR,
        i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR => i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR,
        i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR => i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR,
        i_OBS_BE_RX_HAM_BUFFER_ENC_DATA => i_OBS_BE_RX_HAM_BUFFER_ENC_DATA,
        i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR => i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR,
        i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR => i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR,
        i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA => i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA,
        i_OBS_BE_RX_INTEGRITY_CORRUPT => i_OBS_BE_RX_INTEGRITY_CORRUPT,
        i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR => i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR,
        i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR => i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR,
        i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA => i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA,
        i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR => i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR,
        o_OBS_TM_HAM_BUFFER_CORRECT_ERROR => o_OBS_TM_HAM_BUFFER_CORRECT_ERROR,
        o_OBS_TM_TMR_CTRL_CORRECT_ERROR => o_OBS_TM_TMR_CTRL_CORRECT_ERROR,
        o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR => o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR,
        o_OBS_LB_HAM_BUFFER_CORRECT_ERROR => o_OBS_LB_HAM_BUFFER_CORRECT_ERROR,
        o_OBS_LB_TMR_CTRL_CORRECT_ERROR => o_OBS_LB_TMR_CTRL_CORRECT_ERROR,
        o_OBS_TG_HAM_BUFFER_CORRECT_ERROR => o_OBS_TG_HAM_BUFFER_CORRECT_ERROR,
        o_OBS_TG_TMR_CTRL_CORRECT_ERROR => o_OBS_TG_TMR_CTRL_CORRECT_ERROR,
        o_OBS_FE_INJ_META_HDR_CORRECT_ERROR => o_OBS_FE_INJ_META_HDR_CORRECT_ERROR,
        o_OBS_FE_INJ_ADDR_CORRECT_ERROR => o_OBS_FE_INJ_ADDR_CORRECT_ERROR,
        o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR => o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR,
        o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
        o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR => o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR,
        o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR => o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR,
        o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR => o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR,
        o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR => o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR,
        o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
        o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR => o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR,
        o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR => o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR,
        o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR => o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR,
        o_experiment_run_enable => o_experiment_run_enable,
        o_experiment_reset_pulse => o_experiment_reset_pulse,
        o_uart_baud_div => o_uart_baud_div,
        o_uart_parity   => o_uart_parity,
        o_uart_rtscts   => o_uart_rtscts,
        i_uart_tready => i_uart_tready,
        i_uart_tdone  => i_uart_tdone,
        o_uart_tstart => o_uart_tstart,
        o_uart_tdata  => o_uart_tdata,
        o_uart_rready => o_uart_rready,
        i_uart_rdone  => i_uart_rdone,
        i_uart_rdata  => i_uart_rdata,
        i_uart_rerr   => i_uart_rerr,
        i_dp_hex_char   => w_dp_hex_char,
        i_dp_label_char => w_dp_label_char,
        o_dp_fault_data => w_dp_fault_data,
        o_dp_nibble_index => w_dp_nibble_index,
        o_dp_label_sel  => w_dp_label_sel,
        o_dp_label_index => w_dp_label_index
      );
  end block;

  b_uart_encode_datapath: block
  begin
    u_uart_encode_dp: entity work.tg_tm_lb_selftest_uart_encode_dp
      port map(
        i_fault_data   => w_dp_fault_data,
        i_nibble_index => w_dp_nibble_index,
        i_label_sel    => w_dp_label_sel,
        i_label_index  => w_dp_label_index,
        o_hex_char     => w_dp_hex_char,
        o_label_char   => w_dp_label_char
      );
  end block;
end architecture;
