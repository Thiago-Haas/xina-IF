library ieee;
use ieee.std_logic_1164.all;

use work.xina_ni_ft_pkg.all;

-- Control-side adapter kept outside TMR:
--  * rebuilds captured flit for lb_dp
--  * maps flit select to response flit data
entity lb_ctrl_adapter is
  port (
    i_lin_data      : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_cap_flit_ctrl : in  std_logic;

    i_tx_flit_sel     : in  std_logic_vector(2 downto 0); -- 000 H0, 001 H1, 010 H2, 011 PAYLOAD, 100 CHKSUM
    i_tx_next_is_read : in  std_logic;
    i_rd_payload      : in  std_logic_vector(31 downto 0);

    o_cap_flit  : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_lout_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of lb_ctrl_adapter is
  constant c_RESP_HDR0_CONST : std_logic_vector(31 downto 0) := x"00000000";
  constant c_RESP_HDR1_CONST : std_logic_vector(31 downto 0) := x"00000100";
  constant c_HDR2_WR         : std_logic_vector(31 downto 0) := x"00000001";
  constant c_HDR2_RD         : std_logic_vector(31 downto 0) := x"00000002";
begin
  -- control bit comes from voted controller path; payload comes direct.
  o_cap_flit <= i_cap_flit_ctrl & i_lin_data(c_AXI_DATA_WIDTH-1 downto 0);

  o_lout_data <= ('1' & c_RESP_HDR0_CONST) when i_tx_flit_sel = "000" else
                 ('0' & c_RESP_HDR1_CONST) when i_tx_flit_sel = "001" else
                 ('0' & c_HDR2_RD)         when (i_tx_flit_sel = "010" and i_tx_next_is_read = '1') else
                 ('0' & c_HDR2_WR)         when (i_tx_flit_sel = "010" and i_tx_next_is_read = '0') else
                 ('0' & i_rd_payload)      when i_tx_flit_sel = "011" else
                 ('1' & x"00000000");
end architecture;
