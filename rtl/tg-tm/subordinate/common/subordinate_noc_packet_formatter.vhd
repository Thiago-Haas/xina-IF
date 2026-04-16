library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;

-- Formats manager-style NoC request packets used by the subordinate TG.
entity subordinate_noc_packet_formatter is
  generic(
    p_DEST_X : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_DEST_Y : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_X  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1')
  );
  port(
    is_read_i : in  std_logic;
    address_i : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    payload_i : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    flit_idx_i : in unsigned(2 downto 0);

    flit_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of subordinate_noc_packet_formatter is
  constant C_ZERO_12       : std_logic_vector(11 downto 0) := (others => '0');
  constant C_ZERO_ID       : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  constant C_RESERVED_8    : std_logic_vector(7 downto 0)  := (others => '0');
  constant C_REQUEST_FLAGS : std_logic_vector(2 downto 0)  := (others => '0');

  signal h_dest_w      : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_src_w       : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_interface_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_address_w   : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal payload_w     : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal trailer_w     : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal checksum_w    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal payload_checksum_w : unsigned(c_AXI_DATA_WIDTH - 1 downto 0);
begin
  h_dest_w      <= '1' & p_DEST_X & p_DEST_Y;
  h_src_w       <= '0' & p_SRC_X & p_SRC_Y;
  h_interface_w <= '0' & C_ZERO_12 & C_ZERO_ID & C_RESERVED_8 & "01" & C_REQUEST_FLAGS & is_read_i & '0';
  h_address_w   <= '0' & address_i(c_AXI_ADDR_WIDTH - 1 downto c_AXI_DATA_WIDTH);
  payload_w     <= '0' & payload_i;
  payload_checksum_w <= unsigned(payload_i) when is_read_i = '0' else
                        to_unsigned(0, c_AXI_DATA_WIDTH);

  checksum_w <= std_logic_vector(unsigned(h_dest_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_src_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_interface_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_address_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 payload_checksum_w);
  trailer_w <= '1' & checksum_w;

  flit_o <= h_dest_w      when flit_idx_i = to_unsigned(0, flit_idx_i'length) else
            h_src_w       when flit_idx_i = to_unsigned(1, flit_idx_i'length) else
            h_interface_w when flit_idx_i = to_unsigned(2, flit_idx_i'length) else
            h_address_w   when flit_idx_i = to_unsigned(3, flit_idx_i'length) else
            payload_w     when flit_idx_i = to_unsigned(4, flit_idx_i'length) and is_read_i = '0' else
            trailer_w;
end architecture;
