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
    ARESETn : in std_logic;
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_top is

  -- TG/TM control between observation block and DUT
  signal tg_start_w : std_logic;
  signal tg_done_w  : std_logic;
  signal tg_addr_w  : std_logic_vector(63 downto 0);
  signal tg_seed_w  : std_logic_vector(31 downto 0);

  signal tm_start_w : std_logic;
  signal tm_done_w  : std_logic;
  signal tm_addr_w  : std_logic_vector(63 downto 0);
  signal tm_seed_w  : std_logic_vector(31 downto 0);

  signal tm_comparison_mismatch_w : std_logic;

  -- OBS enable wires (obs block -> DUT)
  signal OBS_TM_HAM_BUFFER_CORRECT_ERROR_w : std_logic;
  signal OBS_TM_TMR_CTRL_CORRECT_ERROR_w   : std_logic;
  signal OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_w : std_logic;

  signal OBS_LB_HAM_BUFFER_CORRECT_ERROR_w : std_logic;
  signal OBS_LB_TMR_CTRL_CORRECT_ERROR_w   : std_logic;

  signal OBS_TG_HAM_BUFFER_CORRECT_ERROR_w : std_logic;
  signal OBS_TG_TMR_CTRL_CORRECT_ERROR_w   : std_logic;

  signal OBS_FE_INJ_META_HDR_CORRECT_ERROR_w : std_logic;
  signal OBS_FE_INJ_ADDR_CORRECT_ERROR_w     : std_logic;

  signal OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_w : std_logic;

  signal OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_w : std_logic;
  signal OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_w : std_logic;

  -- OBS output wires (DUT -> obs block)
  signal OBS_TM_TMR_CTRL_ERROR_w : std_logic;
  signal OBS_TM_HAM_BUFFER_SINGLE_ERR_w : std_logic;
  signal OBS_TM_HAM_BUFFER_DOUBLE_ERR_w : std_logic;
  signal OBS_TM_HAM_BUFFER_ENC_DATA_w : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_w : std_logic;
  signal OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_w : std_logic;
  signal OBS_TM_HAM_TXN_COUNTER_ENC_DATA_w : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal OBS_LB_TMR_CTRL_ERROR_w : std_logic;
  signal OBS_LB_HAM_BUFFER_SINGLE_ERR_w : std_logic;
  signal OBS_LB_HAM_BUFFER_DOUBLE_ERR_w : std_logic;
  signal OBS_LB_HAM_BUFFER_ENC_DATA_w : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, c_ENABLE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal OBS_TG_TMR_CTRL_ERROR_w : std_logic;
  signal OBS_TG_HAM_BUFFER_SINGLE_ERR_w : std_logic;
  signal OBS_TG_HAM_BUFFER_DOUBLE_ERR_w : std_logic;
  signal OBS_TG_HAM_BUFFER_ENC_DATA_w : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal OBS_FE_INJ_META_HDR_SINGLE_ERR_w : std_logic;
  signal OBS_FE_INJ_META_HDR_DOUBLE_ERR_w : std_logic;
  signal OBS_FE_INJ_ADDR_SINGLE_ERR_w : std_logic;
  signal OBS_FE_INJ_ADDR_DOUBLE_ERR_w : std_logic;
  signal OBS_FE_INJ_HAM_META_HDR_ENC_DATA_w : std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_FE_INJ_HAM_ADDR_ENC_DATA_w : std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_w : std_logic;
  signal OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_w : std_logic;
  signal OBS_BE_INJ_HAM_BUFFER_ENC_DATA_w : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_w : std_logic;
  signal OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_w : std_logic;
  signal OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_w : std_logic;
  signal OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_w : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_w : std_logic;
  signal OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_w : std_logic;

  signal OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_w : std_logic;
  signal OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_w : std_logic;
  signal OBS_BE_RX_HAM_BUFFER_ENC_DATA_w : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_w : std_logic;
  signal OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_w : std_logic;
  signal OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_w : std_logic;
  signal OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_w : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_BE_RX_INTEGRITY_CORRUPT_w : std_logic;
  signal OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_w : std_logic;
  signal OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_w : std_logic;
  signal OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_w : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal OBS_BE_RX_TMR_FLOW_CTRL_ERROR_w : std_logic;

  -- DUT outputs consumed by observation block
  signal tm_expected_value_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal tm_transaction_count_w : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
  signal ni_corrupt_packet_w : std_logic;

  -- UART local wires (UART is at top level)
  signal uart_baud_div_w : std_logic_vector(15 downto 0);
  signal uart_parity_w   : std_logic;
  signal uart_rtscts_w   : std_logic;
  signal uart_tready_w : std_logic;
  signal uart_tstart_w : std_logic;
  signal uart_tdata_w  : std_logic_vector(7 downto 0);
  signal uart_tdone_w  : std_logic;
  signal uart_rready_w : std_logic;
  signal uart_rdone_w  : std_logic;
  signal uart_rdata_w  : std_logic_vector(7 downto 0);
  signal uart_rerr_w   : std_logic;

