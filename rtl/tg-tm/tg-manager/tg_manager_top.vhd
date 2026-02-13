library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity tg_manager_top is
  port(
    -- AMBA-AXI 5 signals.
    ACLK  : in std_logic;
    ARESETn : in std_logic;

    INPUT_ADDRESS  : in std_logic_vector(63 downto 0);
    STARTING_VALUE : in std_logic_vector(31 downto 0); -- LFSR seed (zero-extended)

    -- Write request channel.
    AWID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN  : out std_logic_vector(7 downto 0);
    AWBURST: out std_logic_vector(1 downto 0);
    AWVALID: out std_logic;
    AWREADY: in std_logic;

    -- Write data channel.
    WVALID : out std_logic;
    WREADY : in std_logic;
    WDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST  : out std_logic;

    -- Write response channel.
    BID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    BRESP  : in std_logic_vector(1 downto 0);
    BVALID : in std_logic;
    BREADY : out std_logic;

    -- Read request channel.
    ARID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN  : out std_logic_vector(7 downto 0);
    ARBURST: out std_logic_vector(1 downto 0);
    ARVALID: out std_logic;
    ARREADY: in std_logic;

    -- Read data channel.
    RID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    RDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RRESP  : in std_logic_vector(1 downto 0);
    RLAST  : in std_logic;
    RVALID : in std_logic;
    RREADY : out std_logic
  );
end tg_manager_top;

architecture rtl of tg_manager_top is

  -- Controller -> enables
  signal w_load_wdata  : std_logic;
  signal w_update_lfsr : std_logic;

  -- LFSR signals
  signal w_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_seed  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

begin

  -- Seed: zero-extend STARTING_VALUE into DATA_WIDTH
  w_lfsr_seed <= (others => '0');
  w_lfsr_seed(31 downto 0) <= STARTING_VALUE;

  u_CTRL: entity work.tg_manager_controller
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      AWREADY => AWREADY,
      WREADY  => WREADY,
      BVALID  => BVALID,
      ARREADY => ARREADY,
      RVALID  => RVALID,
      RLAST   => RLAST,

      AWVALID => AWVALID,
      WVALID  => WVALID,
      BREADY  => BREADY,
      ARVALID => ARVALID,
      RREADY  => RREADY,

      o_load_wdata  => w_load_wdata,
      o_update_lfsr => w_update_lfsr
    );

  -- LFSR uses the read data directly as input for next_lfsr( RDATA ) on r_done
  u_LFSR: entity work.lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      ACLK        => ACLK,
      ARESETn     => ARESETn,
      i_seed      => w_lfsr_seed,
      i_update_en => w_update_lfsr,
      i_data_in   => RDATA,
      o_value     => w_lfsr_value
    );

  u_DP: entity work.tg_manager_datapath
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      INPUT_ADDRESS => INPUT_ADDRESS,

      i_lfsr_value => w_lfsr_value,
      i_load_wdata => w_load_wdata,

      AWID    => AWID,
      AWADDR  => AWADDR,
      AWLEN   => AWLEN,
      AWBURST => AWBURST,

      WDATA   => WDATA,
      WLAST   => WLAST,

      ARID    => ARID,
      ARADDR  => ARADDR,
      ARLEN   => ARLEN,
      ARBURST => ARBURST
    );

end rtl;
