library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Top for the write phase (AW/W/B).
-- Only the AXI ports are used for communication through the NI.
-- STARTING_SEED and p_INIT_VALUE are CONTROL-only and are meant to match the TM side later.
entity tg_write_top is
  generic(
    -- Base/random start value for LFSR(in).
    -- Lower 32 bits are overwritten by STARTING_SEED.
    p_INIT_VALUE : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0')
  );
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    -- sequencing
    i_start : in  std_logic := '1';
    o_done  : out std_logic;

    -- control inputs
    INPUT_ADDRESS : in std_logic_vector(63 downto 0);
    STARTING_SEED : in std_logic_vector(31 downto 0);

    -- Optional CONTROL-only override (default off)
    i_ext_update_en : in std_logic := '0';
    i_ext_data_in   : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- Write request channel
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);
    AWVALID : out std_logic;
    AWREADY : in  std_logic;

    -- Write data channel
    WVALID  : out std_logic;
    WREADY  : in  std_logic;
    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic;

    -- Write response channel
    BID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
    BVALID : in  std_logic;
    BREADY : out std_logic;

    -- debug (post-LFSR reg = WDATA)
    o_lfsr_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tg_write_top;

architecture rtl of tg_write_top is
  signal w_write_done : std_logic;
  signal w_txn_start_pulse : std_logic;
  signal w_wbeat_pulse     : std_logic;
begin
  u_CTRL: entity work.tg_write_controller
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => w_write_done,

      AWREADY => AWREADY,
      WREADY  => WREADY,
      BVALID  => BVALID,

      AWVALID => AWVALID,
      WVALID  => WVALID,
      BREADY  => BREADY,

      o_txn_start_pulse => w_txn_start_pulse,
      o_wbeat_pulse     => w_wbeat_pulse
    );

  u_DP: entity work.tg_write_datapath
    generic map(
      p_INIT_VALUE => p_INIT_VALUE
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_txn_start_pulse => w_txn_start_pulse,
      i_wbeat_pulse     => w_wbeat_pulse,

      i_ext_update_en => i_ext_update_en,
      i_ext_data_in   => i_ext_data_in,

      AWID    => AWID,
      AWADDR  => AWADDR,
      AWLEN   => AWLEN,
      AWBURST => AWBURST,

      WDATA   => WDATA,
      WLAST   => WLAST,

      o_lfsr_value => o_lfsr_value
    );

  o_done <= w_write_done;
end rtl;
