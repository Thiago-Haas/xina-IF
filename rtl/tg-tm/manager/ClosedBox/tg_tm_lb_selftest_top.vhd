library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- Closed-box self-test top:
--   Inputs: ACLK, ARESETn
--   Internally instantiates TG+TM+NI+loopback (tg_tm_lb_top)
--   and an observation block that is split into control/datapath.
entity tg_tm_lb_selftest_top is
  port (
    ACLK    : in std_logic;
    ARESETn : in std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_top is

  -- TG/TM control between observation block and DUT
  signal w_tg_start : std_logic;
  signal w_tg_done  : std_logic;
  signal w_tg_addr  : std_logic_vector(63 downto 0);
  signal w_tg_seed  : std_logic_vector(31 downto 0);

  signal w_tm_start : std_logic;
  signal w_tm_done  : std_logic;
  signal w_tm_addr  : std_logic_vector(63 downto 0);
  signal w_tm_seed  : std_logic_vector(31 downto 0);

  signal w_tm_lfsr_comparison_mismatch : std_logic;

  -- OBS enable wires (obs block -> DUT)
  signal w_OBS_TM_HAM_BUFFER_CORRECT_ERROR : std_logic;
  signal w_OBS_TM_TMR_CTRL_CORRECT_ERROR   : std_logic;
  signal w_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR : std_logic;

  signal w_OBS_LB_HAM_BUFFER_CORRECT_ERROR : std_logic;
  signal w_OBS_LB_TMR_CTRL_CORRECT_ERROR   : std_logic;

  signal w_OBS_TG_HAM_BUFFER_CORRECT_ERROR : std_logic;
  signal w_OBS_TG_TMR_CTRL_CORRECT_ERROR   : std_logic;

  signal w_OBS_FE_INJ_META_HDR_CORRECT_ERROR : std_logic;
  signal w_OBS_FE_INJ_ADDR_CORRECT_ERROR     : std_logic;

  signal w_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR : std_logic;

  signal w_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR : std_logic;
  signal w_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR : std_logic;

  -- OBS output wires (DUT -> obs block)
  signal w_OBS_TM_TMR_CTRL_ERROR : std_logic;
  signal w_OBS_TM_HAM_BUFFER_SINGLE_ERR : std_logic;
  signal w_OBS_TM_HAM_BUFFER_DOUBLE_ERR : std_logic;
  signal w_OBS_TM_HAM_BUFFER_ENC_DATA : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR : std_logic;
  signal w_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR : std_logic;
  signal w_OBS_TM_HAM_TXN_COUNTER_ENC_DATA : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal w_OBS_LB_TMR_CTRL_ERROR : std_logic;
  signal w_OBS_LB_HAM_BUFFER_SINGLE_ERR : std_logic;
  signal w_OBS_LB_HAM_BUFFER_DOUBLE_ERR : std_logic;
  signal w_OBS_LB_HAM_BUFFER_ENC_DATA : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, c_ENABLE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal w_OBS_TG_TMR_CTRL_ERROR : std_logic;
  signal w_OBS_TG_HAM_BUFFER_SINGLE_ERR : std_logic;
  signal w_OBS_TG_HAM_BUFFER_DOUBLE_ERR : std_logic;
  signal w_OBS_TG_HAM_BUFFER_ENC_DATA : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal w_OBS_FE_INJ_META_HDR_SINGLE_ERR : std_logic;
  signal w_OBS_FE_INJ_META_HDR_DOUBLE_ERR : std_logic;
  signal w_OBS_FE_INJ_ADDR_SINGLE_ERR : std_logic;
  signal w_OBS_FE_INJ_ADDR_DOUBLE_ERR : std_logic;
  signal w_OBS_FE_INJ_HAM_META_HDR_ENC_DATA : std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_FE_INJ_HAM_ADDR_ENC_DATA : std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal w_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR : std_logic;
  signal w_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR : std_logic;
  signal w_OBS_BE_INJ_HAM_BUFFER_ENC_DATA : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR : std_logic;
  signal w_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR : std_logic;
  signal w_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR : std_logic;
  signal w_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR : std_logic;
  signal w_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR : std_logic;

  signal w_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR : std_logic;
  signal w_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR : std_logic;
  signal w_OBS_BE_RX_HAM_BUFFER_ENC_DATA : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR : std_logic;
  signal w_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR : std_logic;
  signal w_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR : std_logic;
  signal w_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_BE_RX_INTEGRITY_CORRUPT : std_logic;
  signal w_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR : std_logic;
  signal w_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR : std_logic;
  signal w_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_OBS_BE_RX_TMR_FLOW_CTRL_ERROR : std_logic;

  -- DUT outputs consumed by observation block
  signal w_tm_expected_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_tm_transaction_count : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
  signal w_ni_corrupt_packet : std_logic;

  -- self-test status (kept internal)
  signal w_selftest_error : std_logic;

  -- UART local wires (UART is at top level)
  signal w_uart_tready : std_logic;
  signal w_uart_tdone  : std_logic;
  signal w_uart_rdone  : std_logic;
  signal w_uart_rdata  : std_logic_vector(7 downto 0);
  signal w_uart_rerr   : std_logic;
  signal w_uart_tx     : std_logic;
  signal w_uart_rts    : std_logic;

begin

  u_top_uart: entity work.uart
    port map(
      baud_div_i => x"0001",
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => w_uart_tready,
      tstart_i   => '0',
      tdata_i    => (others => '0'),
      tdone_o    => w_uart_tdone,
      rready_i   => '1',
      rdone_o    => w_uart_rdone,
      rdata_o    => w_uart_rdata,
      rerr_o     => w_uart_rerr,
      rstn_i     => ARESETn,
      clk_i      => ACLK,
      uart_rx_i  => '1',
      uart_tx_o  => w_uart_tx,
      uart_cts_i => '0',
      uart_rts_o => w_uart_rts
    );

  u_obs_block_controller: entity work.tg_tm_lb_selftest_observation_block
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      o_tg_start => w_tg_start,
      i_tg_done  => w_tg_done,
      o_tg_addr  => w_tg_addr,
      o_tg_seed  => w_tg_seed,

      o_tm_start => w_tm_start,
      i_tm_done  => w_tm_done,
      o_tm_addr  => w_tm_addr,
      o_tm_seed  => w_tm_seed,

      i_tm_lfsr_comparison_mismatch => w_tm_lfsr_comparison_mismatch,
      i_TM_TRANSACTION_COUNT => w_tm_transaction_count,
      i_TM_EXPECTED_VALUE    => w_tm_expected_value,
      i_NI_CORRUPT_PACKET    => w_ni_corrupt_packet,

      o_OBS_TM_HAM_BUFFER_CORRECT_ERROR => w_OBS_TM_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_TM_TMR_CTRL_CORRECT_ERROR   => w_OBS_TM_TMR_CTRL_CORRECT_ERROR,
      o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR => w_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR,

      o_OBS_LB_HAM_BUFFER_CORRECT_ERROR => w_OBS_LB_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_LB_TMR_CTRL_CORRECT_ERROR   => w_OBS_LB_TMR_CTRL_CORRECT_ERROR,

      o_OBS_TG_HAM_BUFFER_CORRECT_ERROR => w_OBS_TG_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_TG_TMR_CTRL_CORRECT_ERROR   => w_OBS_TG_TMR_CTRL_CORRECT_ERROR,

      o_OBS_FE_INJ_META_HDR_CORRECT_ERROR => w_OBS_FE_INJ_META_HDR_CORRECT_ERROR,
      o_OBS_FE_INJ_ADDR_CORRECT_ERROR     => w_OBS_FE_INJ_ADDR_CORRECT_ERROR,

      o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR => w_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => w_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
      o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR => w_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR,
      o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR => w_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR,
      o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR => w_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR,

      o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR => w_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => w_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR => w_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR,
      o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR => w_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR,
      o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR => w_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR,

      i_OBS_TM_TMR_CTRL_ERROR => w_OBS_TM_TMR_CTRL_ERROR,
      i_OBS_TM_HAM_BUFFER_SINGLE_ERR => w_OBS_TM_HAM_BUFFER_SINGLE_ERR,
      i_OBS_TM_HAM_BUFFER_DOUBLE_ERR => w_OBS_TM_HAM_BUFFER_DOUBLE_ERR,
      i_OBS_TM_HAM_BUFFER_ENC_DATA => w_OBS_TM_HAM_BUFFER_ENC_DATA,
      i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR => w_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR,
      i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR => w_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR,
      i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA => w_OBS_TM_HAM_TXN_COUNTER_ENC_DATA,

      i_OBS_LB_TMR_CTRL_ERROR => w_OBS_LB_TMR_CTRL_ERROR,
      i_OBS_LB_HAM_BUFFER_SINGLE_ERR => w_OBS_LB_HAM_BUFFER_SINGLE_ERR,
      i_OBS_LB_HAM_BUFFER_DOUBLE_ERR => w_OBS_LB_HAM_BUFFER_DOUBLE_ERR,
      i_OBS_LB_HAM_BUFFER_ENC_DATA => w_OBS_LB_HAM_BUFFER_ENC_DATA,

      i_OBS_TG_TMR_CTRL_ERROR => w_OBS_TG_TMR_CTRL_ERROR,
      i_OBS_TG_HAM_BUFFER_SINGLE_ERR => w_OBS_TG_HAM_BUFFER_SINGLE_ERR,
      i_OBS_TG_HAM_BUFFER_DOUBLE_ERR => w_OBS_TG_HAM_BUFFER_DOUBLE_ERR,
      i_OBS_TG_HAM_BUFFER_ENC_DATA => w_OBS_TG_HAM_BUFFER_ENC_DATA,

      i_OBS_FE_INJ_META_HDR_SINGLE_ERR => w_OBS_FE_INJ_META_HDR_SINGLE_ERR,
      i_OBS_FE_INJ_META_HDR_DOUBLE_ERR => w_OBS_FE_INJ_META_HDR_DOUBLE_ERR,
      i_OBS_FE_INJ_ADDR_SINGLE_ERR => w_OBS_FE_INJ_ADDR_SINGLE_ERR,
      i_OBS_FE_INJ_ADDR_DOUBLE_ERR => w_OBS_FE_INJ_ADDR_DOUBLE_ERR,
      i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA => w_OBS_FE_INJ_HAM_META_HDR_ENC_DATA,
      i_OBS_FE_INJ_HAM_ADDR_ENC_DATA => w_OBS_FE_INJ_HAM_ADDR_ENC_DATA,

      i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR => w_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR,
      i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR => w_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR,
      i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA => w_OBS_BE_INJ_HAM_BUFFER_ENC_DATA,
      i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR => w_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR,
      i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR => w_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR,
      i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR => w_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR,
      i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA => w_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA,
      i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR => w_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR,
      i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR => w_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR,

      i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR => w_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR,
      i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR => w_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR,
      i_OBS_BE_RX_HAM_BUFFER_ENC_DATA => w_OBS_BE_RX_HAM_BUFFER_ENC_DATA,
      i_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR => w_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR,
      i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR => w_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR,
      i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR => w_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR,
      i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA => w_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA,
      i_OBS_BE_RX_INTEGRITY_CORRUPT => w_OBS_BE_RX_INTEGRITY_CORRUPT,
      i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR => w_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR,
      i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR => w_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR,
      i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA => w_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA,
      i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR => w_OBS_BE_RX_TMR_FLOW_CTRL_ERROR,

      o_error => w_selftest_error
    );

  u_tg_tm_lb_system_dut: entity work.tg_tm_lb_top
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start       => w_tg_start,
      o_tg_done        => w_tg_done,
      TG_INPUT_ADDRESS => w_tg_addr,
      TG_STARTING_SEED => w_tg_seed,

      i_tm_start       => w_tm_start,
      o_tm_done        => w_tm_done,
      TM_INPUT_ADDRESS => w_tm_addr,
      TM_STARTING_SEED => w_tm_seed,

      o_tm_lfsr_comparison_mismatch => w_tm_lfsr_comparison_mismatch,
      o_tm_expected_value => w_tm_expected_value,
      i_OBS_TM_HAM_BUFFER_CORRECT_ERROR => w_OBS_TM_HAM_BUFFER_CORRECT_ERROR,
      i_OBS_TM_TMR_CTRL_CORRECT_ERROR   => w_OBS_TM_TMR_CTRL_CORRECT_ERROR,
      i_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR => w_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR,
      o_OBS_TM_TMR_CTRL_ERROR           => w_OBS_TM_TMR_CTRL_ERROR,
      o_OBS_TM_HAM_BUFFER_SINGLE_ERR    => w_OBS_TM_HAM_BUFFER_SINGLE_ERR,
      o_OBS_TM_HAM_BUFFER_DOUBLE_ERR    => w_OBS_TM_HAM_BUFFER_DOUBLE_ERR,
      o_OBS_TM_HAM_BUFFER_ENC_DATA      => w_OBS_TM_HAM_BUFFER_ENC_DATA,
      o_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR => w_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR,
      o_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR => w_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR,
      o_OBS_TM_HAM_TXN_COUNTER_ENC_DATA   => w_OBS_TM_HAM_TXN_COUNTER_ENC_DATA,
      o_TM_TRANSACTION_COUNT              => w_tm_transaction_count,

      i_OBS_LB_HAM_BUFFER_CORRECT_ERROR => w_OBS_LB_HAM_BUFFER_CORRECT_ERROR,
      i_OBS_LB_TMR_CTRL_CORRECT_ERROR   => w_OBS_LB_TMR_CTRL_CORRECT_ERROR,
      o_OBS_LB_TMR_CTRL_ERROR           => w_OBS_LB_TMR_CTRL_ERROR,
      o_OBS_LB_HAM_BUFFER_SINGLE_ERR    => w_OBS_LB_HAM_BUFFER_SINGLE_ERR,
      o_OBS_LB_HAM_BUFFER_DOUBLE_ERR    => w_OBS_LB_HAM_BUFFER_DOUBLE_ERR,
      o_OBS_LB_HAM_BUFFER_ENC_DATA      => w_OBS_LB_HAM_BUFFER_ENC_DATA,

      i_OBS_TG_HAM_BUFFER_CORRECT_ERROR => w_OBS_TG_HAM_BUFFER_CORRECT_ERROR,
      i_OBS_TG_TMR_CTRL_CORRECT_ERROR   => w_OBS_TG_TMR_CTRL_CORRECT_ERROR,
      o_OBS_TG_TMR_CTRL_ERROR           => w_OBS_TG_TMR_CTRL_ERROR,
      o_OBS_TG_HAM_BUFFER_SINGLE_ERR    => w_OBS_TG_HAM_BUFFER_SINGLE_ERR,
      o_OBS_TG_HAM_BUFFER_DOUBLE_ERR    => w_OBS_TG_HAM_BUFFER_DOUBLE_ERR,
      o_OBS_TG_HAM_BUFFER_ENC_DATA      => w_OBS_TG_HAM_BUFFER_ENC_DATA,

      o_OBS_FE_INJ_META_HDR_SINGLE_ERR => w_OBS_FE_INJ_META_HDR_SINGLE_ERR,
      o_OBS_FE_INJ_META_HDR_DOUBLE_ERR => w_OBS_FE_INJ_META_HDR_DOUBLE_ERR,
      o_OBS_FE_INJ_ADDR_SINGLE_ERR     => w_OBS_FE_INJ_ADDR_SINGLE_ERR,
      o_OBS_FE_INJ_ADDR_DOUBLE_ERR     => w_OBS_FE_INJ_ADDR_DOUBLE_ERR,
      o_OBS_FE_INJ_HAM_META_HDR_ENC_DATA => w_OBS_FE_INJ_HAM_META_HDR_ENC_DATA,
      o_OBS_FE_INJ_HAM_ADDR_ENC_DATA     => w_OBS_FE_INJ_HAM_ADDR_ENC_DATA,
      i_OBS_FE_INJ_META_HDR_CORRECT_ERROR => w_OBS_FE_INJ_META_HDR_CORRECT_ERROR,
      i_OBS_FE_INJ_ADDR_CORRECT_ERROR     => w_OBS_FE_INJ_ADDR_CORRECT_ERROR,

      i_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR    => w_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR       => w_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR,
      o_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR       => w_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR,
      o_OBS_BE_INJ_HAM_BUFFER_ENC_DATA         => w_OBS_BE_INJ_HAM_BUFFER_ENC_DATA,
      i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => w_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
      o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR         => w_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR,
      i_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR => w_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR,
      o_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR    => w_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR,
      o_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR    => w_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR,
      o_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA      => w_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA,
      i_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR => w_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR,
      o_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR         => w_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR,
      i_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR => w_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR,
      o_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR         => w_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR,

      i_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR     => w_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR,
      o_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR        => w_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR,
      o_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR        => w_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR,
      o_OBS_BE_RX_HAM_BUFFER_ENC_DATA          => w_OBS_BE_RX_HAM_BUFFER_ENC_DATA,
      i_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => w_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
      o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR         => w_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR,
      i_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR => w_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR    => w_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR    => w_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR,
      o_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA      => w_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA,
      o_OBS_BE_RX_INTEGRITY_CORRUPT            => w_OBS_BE_RX_INTEGRITY_CORRUPT,
      i_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR  => w_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR,
      o_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR     => w_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR,
      o_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR     => w_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR,
      o_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA       => w_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA,
      i_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR  => w_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR,
      o_OBS_BE_RX_TMR_FLOW_CTRL_ERROR          => w_OBS_BE_RX_TMR_FLOW_CTRL_ERROR,

      o_NI_CORRUPT_PACKET => w_ni_corrupt_packet
    );

end architecture;