begin

  u_top_uart: entity work.uart
    port map(
      baud_div_i => uart_baud_div_w,
      parity_i   => uart_parity_w,
      rtscts_i   => uart_rtscts_w,
      tready_o   => uart_tready_w,
      tstart_i   => uart_tstart_w,
      tdata_i    => uart_tdata_w,
      tdone_o    => uart_tdone_w,
      rready_i   => uart_rready_w,
      rdone_o    => uart_rdone_w,
      rdata_o    => uart_rdata_w,
      rerr_o     => uart_rerr_w,
      rstn_i     => ARESETn,
      clk_i      => ACLK,
      uart_rx_i  => uart_rx_i,
      uart_tx_o  => uart_tx_o,
      uart_cts_i => uart_cts_i,
      uart_rts_o => uart_rts_o
    );

  u_obs_block_controller: entity work.tg_tm_lb_selftest_observation_block
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,
      uart_baud_div_o => uart_baud_div_w,
      uart_parity_o   => uart_parity_w,
      uart_rtscts_o   => uart_rtscts_w,
      uart_tready_i => uart_tready_w,
      uart_tdone_i  => uart_tdone_w,
      uart_tstart_o => uart_tstart_w,
      uart_tdata_o  => uart_tdata_w,
      uart_rready_o => uart_rready_w,
      uart_rdone_i  => uart_rdone_w,
      uart_rdata_i  => uart_rdata_w,
      uart_rerr_i   => uart_rerr_w,

      tg_start_o => tg_start_w,
      tg_done_i  => tg_done_w,
      tg_addr_o  => tg_addr_w,
      tg_seed_o  => tg_seed_w,

      tm_start_o => tm_start_w,
      tm_done_i  => tm_done_w,
      tm_addr_o  => tm_addr_w,
      tm_seed_o  => tm_seed_w,

      tm_comparison_mismatch_i => tm_comparison_mismatch_w,
      TM_TRANSACTION_COUNT_i => tm_transaction_count_w,
      TM_EXPECTED_VALUE_i    => tm_expected_value_w,
      NI_CORRUPT_PACKET_i    => ni_corrupt_packet_w,

      OBS_TM_HAM_BUFFER_CORRECT_ERROR_o => OBS_TM_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_TM_TMR_CTRL_CORRECT_ERROR_o   => OBS_TM_TMR_CTRL_CORRECT_ERROR_w,
      OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_o => OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_w,

      OBS_LB_HAM_BUFFER_CORRECT_ERROR_o => OBS_LB_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_LB_TMR_CTRL_CORRECT_ERROR_o   => OBS_LB_TMR_CTRL_CORRECT_ERROR_w,

      OBS_TG_HAM_BUFFER_CORRECT_ERROR_o => OBS_TG_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_TG_TMR_CTRL_CORRECT_ERROR_o   => OBS_TG_TMR_CTRL_CORRECT_ERROR_w,

      OBS_FE_INJ_META_HDR_CORRECT_ERROR_o => OBS_FE_INJ_META_HDR_CORRECT_ERROR_w,
      OBS_FE_INJ_ADDR_CORRECT_ERROR_o     => OBS_FE_INJ_ADDR_CORRECT_ERROR_w,

      OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_o => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_w,
      OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_w,
      OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_w,
      OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_o => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_w,

      OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_o => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_w,
      OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_o => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_w,
      OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_o => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_w,

      OBS_TM_TMR_CTRL_ERROR_i => OBS_TM_TMR_CTRL_ERROR_w,
      OBS_TM_HAM_BUFFER_SINGLE_ERR_i => OBS_TM_HAM_BUFFER_SINGLE_ERR_w,
      OBS_TM_HAM_BUFFER_DOUBLE_ERR_i => OBS_TM_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_TM_HAM_BUFFER_ENC_DATA_i => OBS_TM_HAM_BUFFER_ENC_DATA_w,
      OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_i => OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_w,
      OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_i => OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_w,
      OBS_TM_HAM_TXN_COUNTER_ENC_DATA_i => OBS_TM_HAM_TXN_COUNTER_ENC_DATA_w,

      OBS_LB_TMR_CTRL_ERROR_i => OBS_LB_TMR_CTRL_ERROR_w,
      OBS_LB_HAM_BUFFER_SINGLE_ERR_i => OBS_LB_HAM_BUFFER_SINGLE_ERR_w,
      OBS_LB_HAM_BUFFER_DOUBLE_ERR_i => OBS_LB_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_LB_HAM_BUFFER_ENC_DATA_i => OBS_LB_HAM_BUFFER_ENC_DATA_w,

      OBS_TG_TMR_CTRL_ERROR_i => OBS_TG_TMR_CTRL_ERROR_w,
      OBS_TG_HAM_BUFFER_SINGLE_ERR_i => OBS_TG_HAM_BUFFER_SINGLE_ERR_w,
      OBS_TG_HAM_BUFFER_DOUBLE_ERR_i => OBS_TG_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_TG_HAM_BUFFER_ENC_DATA_i => OBS_TG_HAM_BUFFER_ENC_DATA_w,

      OBS_FE_INJ_META_HDR_SINGLE_ERR_i => OBS_FE_INJ_META_HDR_SINGLE_ERR_w,
      OBS_FE_INJ_META_HDR_DOUBLE_ERR_i => OBS_FE_INJ_META_HDR_DOUBLE_ERR_w,
      OBS_FE_INJ_ADDR_SINGLE_ERR_i => OBS_FE_INJ_ADDR_SINGLE_ERR_w,
      OBS_FE_INJ_ADDR_DOUBLE_ERR_i => OBS_FE_INJ_ADDR_DOUBLE_ERR_w,
      OBS_FE_INJ_HAM_META_HDR_ENC_DATA_i => OBS_FE_INJ_HAM_META_HDR_ENC_DATA_w,
      OBS_FE_INJ_HAM_ADDR_ENC_DATA_i => OBS_FE_INJ_HAM_ADDR_ENC_DATA_w,

      OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_i => OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_w,
      OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_i => OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_BE_INJ_HAM_BUFFER_ENC_DATA_i => OBS_BE_INJ_HAM_BUFFER_ENC_DATA_w,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_i => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_w,
      OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_i => OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_w,
      OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_i => OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_w,
      OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_i => OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_w,
      OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_i => OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_w,
      OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_i => OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_w,

      OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_i => OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_w,
      OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_i => OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_BE_RX_HAM_BUFFER_ENC_DATA_i => OBS_BE_RX_HAM_BUFFER_ENC_DATA_w,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_i => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_i => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_i => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_i => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_w,
      OBS_BE_RX_INTEGRITY_CORRUPT_i => OBS_BE_RX_INTEGRITY_CORRUPT_w,
      OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_i => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_w,
      OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_i => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_w,
      OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_i => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_w,
      OBS_BE_RX_TMR_FLOW_CTRL_ERROR_i => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_w
    );

  u_tg_tm_lb_system_dut: entity work.tg_tm_lb_top
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      tg_start_i       => tg_start_w,
      tg_done_o        => tg_done_w,
      TG_INPUT_ADDRESS => tg_addr_w,
      TG_STARTING_SEED => tg_seed_w,

      tm_start_i       => tm_start_w,
      tm_done_o        => tm_done_w,
      TM_INPUT_ADDRESS => tm_addr_w,
      TM_STARTING_SEED => tm_seed_w,

      tm_lfsr_comparison_mismatch_o => tm_comparison_mismatch_w,
      tm_expected_value_o => tm_expected_value_w,
      OBS_TM_HAM_BUFFER_CORRECT_ERROR_i => OBS_TM_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_TM_TMR_CTRL_CORRECT_ERROR_i   => OBS_TM_TMR_CTRL_CORRECT_ERROR_w,
      OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_i => OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_w,
      OBS_TM_TMR_CTRL_ERROR_o           => OBS_TM_TMR_CTRL_ERROR_w,
      OBS_TM_HAM_BUFFER_SINGLE_ERR_o    => OBS_TM_HAM_BUFFER_SINGLE_ERR_w,
      OBS_TM_HAM_BUFFER_DOUBLE_ERR_o    => OBS_TM_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_TM_HAM_BUFFER_ENC_DATA_o      => OBS_TM_HAM_BUFFER_ENC_DATA_w,
      OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_o => OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_w,
      OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_o => OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_w,
      OBS_TM_HAM_TXN_COUNTER_ENC_DATA_o   => OBS_TM_HAM_TXN_COUNTER_ENC_DATA_w,
      TM_TRANSACTION_COUNT_o              => tm_transaction_count_w,

      OBS_LB_HAM_BUFFER_CORRECT_ERROR_i => OBS_LB_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_LB_TMR_CTRL_CORRECT_ERROR_i   => OBS_LB_TMR_CTRL_CORRECT_ERROR_w,
      OBS_LB_TMR_CTRL_ERROR_o           => OBS_LB_TMR_CTRL_ERROR_w,
      OBS_LB_HAM_BUFFER_SINGLE_ERR_o    => OBS_LB_HAM_BUFFER_SINGLE_ERR_w,
      OBS_LB_HAM_BUFFER_DOUBLE_ERR_o    => OBS_LB_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_LB_HAM_BUFFER_ENC_DATA_o      => OBS_LB_HAM_BUFFER_ENC_DATA_w,

      OBS_TG_HAM_BUFFER_CORRECT_ERROR_i => OBS_TG_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_TG_TMR_CTRL_CORRECT_ERROR_i   => OBS_TG_TMR_CTRL_CORRECT_ERROR_w,
      OBS_TG_TMR_CTRL_ERROR_o           => OBS_TG_TMR_CTRL_ERROR_w,
      OBS_TG_HAM_BUFFER_SINGLE_ERR_o    => OBS_TG_HAM_BUFFER_SINGLE_ERR_w,
      OBS_TG_HAM_BUFFER_DOUBLE_ERR_o    => OBS_TG_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_TG_HAM_BUFFER_ENC_DATA_o      => OBS_TG_HAM_BUFFER_ENC_DATA_w,

      OBS_FE_INJ_META_HDR_SINGLE_ERR_o => OBS_FE_INJ_META_HDR_SINGLE_ERR_w,
      OBS_FE_INJ_META_HDR_DOUBLE_ERR_o => OBS_FE_INJ_META_HDR_DOUBLE_ERR_w,
      OBS_FE_INJ_ADDR_SINGLE_ERR_o     => OBS_FE_INJ_ADDR_SINGLE_ERR_w,
      OBS_FE_INJ_ADDR_DOUBLE_ERR_o     => OBS_FE_INJ_ADDR_DOUBLE_ERR_w,
      OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o => OBS_FE_INJ_HAM_META_HDR_ENC_DATA_w,
      OBS_FE_INJ_HAM_ADDR_ENC_DATA_o     => OBS_FE_INJ_HAM_ADDR_ENC_DATA_w,
      OBS_FE_INJ_META_HDR_CORRECT_ERROR_i => OBS_FE_INJ_META_HDR_CORRECT_ERROR_w,
      OBS_FE_INJ_ADDR_CORRECT_ERROR_i     => OBS_FE_INJ_ADDR_CORRECT_ERROR_w,

      OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i    => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o       => OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_w,
      OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o       => OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o         => OBS_BE_INJ_HAM_BUFFER_ENC_DATA_w,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_w,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_w,
      OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_w,
      OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_w,
      OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_w,
      OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o      => OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_w,
      OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_w,
      OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o         => OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_w,
      OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_w,
      OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_w,

      OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i     => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_w,
      OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o        => OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_w,
      OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o        => OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_w,
      OBS_BE_RX_HAM_BUFFER_ENC_DATA_o          => OBS_BE_RX_HAM_BUFFER_ENC_DATA_w,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_w,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_w,
      OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o      => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_w,
      OBS_BE_RX_INTEGRITY_CORRUPT_o            => OBS_BE_RX_INTEGRITY_CORRUPT_w,
      OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i  => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_w,
      OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o     => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_w,
      OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o     => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_w,
      OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o       => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_w,
      OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i  => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_w,
      OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o          => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_w,

      NI_CORRUPT_PACKET_o => ni_corrupt_packet_w
    );

end architecture;
