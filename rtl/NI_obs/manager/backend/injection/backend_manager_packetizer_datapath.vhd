library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_packetizer_datapath is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0)
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        i_OPC_ADDR : in std_logic_vector((c_AXI_ADDR_WIDTH / 2) - 1 downto 0);
        i_ID       : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        i_LENGTH   : in std_logic_vector(7 downto 0);
        i_BURST    : in std_logic_vector(1 downto 0);
        i_OPC_SEND : in std_logic;
        i_DATA_SEND: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        i_DEST_X       : in std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        i_DEST_Y       : in std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        i_FLIT_SELECTOR: in std_logic_vector(2 downto 0);
        i_CHECKSUM     : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        o_FLIT: out std_logic_vector(c_FLIT_WIDTH - 1 downto 0)
    );
end backend_manager_packetizer_datapath;

architecture rtl of backend_manager_packetizer_datapath is
    signal w_FLIT_H_DEST: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal w_FLIT_H_SRC : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal w_FLIT_H_INTERFACE: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal w_FLIT_H_ADDRESS: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    signal w_FLIT_PAYLOAD : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal w_FLIT_TRAILER : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

begin
    w_FLIT_H_DEST      <= '1' & i_DEST_X & i_DEST_Y;
    w_FLIT_H_SRC       <= '0' & p_SRC_X  & p_SRC_Y;
    w_FLIT_H_INTERFACE <= '0' & "000000000000" & i_ID & i_LENGTH & i_BURST & "000" & i_OPC_SEND & "0";
    w_FLIT_H_ADDRESS   <= '0' & i_OPC_ADDR;

    w_FLIT_PAYLOAD <= '0' & i_DATA_SEND;
    w_FLIT_TRAILER <= '1' & i_CHECKSUM;

    process (w_FLIT_H_DEST, w_FLIT_H_SRC, w_FLIT_H_INTERFACE, w_FLIT_H_ADDRESS, w_FLIT_PAYLOAD, w_FLIT_TRAILER, i_FLIT_SELECTOR)
    begin
        case i_FLIT_SELECTOR is
            when "000" =>
                o_FLIT <= w_FLIT_H_DEST;
            when "001" =>
                o_FLIT <= w_FLIT_H_SRC;
            when "010" =>
                o_FLIT <= w_FLIT_H_INTERFACE;
            when "011" =>
                o_FLIT <= w_FLIT_H_ADDRESS;
            when "100" =>
                o_FLIT <= w_FLIT_PAYLOAD;
            when "101" =>
                o_FLIT <= w_FLIT_TRAILER;
            when others =>
                o_FLIT <= (others => '0');
        end case;
    end process;
end rtl;
