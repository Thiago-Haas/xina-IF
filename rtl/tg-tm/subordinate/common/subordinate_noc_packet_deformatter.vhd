library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;

-- Extracts useful fields from manager-style NoC response packets seen by the subordinate TM.
entity subordinate_noc_packet_deformatter is
  port(
    is_read_i  : in  std_logic;
    flit_idx_i : in  unsigned(2 downto 0);
    flit_i     : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    payload_data_o  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    payload_valid_o : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_packet_deformatter is
begin
  payload_data_o <= flit_i(c_AXI_DATA_WIDTH - 1 downto 0);
  payload_valid_o <= '1' when (flit_idx_i = to_unsigned(3, flit_idx_i'length)) and (is_read_i = '1') else
                     '0';
end architecture;
