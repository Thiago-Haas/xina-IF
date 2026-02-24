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
  signal fb : std_logic;
begin
  -- Same taps as before:
  -- fb := x(msb) xor x(msb-1) xor x(msb-3) xor x(msb-4)
  fb     <= i_data(p_WIDTH-1) xor i_data(p_WIDTH-2) xor i_data(p_WIDTH-4) xor i_data(p_WIDTH-5);
  o_next <= i_data(p_WIDTH-2 downto 0) & fb;
end rtl;
