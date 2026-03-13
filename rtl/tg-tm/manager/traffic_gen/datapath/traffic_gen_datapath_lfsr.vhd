library IEEE;
use IEEE.std_logic_1164.all;

-- Combinational LFSR "next state" block used by traffic_gen_datapath.
-- This matches the polynomial/taps you previously used:
--   fb := x(msb) xor x(msb-1) xor x(msb-3) xor x(msb-4)
entity traffic_gen_datapath_lfsr is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    data_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
    next_o : out std_logic_vector(p_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of traffic_gen_datapath_lfsr is
  signal fb : std_logic;
begin
  -- Same taps as before:
  -- fb := x(msb) xor x(msb-1) xor x(msb-3) xor x(msb-4)
  fb     <= data_i(p_WIDTH-1) xor data_i(p_WIDTH-2) xor data_i(p_WIDTH-4) xor data_i(p_WIDTH-5);
  next_o <= data_i(p_WIDTH-2 downto 0) & fb;
end rtl;
