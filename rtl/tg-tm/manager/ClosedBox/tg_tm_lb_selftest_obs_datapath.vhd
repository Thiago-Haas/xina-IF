library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Datapath slice for closed-box self-test observation block.
-- Keeps only static vectors (addr/seed).
entity tg_tm_lb_selftest_obs_datapath is
  port (
    o_tg_addr : out std_logic_vector(63 downto 0);
    o_tg_seed : out std_logic_vector(31 downto 0);
    o_tm_addr : out std_logic_vector(63 downto 0);
    o_tm_seed : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_datapath is
  constant c_SEED_INIT : unsigned(31 downto 0) := to_unsigned(16#1ACEB00C#, 32);
begin
  o_tg_addr <= (others => '0');
  o_tm_addr <= (others => '0');
  o_tg_seed <= std_logic_vector(c_SEED_INIT);
  o_tm_seed <= std_logic_vector(c_SEED_INIT);
end architecture;
