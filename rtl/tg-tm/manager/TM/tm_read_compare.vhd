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
    check_pulse_i : in std_logic; -- do comparison on this cycle (typically RVALID&RREADY)

    expected_i : in std_logic_vector(p_WIDTH - 1 downto 0);
    rdata_i    : in std_logic_vector(p_WIDTH - 1 downto 0);

    lfsr_comparison_mismatch_o : out std_logic
  );
end entity;

architecture rtl of tm_read_compare is
begin
  lfsr_comparison_mismatch_o <= '1' when (check_pulse_i = '1') and (rdata_i /= expected_i) else '0';
end rtl;
