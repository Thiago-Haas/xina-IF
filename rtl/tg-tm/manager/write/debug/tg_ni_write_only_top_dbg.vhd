library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- RTL top that connects only the TG write manager (tg_write_top_dbg)
-- to the NI manager (top_manager).
--
-- DEBUG VERSION:
--  * Exposes the AXI signals between TG and NI
--  * Exposes TG controller FSM and datapath taps
--  * Exposes NI CORRUPT_PACKET flag
--
-- The NoC-side ports are also exposed so a TB can emulate a loopback/subordinate.
entity tg_ni_write_only_top_dbg is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    i_start       : in  std_logic;
    o_done        : out std_logic;
    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- NoC-side (connect to TB / NoC)
    l_in_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_in_val_o  : out std_logic;
    l_in_ack_i  : in  std_logic;

    l_out_data_i: in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_out_val_i : in  std_logic;
    l_out_ack_o : out std_logic;

    -- ------------------------------------------------------------------
    -- Debug: AXI between TG and NI (master side)
    -- ------------------------------------------------------------------
    o_dbg_axi_awid    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_dbg_axi_awaddr  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    o_dbg_axi_awlen   : out std_logic_vector(7 downto 0);
    o_dbg_axi_awburst : out std_logic_vector(1 downto 0);
    o_dbg_axi_awvalid : out std_logic;
    o_dbg_axi_awready : out std_logic;

    o_dbg_axi_wvalid  : out std_logic;
    o_dbg_axi_wready  : out std_logic;
    o_dbg_axi_wdata   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_axi_wlast   : out std_logic;

    o_dbg_axi_bid     : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_dbg_axi_bresp   : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
    o_dbg_axi_bvalid  : out std_logic;
    o_dbg_axi_bready  : out std_logic;

    -- ------------------------------------------------------------------
    -- Debug: TG internal
    -- ------------------------------------------------------------------
    o_dbg_tg_state        : out std_logic_vector(1 downto 0);
    o_dbg_tg_aw_hs        : out std_logic;
    o_dbg_tg_w_hs         : out std_logic;
    o_dbg_tg_b_hs         : out std_logic;
    o_dbg_tg_bhs_seen     : out std_logic;
    o_dbg_tg_txn_start_pulse : out std_logic;
    o_dbg_tg_wbeat_pulse     : out std_logic;

    o_dbg_dp_seeded       : out std_logic;
    o_dbg_dp_do_init      : out std_logic;
    o_dbg_dp_do_step      : out std_logic;
    o_dbg_dp_init_value   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_feedback_val : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_lfsr_input   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_lfsr_next    : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_lfsr_in_reg  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_wdata_reg    : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- legacy debug
    o_dbg_tg_lfsr_value   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- ------------------------------------------------------------------
    -- Debug: NI
    -- ------------------------------------------------------------------
    o_dbg_corrupt_packet  : out std_logic
  );
end entity;

architecture rtl of tg_ni_write_only_top_dbg is
  -- AXI write interconnect
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

  -- unused read channels (tied off)
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal arlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal arburst : std_logic_vector(1 downto 0) := "01";

  signal rvalid : std_logic;
  signal rready : std_logic := '0';
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal corrupt_packet : std_logic;
  signal tg_lfsr_value  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  -- TG internal debug
  signal tg_state    : std_logic_vector(1 downto 0);
  signal tg_aw_hs    : std_logic;
  signal tg_w_hs     : std_logic;
  signal tg_b_hs     : std_logic;
  signal tg_bhs_seen : std_logic;
  signal tg_txn_start_pulse : std_logic;
  signal tg_wbeat_pulse     : std_logic;

  signal dp_seeded       : std_logic;
  signal dp_do_init      : std_logic;
  signal dp_do_step      : std_logic;
  signal dp_init_value   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_feedback_val : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_lfsr_input   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_lfsr_next    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_lfsr_in_reg  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_wdata_reg    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

