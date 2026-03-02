library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Combinational LFSR core for TM.
-- Must match tg_write_lfsr polynomial/taps so TG and TM stay in lock-step.
entity tm_read_lfsr is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    i_value : in  std_logic_vector(p_WIDTH - 1 downto 0);
    o_next  : out std_logic_vector(p_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of tm_read_lfsr is
  function next_lfsr(x : std_logic_vector) return std_logic_vector is
    variable v  : std_logic_vector(x'range) := x;
    variable fb : std_logic;
  begin
    -- Same taps as tg_write_lfsr (example taps; adjust if you use a specific polynomial).
    fb := v(v'high) xor v(v'high-1) xor v(v'high-3) xor v(v'high-4);
    v  := v(v'high-1 downto 0) & fb;
    return v;
  end function;
begin
  o_next <= next_lfsr(i_value);
end rtl;