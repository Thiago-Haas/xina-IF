library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- RTL top that connects only the TM read master (tm_read_top_dbg) to the NI manager (top_manager).
-- DEBUG VERSION:
--  * Exposes the AXI signals between TM and NI
--  * Exposes TM controller FSM and datapath taps
--  * Exposes NI CORRUPT_PACKET flag
--  * Exposes NoC-side ports for a TB loopback/subordinate emulator
entity tm_ni_read_only_top_dbg is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TM control
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
    -- Debug: AXI between TM and NI (read channels)
    -- ------------------------------------------------------------------
    o_dbg_axi_arid    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_dbg_axi_araddr  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    o_dbg_axi_arlen   : out std_logic_vector(7 downto 0);
    o_dbg_axi_arburst : out std_logic_vector(1 downto 0);
    o_dbg_axi_arvalid : out std_logic;
    o_dbg_axi_arready : out std_logic;

    o_dbg_axi_rvalid  : out std_logic;
    o_dbg_axi_rready  : out std_logic;
    o_dbg_axi_rdata   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_axi_rlast   : out std_logic;
    o_dbg_axi_rid     : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_dbg_axi_rresp   : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    -- ------------------------------------------------------------------
    -- Debug: TM internal
    -- ------------------------------------------------------------------
    o_dbg_tm_state       : out std_logic_vector(1 downto 0);
    o_dbg_tm_ar_hs       : out std_logic;
    o_dbg_tm_r_hs        : out std_logic;
    o_dbg_tm_last_hs     : out std_logic;
    o_dbg_tm_txn_start_pulse : out std_logic;
    o_dbg_tm_rbeat_pulse     : out std_logic;
    o_dbg_tm_arvalid     : out std_logic;
    o_dbg_tm_rready      : out std_logic;

    o_dbg_dp_seeded       : out std_logic;
    o_dbg_dp_do_init      : out std_logic;
    o_dbg_dp_do_step      : out std_logic;
    o_dbg_dp_init_value   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_lfsr_input   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_lfsr_next    : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_lfsr_in_reg  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_expected_reg : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_dp_mismatch     : out std_logic;

    -- legacy debug
    o_dbg_expected_value  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- ------------------------------------------------------------------
    -- Debug: NI
    -- ------------------------------------------------------------------
    o_dbg_corrupt_packet  : out std_logic
  );
end entity;

architecture rtl of tm_ni_read_only_top_dbg is
  -- AXI read interconnect
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

  -- unused write channels (tied off)
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal awlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal awburst : std_logic_vector(1 downto 0) := "01";

  signal wvalid : std_logic := '0';
  signal wready : std_logic;
  signal wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal wlast  : std_logic := '0';

  signal bvalid : std_logic;
  signal bready : std_logic := '0';
  signal bid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal corrupt_packet : std_logic;
  signal exp_value      : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal mismatch       : std_logic;

  -- TM internal debug
  signal tm_state   : std_logic_vector(1 downto 0);
  signal tm_ar_hs   : std_logic;
  signal tm_r_hs    : std_logic;
  signal tm_last_hs : std_logic;
  signal tm_txn_start_pulse : std_logic;
  signal tm_rbeat_pulse     : std_logic;
  signal tm_arvalid_dbg     : std_logic;
  signal tm_rready_dbg      : std_logic;

  signal dp_seeded       : std_logic;
  signal dp_do_init      : std_logic;
  signal dp_do_step      : std_logic;
  signal dp_init_value   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_lfsr_input   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_lfsr_next    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_lfsr_in_reg  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal dp_expected_reg : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

begin

  u_tm: entity work.tm_read_top_dbg
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => o_done,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

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

      o_mismatch       => mismatch,
      o_expected_value => exp_value,

      o_dbg_state           => tm_state,
      o_dbg_ar_hs           => tm_ar_hs,
      o_dbg_r_hs            => tm_r_hs,
      o_dbg_last_hs         => tm_last_hs,
      o_dbg_txn_start_pulse => tm_txn_start_pulse,
      o_dbg_rbeat_pulse     => tm_rbeat_pulse,
      o_dbg_arvalid         => tm_arvalid_dbg,
      o_dbg_rready          => tm_rready_dbg,

      o_dbg_seeded       => dp_seeded,
      o_dbg_do_init      => dp_do_init,
      o_dbg_do_step      => dp_do_step,
      o_dbg_init_value   => dp_init_value,
      o_dbg_lfsr_input   => dp_lfsr_input,
      o_dbg_lfsr_next    => dp_lfsr_next,
      o_dbg_lfsr_in_reg  => dp_lfsr_in_reg,
      o_dbg_expected_reg => dp_expected_reg
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
  o_dbg_axi_arid    <= arid;
  o_dbg_axi_araddr  <= araddr;
  o_dbg_axi_arlen   <= arlen;
  o_dbg_axi_arburst <= arburst;
  o_dbg_axi_arvalid <= arvalid;
  o_dbg_axi_arready <= arready;

  o_dbg_axi_rvalid  <= rvalid;
  o_dbg_axi_rready  <= rready;
  o_dbg_axi_rdata   <= rdata;
  o_dbg_axi_rlast   <= rlast;
  o_dbg_axi_rid     <= rid;
  o_dbg_axi_rresp   <= rresp;

  -- TM exports
  o_dbg_tm_state           <= tm_state;
  o_dbg_tm_ar_hs           <= tm_ar_hs;
  o_dbg_tm_r_hs            <= tm_r_hs;
  o_dbg_tm_last_hs         <= tm_last_hs;
  o_dbg_tm_txn_start_pulse <= tm_txn_start_pulse;
  o_dbg_tm_rbeat_pulse     <= tm_rbeat_pulse;
  o_dbg_tm_arvalid         <= tm_arvalid_dbg;
  o_dbg_tm_rready          <= tm_rready_dbg;

  o_dbg_dp_seeded       <= dp_seeded;
  o_dbg_dp_do_init      <= dp_do_init;
  o_dbg_dp_do_step      <= dp_do_step;
  o_dbg_dp_init_value   <= dp_init_value;
  o_dbg_dp_lfsr_input   <= dp_lfsr_input;
  o_dbg_dp_lfsr_next    <= dp_lfsr_next;
  o_dbg_dp_lfsr_in_reg  <= dp_lfsr_in_reg;
  o_dbg_dp_expected_reg <= dp_expected_reg;
  o_dbg_dp_mismatch     <= mismatch;

  o_dbg_expected_value <= exp_value;

  -- NI exports
  o_dbg_corrupt_packet <= corrupt_packet;

end architecture;
