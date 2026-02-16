library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Top for the read phase (AR/R).
-- Mirrors tg_write_top: controller + datapath + LFSR core.
entity tm_read_top is
  generic(
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

    -- Read address channel
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);
    ARVALID : out std_logic;
    ARREADY : in  std_logic;

    -- Read data channel
    RVALID : in  std_logic;
    RREADY : out std_logic;
    RDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RLAST  : in  std_logic;

    RID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    RRESP  : in  std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

    -- comparator outputs
    o_match_sticky : out std_logic;
    o_last_match   : out std_logic;
    o_mismatch_cnt : out unsigned(15 downto 0);

    -- debug
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tm_read_top;

architecture rtl of tm_read_top is
  signal w_read_done       : std_logic;
  signal w_txn_start_pulse : std_logic;
  signal w_rbeat_pulse     : std_logic;
begin
  u_CTRL: entity work.tm_read_controller
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => w_read_done,

      ARREADY => ARREADY,
      RVALID  => RVALID,
      RLAST   => RLAST,

      ARVALID => ARVALID,
      RREADY  => RREADY,

      o_txn_start_pulse => w_txn_start_pulse,
      o_rbeat_pulse     => w_rbeat_pulse
    );

  u_DP: entity work.tm_read_datapath
    generic map(
      p_INIT_VALUE => p_INIT_VALUE
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_txn_start_pulse => w_txn_start_pulse,
      i_rbeat_pulse     => w_rbeat_pulse,

      RDATA => RDATA,

      ARID    => ARID,
      ARADDR  => ARADDR,
      ARLEN   => ARLEN,
      ARBURST => ARBURST,

      o_match_sticky   => o_match_sticky,
      o_last_match     => o_last_match,
      o_mismatch_cnt   => o_mismatch_cnt,

      o_expected_value => o_expected_value
    );

  o_done <= w_read_done;
end rtl;