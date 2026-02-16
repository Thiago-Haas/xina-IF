library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- TG-TM system top (TM hookup TBD)
--
-- For now:
--   * Instantiates the TG write-phase generator (tg_write_top)
--   * Instantiates the Manager NI top (top_manager)
--   * Connects TG <-> NI through AXI write channels only
--   * Read channels are tied-off (TM will be connected later)
--
entity tg_tm_manager_top is
  generic(
    -- TG LFSR base/random init value (lower 32 bits are overwritten by STARTING_SEED inside TG)
    p_TG_INIT_VALUE : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- NI / Manager generics
    p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');

    p_BUFFER_DEPTH      : positive := c_BUFFER_DEPTH;
    p_USE_TMR_PACKETIZER: boolean  := c_USE_TMR_PACKETIZER;
    p_USE_TMR_FLOW      : boolean  := c_USE_TMR_FLOW;
    p_USE_TMR_INTEGRITY : boolean  := c_USE_TMR_INTEGRITY;
    p_USE_HAMMING       : boolean  := c_USE_HAMMING;
    p_USE_INTEGRITY     : boolean  := c_USE_INTEGRITY
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control (CONTROL-only ports)
    i_tg_start   : in  std_logic := '1';
    o_tg_done    : out std_logic;
    i_tg_address : in  std_logic_vector(63 downto 0);
    i_tg_seed    : in  std_logic_vector(31 downto 0);

    -- Optional CONTROL-only override hook (keep for debug/bring-up)
    i_tg_ext_update_en : in std_logic := '0';
    i_tg_ext_data_in   : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- Debug
    o_tg_lfsr_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Extra from NI
    o_corrupt_packet : out std_logic;

    -- XINA link (connect to your router / NoC)
    l_in_data_i  : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_in_val_i   : out std_logic;
    l_in_ack_o   : in  std_logic;
    l_out_data_o : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_out_val_o  : in  std_logic;
    l_out_ack_i  : out std_logic
  );
end tg_tm_manager_top;

architecture rtl of tg_tm_manager_top is
  -- AXI write channel wiring TG <-> NI
  signal w_AWVALID : std_logic;
  signal w_AWREADY : std_logic;
  signal w_AWID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal w_AWADDR  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal w_AWLEN   : std_logic_vector(7 downto 0);
  signal w_AWBURST : std_logic_vector(1 downto 0);

  signal w_WVALID  : std_logic;
  signal w_WREADY  : std_logic;
  signal w_WDATA   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_WLAST   : std_logic;

  signal w_BVALID  : std_logic;
  signal w_BREADY  : std_logic;
  signal w_BID     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal w_BRESP   : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- Read channel tie-offs (TM will drive these later)
  signal w_ARVALID : std_logic;
  signal w_ARID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal w_ARADDR  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal w_ARLEN   : std_logic_vector(7 downto 0);
  signal w_ARBURST : std_logic_vector(1 downto 0);
  signal w_RREADY  : std_logic;

begin
  -- Tie-off read channel until TM is instantiated
  w_ARVALID <= '0';
  w_ARID    <= (others => '0');
  w_ARADDR  <= (others => '0');
  w_ARLEN   <= (others => '0');
  w_ARBURST <= "01";      -- INCR
  w_RREADY  <= '0';

  u_TG: entity work.tg_write_top
    generic map(
      p_INIT_VALUE => p_TG_INIT_VALUE
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_tg_start,
      o_done  => o_tg_done,

      INPUT_ADDRESS => i_tg_address,
      STARTING_SEED => i_tg_seed,

      i_ext_update_en => i_tg_ext_update_en,
      i_ext_data_in   => i_tg_ext_data_in,

      -- Write request channel
      AWID    => w_AWID,
      AWADDR  => w_AWADDR,
      AWLEN   => w_AWLEN,
      AWBURST => w_AWBURST,
      AWVALID => w_AWVALID,
      AWREADY => w_AWREADY,

      -- Write data channel
      WVALID  => w_WVALID,
      WREADY  => w_WREADY,
      WDATA   => w_WDATA,
      WLAST   => w_WLAST,

      -- Write response channel
      BID     => w_BID,
      BRESP   => w_BRESP(1 downto 0), -- AXI BRESP is 2 bits
      BVALID  => w_BVALID,
      BREADY  => w_BREADY,

      -- debug
      o_lfsr_value => o_tg_lfsr_value
    );

  u_NI: entity work.top_manager
    generic map(
      p_SRC_X => p_SRC_X,
      p_SRC_Y => p_SRC_Y,
      p_BUFFER_DEPTH       => p_BUFFER_DEPTH,
      p_USE_TMR_PACKETIZER => p_USE_TMR_PACKETIZER,
      p_USE_TMR_FLOW       => p_USE_TMR_FLOW,
      p_USE_TMR_INTEGRITY  => p_USE_TMR_INTEGRITY,
      p_USE_HAMMING        => p_USE_HAMMING,
      p_USE_INTEGRITY      => p_USE_INTEGRITY
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write request
      AWVALID => w_AWVALID,
      AWREADY => w_AWREADY,
      AWID    => w_AWID,
      AWADDR  => w_AWADDR,
      AWLEN   => w_AWLEN,
      AWBURST => w_AWBURST,

      -- Write data
      WVALID  => w_WVALID,
      WREADY  => w_WREADY,
      WDATA   => w_WDATA,
      WLAST   => w_WLAST,

      -- Write response
      BVALID  => w_BVALID,
      BREADY  => w_BREADY,
      BID     => w_BID,
      BRESP   => w_BRESP,

      -- Read request (tied-off for now)
      ARVALID => w_ARVALID,
      ARREADY => open,
      ARID    => w_ARID,
      ARADDR  => w_ARADDR,
      ARLEN   => w_ARLEN,
      ARBURST => w_ARBURST,

      -- Read response/data (unused for now)
      RVALID  => open,
      RREADY  => w_RREADY,
      RDATA   => open,
      RLAST   => open,
      RID     => open,
      RRESP   => open,

      -- Extra
      CORRUPT_PACKET => o_corrupt_packet,

      -- XINA
      l_in_data_i  => l_in_data_i,
      l_in_val_i   => l_in_val_i,
      l_in_ack_o   => l_in_ack_o,
      l_out_data_o => l_out_data_o,
      l_out_val_o  => l_out_val_o,
      l_out_ack_i  => l_out_ack_i
    );

end rtl;