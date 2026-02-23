library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- RTL top that connects only the TM read block (tm_read_top)
-- to the NI manager (top_manager).
--
-- This is the READ-only equivalent of tg_ni_write_only_top.
-- Unused AXI write channel is tied off.
--
-- NoC-side ports are exposed so a TB can emulate a subordinate/loopback.
entity tm_ni_read_only_top is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TM control
    i_start       : in  std_logic;
    o_done        : out std_logic;
    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- Optional observability from TM
    o_mismatch       : out std_logic;
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- NoC-side (connect to TB / NoC)
    l_in_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_in_val_o  : out std_logic;
    l_in_ack_i  : in  std_logic;

    l_out_data_i: in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_out_val_i : in  std_logic;
    l_out_ack_o : out std_logic
  );
end entity;

architecture rtl of tm_ni_read_only_top is

  -- AXI write channel (unused)
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal awlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal awburst : std_logic_vector(1 downto 0) := "01";

  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal wdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal wlast   : std_logic := '0';

  signal bid     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp   : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic := '1';

  -- AXI read channel (used)
  signal arvalid : std_logic;
  signal arready : std_logic;
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen   : std_logic_vector(7 downto 0);
  signal arburst : std_logic_vector(1 downto 0);

  signal rvalid : std_logic;
  signal rready : std_logic;
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

begin

  -- Traffic Monitor / Read generator
  u_tm: entity work.tm_read_top
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

      o_mismatch       => o_mismatch,
      o_expected_value => o_expected_value
    );

  -- NI manager
  u_ni: entity work.top_manager
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write channels (tied off)
      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,

      WVALID => wvalid,
      WREADY => wready,
      WDATA  => wdata,
      WLAST  => wlast,

      BVALID => bvalid,
      BREADY => bready,
      BID    => bid,
      BRESP  => bresp,

      -- Read channels (used)
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

      CORRUPT_PACKET => open,

      -- NoC-side
      l_in_data_i  => l_in_data_o,
      l_in_val_i   => l_in_val_o,
      l_in_ack_o   => l_in_ack_i,
      l_out_data_o => l_out_data_i,
      l_out_val_o  => l_out_val_i,
      l_out_ack_i  => l_out_ack_o
    );

end architecture;
