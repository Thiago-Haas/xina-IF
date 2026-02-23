library IEEE;
use IEEE.std_logic_1164.all;

-- Minimal comparator for TM:
-- single sticky mismatch flag (one register).
-- Cleared on reset or i_init_pulse.
-- Set to '1' if any checked beat mismatches (i_check_pulse).
entity tm_read_compare is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_init_pulse  : in std_logic; -- re-arm / clear mismatch
    i_check_pulse : in std_logic; -- do comparison on this cycle (typically RVALID&RREADY)

    i_expected : in std_logic_vector(p_WIDTH - 1 downto 0);
    i_rdata    : in std_logic_vector(p_WIDTH - 1 downto 0);

    o_mismatch : out std_logic  -- '1' if any mismatch since last init/reset
  );
end entity;

architecture rtl of tm_read_compare is
  signal r_mismatch : std_logic := '0';
begin
  o_mismatch <= r_mismatch;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_mismatch <= '0';
      else
        if i_init_pulse = '1' then
          r_mismatch <= '0';
        elsif i_check_pulse = '1' then
          if i_rdata /= i_expected then
            r_mismatch <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;
