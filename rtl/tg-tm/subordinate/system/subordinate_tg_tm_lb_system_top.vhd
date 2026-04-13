library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- Subordinate-side system test top:
--   NoC request TG -> subordinate NI -> AXI-compatible loopback slave -> subordinate NI -> NoC response TM
entity subordinate_tg_tm_lb_system_top is
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    start_i   : in std_logic;
    is_read_i : in std_logic;
    id_i      : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    address_i : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    seed_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    done_o     : out std_logic;
    mismatch_o : out std_logic;
    corrupt_packet_o : out std_logic;

    OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_SUB_TG_LFSR_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + 1 + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH + 1, c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o      : out std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_SUB_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    TM_TRANSACTION_COUNT_o                 : out std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o      : out std_logic := '0';
    OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o      : out std_logic := '0';
    OBS_SUB_LB_HAM_RDATA_ENC_DATA_o        : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o      : out std_logic_vector((3 * c_AXI_ID_WIDTH) + work.hamming_pkg.get_ecc_size(3 * c_AXI_ID_WIDTH, c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');

    OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_FE_INJ_TMR_STATUS_ERROR_o         : out std_logic := '0';

    OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
    OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
    OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o         : out std_logic := '0';

    OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
    OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
    OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         : out std_logic := '0'
  );
end entity;

architecture rtl of subordinate_tg_tm_lb_system_top is
  -- NoC request stream into subordinate NI.
  signal req_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal req_val  : std_logic;
  signal req_ack  : std_logic;

  -- NoC response stream out of subordinate NI.
  signal resp_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal resp_val  : std_logic;
  signal resp_ack  : std_logic;

  -- AXI master interface driven by subordinate NI into local loopback slave.
  signal awvalid : std_logic;
  signal awready : std_logic;
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal awlen   : std_logic_vector(7 downto 0);
  signal awsize  : std_logic_vector(2 downto 0);
  signal awburst : std_logic_vector(1 downto 0);

  signal wvalid : std_logic;
  signal wready : std_logic;
  signal wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal wlast  : std_logic;

  signal bvalid : std_logic;
  signal bready : std_logic;
  signal bid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal arvalid : std_logic;
  signal arready : std_logic;
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen   : std_logic_vector(7 downto 0);
  signal arsize  : std_logic_vector(2 downto 0);
  signal arburst : std_logic_vector(1 downto 0);

  signal rvalid : std_logic;
  signal rready : std_logic;
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal noc_tg_done : std_logic;
  signal noc_tm_done : std_logic;
  signal noc_tg_done_seen_r : std_logic := '0';
  signal noc_tm_done_seen_r : std_logic := '0';

begin
  u_subordinate_noc_traffic_gen_top: entity work.subordinate_noc_traffic_gen_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      id_i => id_i,
      address_i => address_i,
      seed_i => seed_i,
      done_o => noc_tg_done,
      l_out_data_o => req_data,
      l_out_val_o  => req_val,
      l_out_ack_i  => req_ack,
      OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i => OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i,
      OBS_SUB_TG_TMR_CTRL_ERROR_o         => OBS_SUB_TG_TMR_CTRL_ERROR_o,
      OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i => OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i,
      OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o    => OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o,
      OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o    => OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o,
      OBS_SUB_TG_HAM_LFSR_ENC_DATA_o      => OBS_SUB_TG_HAM_LFSR_ENC_DATA_o
    );

  u_ni_subordinate_top: entity work.ni_subordinate_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWSIZE  => awsize,
      AWBURST => awburst,

      WVALID => wvalid,
      WREADY => wready,
      WDATA  => wdata,
      WLAST  => wlast,

      BVALID => bvalid,
      BREADY => bready,
      BID    => bid,
      BRESP  => bresp,

      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARSIZE  => arsize,
      ARBURST => arburst,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      CORRUPT_PACKET => corrupt_packet_o,

      OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_i => OBS_SUB_FE_INJ_TMR_STATUS_CORRECT_ERROR_i,
      OBS_SUB_FE_INJ_TMR_STATUS_ERROR_o         => OBS_SUB_FE_INJ_TMR_STATUS_ERROR_o,
      OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i => OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o    => OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o,
      OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o    => OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o      => open,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
      OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o,
      OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
      OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
      OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
      OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o      => open,
      OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
      OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
      OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o,
      OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i => OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o    => OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o,
      OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o      => open,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
      OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o,
      OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i => OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i,
      OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o    => OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o,
      OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o,
      OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o      => OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o,
      OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i => OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i,
      OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o    => OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o,
      OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o,
      OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o      => OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o,
      OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i => OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i,
      OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o    => OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o,
      OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o,
      OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o      => OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o,
      OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
      OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o,
      OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
      OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o      => open,
      OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
      OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         => OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
      OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         => OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o,

      l_in_data_i  => resp_data,
      l_in_val_i   => resp_val,
      l_in_ack_o   => resp_ack,
      l_out_data_o => req_data,
      l_out_val_o  => req_val,
      l_out_ack_i  => req_ack
    );

  u_subordinate_axi_loopback: entity work.subordinate_axi_loopback
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWSIZE  => awsize,
      AWBURST => awburst,

      WVALID => wvalid,
      WREADY => wready,
      WDATA  => wdata,
      WLAST  => wlast,

      BVALID => bvalid,
      BREADY => bready,
      BID    => bid,
      BRESP  => bresp,

      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARSIZE  => arsize,
      ARBURST => arburst,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,
      OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_i => OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_i,
      OBS_SUB_LB_TMR_CTRL_ERROR_o         => OBS_SUB_LB_TMR_CTRL_ERROR_o,
      OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i => OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i,
      OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o    => OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o,
      OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o    => OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o,
      OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o      => OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o,
      OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i   => OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i,
      OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o      => OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o,
      OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o      => OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o,
      OBS_SUB_LB_HAM_RDATA_ENC_DATA_o        => OBS_SUB_LB_HAM_RDATA_ENC_DATA_o,
      OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i => OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i,
      OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o    => OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o,
      OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o    => OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o,
      OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o      => OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o
    );

  u_subordinate_noc_traffic_mon_top: entity work.subordinate_noc_traffic_mon_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      expected_id_i => id_i,
      seed_i => seed_i,
      done_o => noc_tm_done,
      mismatch_o => mismatch_o,
      l_in_data_i => resp_data,
      l_in_val_i  => resp_val,
      l_in_ack_o  => resp_ack,
      OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i => OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i,
      OBS_SUB_TM_TMR_CTRL_ERROR_o         => OBS_SUB_TM_TMR_CTRL_ERROR_o,
      OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i => OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i,
      OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    => OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o,
      OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    => OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o,
      OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      => OBS_SUB_TM_HAM_LFSR_ENC_DATA_o,
      OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i => OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i,
      OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o    => OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o,
      OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o    => OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o,
      OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o      => OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o,
      TM_TRANSACTION_COUNT_o                 => TM_TRANSACTION_COUNT_o
    );

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        noc_tg_done_seen_r <= '0';
        noc_tm_done_seen_r <= '0';
      elsif start_i = '1' then
        noc_tg_done_seen_r <= '0';
        noc_tm_done_seen_r <= '0';
      else
        if noc_tg_done = '1' then
          noc_tg_done_seen_r <= '1';
        end if;
        if noc_tm_done = '1' then
          noc_tm_done_seen_r <= '1';
        end if;
      end if;
    end if;
  end process;

  done_o <= noc_tg_done_seen_r and noc_tm_done_seen_r;

end architecture;
