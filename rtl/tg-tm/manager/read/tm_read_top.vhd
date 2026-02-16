library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Top for the read phase (AR/R).
entity tm_read_top is
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    -- sequencing
    i_start : in  std_logic := '1';
    o_done  : out std_logic;

    INPUT_ADDRESS : in std_logic_vector(63 downto 0);
    STARTING_SEED : in std_logic_vector(31 downto 0);

    -- Read request channel
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);
    ARVALID : out std_logic;
    ARREADY : in  std_logic;

    -- Read data channel
-- Read data channel
    RID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    RDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RRESP  : in  std_logic_vector(1 downto 0) := (others => '0');
    RLAST  : in  std_logic;
    RVALID : in  std_logic;
    RREADY : out std_logic;

    -- Optional: expose raw read data for chaining into TG
    o_rdata_sample : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_rdone_pulse  : out std_logic;

    -- debug
    o_lfsr_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tm_read_top;

architecture rtl of tm_read_top is
  signal w_update_lfsr : std_logic;
  signal w_done        : std_logic;
begin
  u_CTRL: entity work.tm_read_controller
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => w_done,

      ARREADY => ARREADY,
      RVALID  => RVALID,
      RLAST   => RLAST,

      ARVALID => ARVALID,
      RREADY  => RREADY,

      o_update_lfsr => w_update_lfsr
    );

  u_DP: entity work.tm_read_datapath
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_update_lfsr => w_update_lfsr,
      i_rdata_in    => RDATA,

      ARID    => ARID,
      ARADDR  => ARADDR,
      ARLEN   => ARLEN,
      ARBURST => ARBURST,

      o_lfsr_value => o_lfsr_value
    );

  -- simple chaining helpers
  o_rdata_sample <= RDATA;
  o_rdone_pulse  <= w_update_lfsr;

  o_done <= w_done;
end rtl;