begin

  u_tg: entity work.tg_write_top_dbg
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => o_done,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_ext_update_en => '0',
      i_ext_data_in   => (others => '0'),

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

      o_lfsr_value => tg_lfsr_value,

      o_dbg_state           => tg_state,
      o_dbg_aw_hs           => tg_aw_hs,
      o_dbg_w_hs            => tg_w_hs,
      o_dbg_b_hs            => tg_b_hs,
      o_dbg_bhs_seen        => tg_bhs_seen,
      o_dbg_txn_start_pulse => tg_txn_start_pulse,
      o_dbg_wbeat_pulse     => tg_wbeat_pulse,

      o_dbg_seeded       => dp_seeded,
      o_dbg_do_init      => dp_do_init,
      o_dbg_do_step      => dp_do_step,
      o_dbg_init_value   => dp_init_value,
      o_dbg_feedback_val => dp_feedback_val,
      o_dbg_lfsr_input   => dp_lfsr_input,
      o_dbg_lfsr_next    => dp_lfsr_next,
      o_dbg_lfsr_in_reg  => dp_lfsr_in_reg,
      o_dbg_wdata_reg    => dp_wdata_reg
    );

  u_ni: entity work.top_manager
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

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

      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,

      RVALID  => rvalid,
      RREADY  => rready,
      RDATA   => rdata,
      RLAST   => rlast,
      RID     => rid,
      RRESP   => rresp,

      CORRUPT_PACKET => corrupt_packet,

      l_in_data_i  => l_in_data_o,
      l_in_val_i   => l_in_val_o,
      l_in_ack_o   => l_in_ack_i,
      l_out_data_o => l_out_data_i,
      l_out_val_o  => l_out_val_i,
      l_out_ack_i  => l_out_ack_o
    );

  -- AXI exports
  o_dbg_axi_awid    <= awid;
  o_dbg_axi_awaddr  <= awaddr;
  o_dbg_axi_awlen   <= awlen;
  o_dbg_axi_awburst <= awburst;
  o_dbg_axi_awvalid <= awvalid;
  o_dbg_axi_awready <= awready;

  o_dbg_axi_wvalid  <= wvalid;
  o_dbg_axi_wready  <= wready;
  o_dbg_axi_wdata   <= wdata;
  o_dbg_axi_wlast   <= wlast;

  o_dbg_axi_bid     <= bid;
  o_dbg_axi_bresp   <= bresp;
  o_dbg_axi_bvalid  <= bvalid;
  o_dbg_axi_bready  <= bready;

  -- TG exports
  o_dbg_tg_state        <= tg_state;
  o_dbg_tg_aw_hs        <= tg_aw_hs;
  o_dbg_tg_w_hs         <= tg_w_hs;
  o_dbg_tg_b_hs         <= tg_b_hs;
  o_dbg_tg_bhs_seen     <= tg_bhs_seen;
  o_dbg_tg_txn_start_pulse <= tg_txn_start_pulse;
  o_dbg_tg_wbeat_pulse     <= tg_wbeat_pulse;

  o_dbg_dp_seeded       <= dp_seeded;
  o_dbg_dp_do_init      <= dp_do_init;
  o_dbg_dp_do_step      <= dp_do_step;
  o_dbg_dp_init_value   <= dp_init_value;
  o_dbg_dp_feedback_val <= dp_feedback_val;
  o_dbg_dp_lfsr_input   <= dp_lfsr_input;
  o_dbg_dp_lfsr_next    <= dp_lfsr_next;
  o_dbg_dp_lfsr_in_reg  <= dp_lfsr_in_reg;
  o_dbg_dp_wdata_reg    <= dp_wdata_reg;

  o_dbg_tg_lfsr_value <= tg_lfsr_value;

  -- NI exports
  o_dbg_corrupt_packet <= corrupt_packet;

end architecture;
