library IEEE;
use IEEE.std_logic_1164.all;

-- Compatibility wrapper:
-- keeps legacy entity name while delegating implementation to the
-- hierarchy-separated observation block (control + datapath).

entity tg_tm_lb_selftest_ctrl is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    o_tg_start : out std_logic;
    i_tg_done  : in  std_logic;
    o_tg_addr  : out std_logic_vector(63 downto 0);
    o_tg_seed  : out std_logic_vector(31 downto 0);

    -- TM control
    o_tm_start : out std_logic;
    i_tm_done  : in  std_logic;
    o_tm_addr  : out std_logic_vector(63 downto 0);
    o_tm_seed  : out std_logic_vector(31 downto 0);

    -- TM result
    i_tm_lfsr_comparison_mismatch : in  std_logic;
    o_error       : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_ctrl is
begin
  u_observation_block: entity work.tg_tm_lb_selftest_observation_block
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      o_tg_start => o_tg_start,
      i_tg_done  => i_tg_done,
      o_tg_addr  => o_tg_addr,
      o_tg_seed  => o_tg_seed,
      o_tm_start => o_tm_start,
      i_tm_done  => i_tm_done,
      o_tm_addr  => o_tm_addr,
      o_tm_seed  => o_tm_seed,
      i_tm_lfsr_comparison_mismatch => i_tm_lfsr_comparison_mismatch,
      o_error       => o_error
    );
end architecture;
