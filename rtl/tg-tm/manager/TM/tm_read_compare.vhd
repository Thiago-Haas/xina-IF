library IEEE;
use IEEE.std_logic_1164.all;

-- Minimal comparator for TM:
-- combinational mismatch flag:
-- '1' only on checked beats that mismatch.
entity tm_read_compare is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    i_check_pulse : in std_logic; -- do comparison on this cycle (typically RVALID&RREADY)

    i_expected : in std_logic_vector(p_WIDTH - 1 downto 0);
    i_rdata    : in std_logic_vector(p_WIDTH - 1 downto 0);

    o_lfsr_comparison_mismatch : out std_logic
  );
end entity;

architecture rtl of tm_read_compare is
begin
  o_lfsr_comparison_mismatch <= '1' when (i_check_pulse = '1') and (i_rdata /= i_expected) else '0';
end rtl;
