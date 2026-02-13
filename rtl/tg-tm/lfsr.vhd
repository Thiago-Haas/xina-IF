library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- LFSR block:
-- - Seed loaded on reset
-- - On update enable, computes next_lfsr( i_data_in )  (OPTION B)

entity lfsr is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_seed      : in  std_logic_vector(p_WIDTH - 1 downto 0);
    i_update_en : in  std_logic;
    i_data_in   : in  std_logic_vector(p_WIDTH - 1 downto 0);

    o_value     : out std_logic_vector(p_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of lfsr is
  signal r_lfsr : std_logic_vector(p_WIDTH - 1 downto 0) := (others => '0');

  function next_lfsr(x : std_logic_vector) return std_logic_vector is
    variable v  : std_logic_vector(x'range) := x;
    variable fb : std_logic;
  begin
    -- Example taps (works for width >= 5). Adjust if you need a specific polynomial.
    fb := v(v'high) xor v(v'high-1) xor v(v'high-3) xor v(v'high-4);
    v  := v(v'high-1 downto 0) & fb;
    return v;
  end function;

begin
  o_value <= r_lfsr;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_lfsr <= i_seed;
      else
        if i_update_en = '1' then
          r_lfsr <= next_lfsr(i_data_in);
        end if;
      end if;
    end if;
  end process;

end rtl;
