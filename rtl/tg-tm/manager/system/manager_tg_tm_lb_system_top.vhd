library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

-- Flat hierarchy top (non-debug): TG + TM + single NI + loopback.
--
-- IMPORTANT (matches working tg_ni_write_only_top / tm_ni_read_only_top wrappers):
--   * ni_manager_top exposes NI->NoC request stream on ports named l_in_* (yes, *_i suffix!)
--   * ni_manager_top consumes NoC->NI response stream on ports named l_out_* (yes, *_o suffix!)
--
-- Wiring:
--   NI request  (ni_manager_top.l_in_*)  -> loopback.lin_*
--   NI response (ni_manager_top.l_out_*) <- loopback.lout_*
entity manager_tg_tm_lb_system_top is
  generic (
    p_MEM_ADDR_BITS : natural := 10;

    -- TG ECC/TMR enables (follows NI p_USE_* scheme)
    p_USE_TG_CTRL_TMR              : boolean := c_ENABLE_TG_CTRL_TMR;
    p_USE_TG_HAMMING               : boolean := c_ENABLE_TG_HAMMING_PROTECTION;
    p_USE_TG_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TG_HAMMING_DOUBLE_DETECT;
    p_USE_TG_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TG_HAMMING_INJECT_ERROR;

    -- TM ECC/TMR enables (follows NI p_USE_* scheme)
    p_USE_TM_CTRL_TMR              : boolean := c_ENABLE_TM_CTRL_TMR;
    p_USE_TM_HAMMING               : boolean := c_ENABLE_TM_HAMMING_PROTECTION;
    p_USE_TM_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TM_HAMMING_DOUBLE_DETECT;
    p_USE_TM_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TM_HAMMING_INJECT_ERROR;
    p_USE_TM_RECEIVED_COUNTER_HAMMING : boolean := c_ENABLE_TM_RECEIVED_COUNTER_HAMMING;
    p_USE_TM_CORRECT_COUNTER_HAMMING  : boolean := c_ENABLE_TM_CORRECT_COUNTER_HAMMING;
    p_TM_COUNTER_WIDTH                : natural := c_TM_COUNTER_WIDTH;

    -- LB ECC/TMR enables (follows NI p_USE_* scheme)
    p_USE_LB_CTRL_TMR              : boolean := c_ENABLE_LB_CTRL_TMR;
    p_USE_LB_HAMMING               : boolean := c_ENABLE_LB_HAMMING_PROTECTION;
    p_USE_LB_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_LB_HAMMING_DOUBLE_DETECT;
    p_USE_LB_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_LB_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    tg_start_i       : in  std_logic;
    tg_done_o        : out std_logic;
    TG_INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    TG_STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- TM control
    tm_start_i       : in  std_logic;
    tm_done_o        : out std_logic;
    TM_INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    TM_STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- TM observability
    tm_lfsr_comparison_mismatch_o : out std_logic;
    tm_expected_value_o : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    OBS_TM_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_TM_TMR_CTRL_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_TM_HAM_RECEIVED_COUNTER_CORRECT_ERROR_i : in std_logic := '1';
    OBS_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_i  : in std_logic := '1';
    OBS_TM_TMR_CTRL_ERROR_o           : out std_logic;
    OBS_TM_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
    OBS_TM_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_RECEIVED_COUNTER_SINGLE_ERR_o : out std_logic;
    OBS_TM_HAM_RECEIVED_COUNTER_DOUBLE_ERR_o : out std_logic;
    OBS_TM_HAM_RECEIVED_COUNTER_ENC_DATA_o   : out std_logic_vector(p_TM_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_o  : out std_logic;
    OBS_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_o  : out std_logic;
    OBS_TM_HAM_CORRECT_COUNTER_ENC_DATA_o    : out std_logic_vector(p_TM_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    TM_RECEIVED_COUNT_o                      : out std_logic_vector(p_TM_COUNTER_WIDTH - 1 downto 0);
    TM_CORRECT_COUNT_o                       : out std_logic_vector(p_TM_COUNTER_WIDTH - 1 downto 0);

    -- LB observability
    OBS_LB_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_LB_TMR_CTRL_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_LB_TMR_CTRL_ERROR_o           : out std_logic;
    OBS_LB_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
    OBS_LB_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
    OBS_LB_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    -- TG observability (same naming pattern as NI OBS ports)
    OBS_TG_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_TG_TMR_CTRL_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_TG_TMR_CTRL_ERROR_o           : out std_logic;
    OBS_TG_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
    OBS_TG_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
    OBS_TG_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    -- NI observability (forwarded from ni_manager_top)
    OBS_FE_INJ_META_HDR_SINGLE_ERR_o : out std_logic;
    OBS_FE_INJ_META_HDR_DOUBLE_ERR_o : out std_logic;
    OBS_FE_INJ_ADDR_SINGLE_ERR_o     : out std_logic;
    OBS_FE_INJ_ADDR_DOUBLE_ERR_o     : out std_logic;
    OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o : out std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_FE_INJ_HAM_ADDR_ENC_DATA_o     : out std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_FE_INJ_META_HDR_CORRECT_ERROR_i : in std_logic := '1';
    OBS_FE_INJ_ADDR_CORRECT_ERROR_i     : in std_logic := '1';

    OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i    : in std_logic := '1';
    OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o       : out std_logic;
    OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o       : out std_logic;
    OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o         : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in std_logic := '1';
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in std_logic := '1';
    OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic;
    OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in std_logic := '1';
    OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o         : out std_logic;
    OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in std_logic := '1';
    OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o         : out std_logic;

    OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i     : in std_logic := '1';
    OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o        : out std_logic;
    OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o        : out std_logic;
    OBS_BE_RX_HAM_BUFFER_ENC_DATA_o          : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i     : in std_logic := '1';
    OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_o             : out std_logic;
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in std_logic := '1';
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i : in std_logic := '1';
    OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    : out std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    : out std_logic;
    OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_INTEGRITY_CORRUPT_o            : out std_logic;
    OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i  : in std_logic := '1';
    OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o     : out std_logic;
    OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o     : out std_logic;
    OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o       : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i  : in std_logic := '1';
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o          : out std_logic;

    NI_CORRUPT_PACKET_o : out std_logic
  );
end entity;

architecture rtl of manager_tg_tm_lb_system_top is

  -- AXI write (TG)
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal awlen   : std_logic_vector(7 downto 0);
  signal awburst : std_logic_vector(1 downto 0);
  signal awvalid : std_logic;
  signal awready : std_logic;

  signal wvalid  : std_logic;
  signal wready  : std_logic;
  signal wdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal wlast   : std_logic;

  signal bid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal bvalid : std_logic;
  signal bready : std_logic;

  -- AXI read (TM)
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen   : std_logic_vector(7 downto 0);
  signal arburst : std_logic_vector(1 downto 0);
  signal arvalid : std_logic;
  signal arready : std_logic;

  signal rvalid : std_logic;
  signal rready : std_logic;
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- NI <-> Loopback NoC signals
  signal lin_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic;

  signal lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lout_val  : std_logic;
  signal lout_ack  : std_logic;

  signal tg_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

begin

  -- TG
  u_traffic_gen_top: entity work.traffic_gen_top
    generic map(
      p_USE_TG_CTRL_TMR              => p_USE_TG_CTRL_TMR,
      p_USE_TG_HAMMING               => p_USE_TG_HAMMING,
      p_USE_TG_HAMMING_DOUBLE_DETECT => p_USE_TG_HAMMING_DOUBLE_DETECT,
      p_USE_TG_HAMMING_INJECT_ERROR  => p_USE_TG_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      start_i => tg_start_i,
      done_o  => tg_done_o,

      INPUT_ADDRESS => TG_INPUT_ADDRESS,
      STARTING_SEED => TG_STARTING_SEED,

      --ext_update_en_i => '0',
      --ext_data_in_i   => (others => '0'),

      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,
      AWVALID => awvalid,
      AWREADY => awready,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BID     => bid,
      BRESP   => bresp,
      BVALID  => bvalid,
      BREADY  => bready,

      OBS_TG_HAM_BUFFER_CORRECT_ERROR_i => OBS_TG_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_TG_TMR_CTRL_CORRECT_ERROR_i   => OBS_TG_TMR_CTRL_CORRECT_ERROR_i,

      OBS_TG_TMR_CTRL_ERROR_o        => OBS_TG_TMR_CTRL_ERROR_o,
      OBS_TG_HAM_BUFFER_SINGLE_ERR_o => OBS_TG_HAM_BUFFER_SINGLE_ERR_o,
      OBS_TG_HAM_BUFFER_DOUBLE_ERR_o => OBS_TG_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_TG_HAM_BUFFER_ENC_DATA_o   => OBS_TG_HAM_BUFFER_ENC_DATA_o

      --lfsr_value_o => tg_lfsr_value
    );

  -- TM
  u_traffic_mon_top: entity work.traffic_mon_top
    generic map(
      p_USE_TM_CTRL_TMR              => p_USE_TM_CTRL_TMR,
      p_USE_TM_HAMMING               => p_USE_TM_HAMMING,
      p_USE_TM_HAMMING_DOUBLE_DETECT => p_USE_TM_HAMMING_DOUBLE_DETECT,
      p_USE_TM_HAMMING_INJECT_ERROR  => p_USE_TM_HAMMING_INJECT_ERROR,
      p_USE_TM_RECEIVED_COUNTER_HAMMING => p_USE_TM_RECEIVED_COUNTER_HAMMING,
      p_USE_TM_CORRECT_COUNTER_HAMMING  => p_USE_TM_CORRECT_COUNTER_HAMMING,
      p_TM_COUNTER_WIDTH                => p_TM_COUNTER_WIDTH
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      start_i => tm_start_i,
      done_o  => tm_done_o,

      INPUT_ADDRESS => TM_INPUT_ADDRESS,
      STARTING_SEED => TM_STARTING_SEED,

      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,
      ARVALID => arvalid,
      ARREADY => arready,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      tm_lfsr_comparison_mismatch_o => tm_lfsr_comparison_mismatch_o,
      expected_value_o => tm_expected_value_o,

      OBS_TM_HAM_BUFFER_CORRECT_ERROR_i => OBS_TM_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_TM_TMR_CTRL_CORRECT_ERROR_i   => OBS_TM_TMR_CTRL_CORRECT_ERROR_i,
      OBS_TM_HAM_RECEIVED_COUNTER_CORRECT_ERROR_i => OBS_TM_HAM_RECEIVED_COUNTER_CORRECT_ERROR_i,
      OBS_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_i  => OBS_TM_HAM_CORRECT_COUNTER_CORRECT_ERROR_i,
      OBS_TM_TMR_CTRL_ERROR_o           => OBS_TM_TMR_CTRL_ERROR_o,
      OBS_TM_HAM_BUFFER_SINGLE_ERR_o    => OBS_TM_HAM_BUFFER_SINGLE_ERR_o,
      OBS_TM_HAM_BUFFER_DOUBLE_ERR_o    => OBS_TM_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_TM_HAM_BUFFER_ENC_DATA_o      => OBS_TM_HAM_BUFFER_ENC_DATA_o,
      OBS_TM_HAM_RECEIVED_COUNTER_SINGLE_ERR_o => OBS_TM_HAM_RECEIVED_COUNTER_SINGLE_ERR_o,
      OBS_TM_HAM_RECEIVED_COUNTER_DOUBLE_ERR_o => OBS_TM_HAM_RECEIVED_COUNTER_DOUBLE_ERR_o,
      OBS_TM_HAM_RECEIVED_COUNTER_ENC_DATA_o   => OBS_TM_HAM_RECEIVED_COUNTER_ENC_DATA_o,
      OBS_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_o  => OBS_TM_HAM_CORRECT_COUNTER_SINGLE_ERR_o,
      OBS_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_o  => OBS_TM_HAM_CORRECT_COUNTER_DOUBLE_ERR_o,
      OBS_TM_HAM_CORRECT_COUNTER_ENC_DATA_o    => OBS_TM_HAM_CORRECT_COUNTER_ENC_DATA_o,
      TM_RECEIVED_COUNT_o                      => TM_RECEIVED_COUNT_o,
      TM_CORRECT_COUNT_o                       => TM_CORRECT_COUNT_o
    );

  -- Single NI manager
  u_ni_manager_top: entity work.ni_manager_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write
      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BVALID  => bvalid,
      BREADY  => bready,
      BID     => bid,
      BRESP   => bresp,

      -- Read
      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      -- NoC-side ports (see header comment)
      -- NI -> NoC (request stream)
      l_in_data_i  => lin_data,
      l_in_val_i   => lin_val,
      l_in_ack_o   => lin_ack,

      -- NoC -> NI (response stream)
      l_out_data_o => lout_data,
      l_out_val_o  => lout_val,
      l_out_ack_i  => lout_ack,

      corrupt_packet => NI_CORRUPT_PACKET_o,

      -- Frontend observation ports
      OBS_FE_INJ_META_HDR_SINGLE_ERR_o => OBS_FE_INJ_META_HDR_SINGLE_ERR_o,
      OBS_FE_INJ_META_HDR_DOUBLE_ERR_o => OBS_FE_INJ_META_HDR_DOUBLE_ERR_o,
      OBS_FE_INJ_ADDR_SINGLE_ERR_o     => OBS_FE_INJ_ADDR_SINGLE_ERR_o,
      OBS_FE_INJ_ADDR_DOUBLE_ERR_o     => OBS_FE_INJ_ADDR_DOUBLE_ERR_o,
      OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o => OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o,
      OBS_FE_INJ_HAM_ADDR_ENC_DATA_o     => OBS_FE_INJ_HAM_ADDR_ENC_DATA_o,
      OBS_FE_INJ_META_HDR_CORRECT_ERROR_i => OBS_FE_INJ_META_HDR_CORRECT_ERROR_i,
      OBS_FE_INJ_ADDR_CORRECT_ERROR_i     => OBS_FE_INJ_ADDR_CORRECT_ERROR_i,

      -- Backend correction enables / observation ports
      OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i    => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o       => OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o,
      OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o       => OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o         => OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
      OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o,
      OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
      OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
      OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
      OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o      => OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o,
      OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
      OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o         => OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o,
      OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
      OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o,

      OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i     => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o        => OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o,
      OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o        => OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_BE_RX_HAM_BUFFER_ENC_DATA_o          => OBS_BE_RX_HAM_BUFFER_ENC_DATA_o,
      OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
      OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_o         => OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_o,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
      OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o,
      OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i,
      OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o,
      OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o,
      OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o      => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o,
      OBS_BE_RX_INTEGRITY_CORRUPT_o            => OBS_BE_RX_INTEGRITY_CORRUPT_o,
      OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i  => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
      OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o     => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o,
      OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o     => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
      OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o       => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o,
      OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i  => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
      OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o          => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o
    );

  -- HW loopback (non-debug)
  u_loopback_top: entity work.loopback_top
    generic map(
      p_MEM_ADDR_BITS              => p_MEM_ADDR_BITS,
      p_USE_LB_CTRL_TMR            => p_USE_LB_CTRL_TMR,
      p_USE_LB_HAMMING             => p_USE_LB_HAMMING,
      p_USE_LB_HAMMING_DOUBLE_DETECT => p_USE_LB_HAMMING_DOUBLE_DETECT,
      p_USE_LB_HAMMING_INJECT_ERROR  => p_USE_LB_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_data_i => lin_data,
      lin_val_i  => lin_val,
      lin_ack_o  => lin_ack,

      lout_data_o => lout_data,
      lout_val_o  => lout_val,
      lout_ack_i  => lout_ack,

      OBS_LB_HAM_BUFFER_CORRECT_ERROR_i => OBS_LB_HAM_BUFFER_CORRECT_ERROR_i,
      OBS_LB_TMR_CTRL_CORRECT_ERROR_i   => OBS_LB_TMR_CTRL_CORRECT_ERROR_i,
      OBS_LB_TMR_CTRL_ERROR_o           => OBS_LB_TMR_CTRL_ERROR_o,
      OBS_LB_HAM_BUFFER_SINGLE_ERR_o    => OBS_LB_HAM_BUFFER_SINGLE_ERR_o,
      OBS_LB_HAM_BUFFER_DOUBLE_ERR_o    => OBS_LB_HAM_BUFFER_DOUBLE_ERR_o,
      OBS_LB_HAM_BUFFER_ENC_DATA_o      => OBS_LB_HAM_BUFFER_ENC_DATA_o
    );

end architecture;
