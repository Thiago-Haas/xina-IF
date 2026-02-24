library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Flat hierarchy top (non-debug): TG + TM + single NI + loopback.
--
-- IMPORTANT (matches working tg_ni_write_only_top / tm_ni_read_only_top wrappers):
--   * top_manager exposes NI->NoC request stream on ports named l_in_* (yes, *_i suffix!)
--   * top_manager consumes NoC->NI response stream on ports named l_out_* (yes, *_o suffix!)
--
-- Wiring:
--   NI request  (top_manager.l_in_*)  -> loopback.lin_*
--   NI response (top_manager.l_out_*) <- loopback.lout_*
entity tg_tm_ni_hwloopback_flat_top is
  generic (
    p_MEM_ADDR_BITS : natural := 10
  );
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

    -- TM observability
    o_tm_mismatch       : out std_logic;
    o_tm_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of tg_tm_ni_hwloopback_flat_top is

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

  -- TM
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

  -- Single NI manager
  u_ni: entity work.top_manager
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

      corrupt_packet => open
    );

  -- HW loopback (non-debug)
  u_lb: entity work.tg_tm_loopback_top
    generic map(
      p_MEM_ADDR_BITS => p_MEM_ADDR_BITS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_data_i => lin_data,
      lin_val_i  => lin_val,
      lin_ack_o  => lin_ack,

      lout_data_o => lout_data,
      lout_val_o  => lout_val,
      lout_ack_i  => lout_ack
    );

end architecture;
