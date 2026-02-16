library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Read-phase datapath (AR* constants + local LFSR update on completed read).
-- LFSR behavior:
-- - Seed loaded on reset from STARTING_SEED (zero-extended to DATA_WIDTH).
-- - Updates only when i_update_lfsr='1' (usually r_done) using i_rdata_in.
entity tm_read_datapath is
  generic(
    p_ARID  : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    p_LEN   : std_logic_vector(7 downto 0) := x"00";
    p_BURST : std_logic_vector(1 downto 0) := "01"
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- from controller
    i_update_lfsr : in std_logic;

    -- from AXI read data channel
    i_rdata_in : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- AXI constant fields (read address)
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);

    -- debug
    o_lfsr_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tm_read_datapath;

architecture rtl of tm_read_datapath is
  signal w_seed_ext   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
begin
  -- Seed: zero-extend STARTING_SEED into DATA_WIDTH
  w_seed_ext <= std_logic_vector(resize(unsigned(STARTING_SEED), c_AXI_DATA_WIDTH));

  -- Constant fields
  ARADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  ARID    <= p_ARID;
  ARLEN   <= p_LEN;
  ARBURST <= p_BURST;

  o_lfsr_value <= w_lfsr_value;

  u_LFSR: entity work.tm_read_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      ACLK        => ACLK,
      ARESETn     => ARESETn,
      i_seed      => w_seed_ext,
      i_update_en => i_update_lfsr,
      i_data_in   => i_rdata_in,    -- raw RDATA (no capture reg)
      o_value     => w_lfsr_value
    );
end rtl;
