library IEEE;
use IEEE.std_logic_1164.all;

-- Combinational LFSR "next state" block used by tg_write_datapath.
-- This matches the polynomial/taps you previously used:
--   fb := x(msb) xor x(msb-1) xor x(msb-3) xor x(msb-4)
entity tg_write_lfsr is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    i_data : in  std_logic_vector(p_WIDTH - 1 downto 0);
    o_next : out std_logic_vector(p_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of tg_write_lfsr is
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
  o_next <= next_lfsr(i_data);
end rtl;
