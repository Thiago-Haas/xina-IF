library IEEE;

use IEEE.std_logic_1164.all;

package xina_noc_pkg is
  ------------------------------------------------------------------------------
  -- AXI / Interface Widths
  ------------------------------------------------------------------------------
  -- First half: operation address. Second half: IP address (XXYY).
  constant c_AXI_DATA_WIDTH : natural := 32;
  constant c_AXI_ADDR_WIDTH : natural := c_AXI_DATA_WIDTH * 2;
  -- Corresponds to ID_W_WIDTH and ID_R_WIDTH.
  constant c_AXI_ID_WIDTH   : natural := 5;
  -- Corresponds to BRESP_WIDTH and RRESP_WIDTH.
  constant c_AXI_RESP_WIDTH : natural := 3;

  constant c_FLIT_WIDTH   : natural  := c_AXI_DATA_WIDTH + 1;
  constant c_BUFFER_DEPTH : positive := 8;

  ------------------------------------------------------------------------------
  -- Shared FT Switches
  ------------------------------------------------------------------------------
  constant c_ENABLE_TMR_PACKETIZER        : boolean := true;
  constant c_ENABLE_TMR_FLOW_CTRL         : boolean := true;
  constant c_ENABLE_INTEGRITY_CHECK       : boolean := true;
  constant c_ENABLE_TMR_INTEGRITY_CHECK   : boolean := true;
  constant c_ENABLE_HAMMING_PROTECTION    : boolean := true;
  constant c_ENABLE_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_HAM_FIFO_CTRL_TMR     : boolean := true;

  ------------------------------------------------------------------------------
  -- XINA NoC Configuration
  ------------------------------------------------------------------------------
  constant flow_ft_c          : natural  := 1; -- 1=TMR, 0=standard
  constant routing_ft_c       : natural  := 1; -- 1=TMR, 0=standard
  constant arbitration_ft_c   : natural  := 1; -- 1=TMR, 0=standard
  constant buffering_ft_c     : natural  := 1; -- 1=Hamming, 0=standard
  constant rows_c             : positive := 2;
  constant cols_c             : positive := 2;
  constant flow_mode_c        : natural  := 0; -- 0=HS Moore, 1=HS Mealy
  constant routing_mode_c     : natural  := 0; -- 0=XY Moore, 1=XY Mealy
  constant arbitration_mode_c : natural  := 0; -- 0=RR Moore, 1=RR Mealy
  constant buffer_mode_c      : natural  := 0; -- 0=FIFO Ring, 1=FIFO Shift
  constant buffer_depth_c     : positive := 4;
  constant data_width_c       : positive := 32;

  ------------------------------------------------------------------------------
  -- XINA NoC Datatypes
  ------------------------------------------------------------------------------
  type data_link_l_t is array (cols_c - 1 downto 0, rows_c - 1 downto 0) of std_logic_vector(data_width_c downto 0);
  type data_link_x_t is array (cols_c downto 0, rows_c - 1 downto 0) of std_logic_vector(data_width_c downto 0);
  type data_link_y_t is array (cols_c - 1 downto 0, rows_c downto 0) of std_logic_vector(data_width_c downto 0);
  type ctrl_link_l_t is array (cols_c - 1 downto 0, rows_c - 1 downto 0) of std_logic;
  type ctrl_link_x_t is array (cols_c downto 0, rows_c - 1 downto 0) of std_logic;
  type ctrl_link_y_t is array (cols_c - 1 downto 0, rows_c downto 0) of std_logic;
end package;

