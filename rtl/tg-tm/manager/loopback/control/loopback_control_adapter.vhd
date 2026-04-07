library ieee;
use ieee.std_logic_1164.all;

use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

-- Control-side adapter kept outside TMR:
--  * rebuilds captured flit for loopback_datapath
--  * maps flit select to response flit data
entity loopback_control_adapter is
  port (
    lin_data_i      : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    cap_flit_ctrl_i : in  std_logic;

    tx_flit_sel_i     : in  std_logic_vector(2 downto 0); -- 000 H0, 001 H1, 010 H2, 011 PAYLOAD, 100 CHKSUM
    tx_next_is_read_i : in  std_logic;
    rd_payload_i      : in  std_logic_vector(31 downto 0);

    cap_flit_o  : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lout_data_o : out std_logic_vector(c_FLIT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of loopback_control_adapter is
  constant c_RESP_HDR0_CONST : std_logic_vector(31 downto 0) := x"00000000";
  constant c_RESP_HDR1_CONST : std_logic_vector(31 downto 0) := x"00000100";
  constant c_HDR2_WR         : std_logic_vector(31 downto 0) := x"00000001";
  constant c_HDR2_RD         : std_logic_vector(31 downto 0) := x"00000002";
begin
  -- control bit comes from voted controller path; payload comes direct.
  cap_flit_o <= cap_flit_ctrl_i & lin_data_i(c_AXI_DATA_WIDTH-1 downto 0);

  lout_data_o <= ('1' & c_RESP_HDR0_CONST) when tx_flit_sel_i = "000" else
                 ('0' & c_RESP_HDR1_CONST) when tx_flit_sel_i = "001" else
                 ('0' & c_HDR2_RD)         when (tx_flit_sel_i = "010" and tx_next_is_read_i = '1') else
                 ('0' & c_HDR2_WR)         when (tx_flit_sel_i = "010" and tx_next_is_read_i = '0') else
                 ('0' & rd_payload_i)      when tx_flit_sel_i = "011" else
                 ('1' & x"00000000");
end architecture;
