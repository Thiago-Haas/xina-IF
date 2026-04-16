library IEEE;
use IEEE.std_logic_1164.all;

-- Minimal subordinate TM comparator:
-- compares the received payload flit against the current expected LFSR value,
-- while also accepting the next LFSR value to tolerate the existing subordinate
-- monitor timing alignment.
entity subordinate_noc_traffic_mon_compare is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    check_pulse_i : in std_logic;
    expected_i    : in std_logic_vector(p_WIDTH - 1 downto 0);
    expected_next_i : in std_logic_vector(p_WIDTH - 1 downto 0);
    payload_i     : in std_logic_vector(p_WIDTH - 1 downto 0);

    mismatch_o : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_compare is
begin
  mismatch_o <= '1' when
                  (check_pulse_i = '1') and
                  (payload_i /= expected_i) and
                  (payload_i /= expected_next_i)
                else '0';
end architecture;
