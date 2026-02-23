library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- RTL top that combines:
--   * TG write block (tg_write_top)
--   * TM read  block (tm_read_top)
--   * ONE NI manager (top_manager)
--
-- The NI NoC-side ports are exposed so a TB can emulate a loopback/subordinate.
--
-- NOTE: Do NOT start TG and TM at the same time. Even though AXI read/write channels
-- are independent, the NI injection path is typically single-threaded.
entity tg_tm_ni_top is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    i_tg_start       : in  std_logic;
    o_tg_done        : out std_logic;
    TG_INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    TG_STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- TM control
    i_tm_start       : in  std_logic;
    o_tm_done        : out std_logic;
    TM_INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    TM_STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- Optional observability from TM
    o_tm_mismatch       : out std_logic;
    o_tm_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- NoC-side (connect to TB / NoC)
    l_in_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_in_val_o  : out std_logic;
    l_in_ack_i  : in  std_logic;

    l_out_data_i: in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_out_val_i : in  std_logic;
    l_out_ack_o : out std_logic
  );
end entity;

architecture rtl of tg_tm_ni_top is
  -----------------------------------------------------------------------------
  -- AXI write channel (TG -> NI)
  -----------------------------------------------------------------------------
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

  -----------------------------------------------------------------------------
  -- AXI read channel (TM -> NI)
  -----------------------------------------------------------------------------
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

  signal corrupt_packet : std_logic;
  signal tg_lfsr_value  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- TG write generator
  -----------------------------------------------------------------------------
  u_tg: entity work.tg_write_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_tg_start,
      o_done  => o_tg_done,

      INPUT_ADDRESS => TG_INPUT_ADDRESS,
      STARTING_SEED => TG_STARTING_SEED,

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

      o_lfsr_value => tg_lfsr_value
    );

  -----------------------------------------------------------------------------
  -- TM read generator / monitor
  -----------------------------------------------------------------------------
  u_tm: entity work.tm_read_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_tm_start,
      o_done  => o_tm_done,

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

      o_mismatch       => o_tm_mismatch,
      o_expected_value => o_tm_expected_value
    );

  -----------------------------------------------------------------------------
  -- NI manager (single instance)
  -----------------------------------------------------------------------------
  u_ni: entity work.top_manager
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write channels
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

      -- Read channels
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

      -- NoC-side
      l_in_data_i  => l_in_data_o,
      l_in_val_i   => l_in_val_o,
      l_in_ack_o   => l_in_ack_i,
      l_out_data_o => l_out_data_i,
      l_out_val_o  => l_out_val_i,
      l_out_ack_i  => l_out_ack_o
    );

end architecture;
