library IEEE;
use IEEE.std_logic_1164.all;

-- Combinational LFSR core for subordinate NoC TM.
-- Matches the subordinate NoC TG and manager TG/TM polynomial.
entity subordinate_noc_traffic_mon_lfsr is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    data_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
    next_o : out std_logic_vector(p_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_lfsr is
  signal fb : std_logic;
begin
  fb     <= data_i(p_WIDTH - 1) xor data_i(p_WIDTH - 2) xor data_i(p_WIDTH - 4) xor data_i(p_WIDTH - 5);
  next_o <= data_i(p_WIDTH - 2 downto 0) & fb;
end architecture;
