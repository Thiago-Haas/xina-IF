library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Datapath slice for closed-box self-test observation block.
-- Keeps only static vectors (addr/seed).
entity manager_seed_addr_constants is
  port (
    tg_addr_o : out std_logic_vector(63 downto 0);
    tg_seed_o : out std_logic_vector(31 downto 0);
    tm_addr_o : out std_logic_vector(63 downto 0);
    tm_seed_o : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of manager_seed_addr_constants is
  constant c_SEED_INIT : unsigned(31 downto 0) := to_unsigned(16#1ACEB00C#, 32);
begin
  tg_addr_o <= (others => '0');
  tm_addr_o <= (others => '0');
  tg_seed_o <= std_logic_vector(c_SEED_INIT);
  tm_seed_o <= std_logic_vector(c_SEED_INIT);
end architecture;
