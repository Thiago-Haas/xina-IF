library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_subordinate_packetizer_datapath is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0)
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        DATA_SEND_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        STATUS_SEND_i  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        H_SRC_RECEIVE_i: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        H_INTERFACE_RECEIVE_i: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        FLIT_SELECTOR_i: in std_logic_vector(2 downto 0);
        CHECKSUM_i     : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        FLIT_o: out std_logic_vector(c_FLIT_WIDTH - 1 downto 0)
    );
end backend_subordinate_packetizer_datapath;

architecture rtl of backend_subordinate_packetizer_datapath is
    signal FLIT_H_DEST_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal FLIT_H_SRC_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal FLIT_H_INTERFACE_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal FLIT_PAYLOAD_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal FLIT_TRAILER_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    signal ID_w: std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal LENGTH_w: std_logic_vector(7 downto 0);
    signal BURST_w : std_logic_vector(1 downto 0);
    signal OPC_w   : std_logic;

begin
    ID_w     <= H_INTERFACE_RECEIVE_i(19 downto 15);
    LENGTH_w <= H_INTERFACE_RECEIVE_i(14 downto 7);
    BURST_w  <= H_INTERFACE_RECEIVE_i(6 downto 5);
    OPC_w    <= H_INTERFACE_RECEIVE_i(1);

    FLIT_H_DEST_w <= '1' & H_SRC_RECEIVE_i(31 downto 0);
    FLIT_H_SRC_w  <= '0' & p_SRC_X & p_SRC_Y;
    FLIT_H_INTERFACE_w <= '0' & "000000000000" & ID_w & LENGTH_w & BURST_w & STATUS_SEND_i & OPC_w & "1";
    FLIT_PAYLOAD_w  <= '0' & DATA_SEND_i;
    FLIT_TRAILER_w  <= '1' & CHECKSUM_i;

    process (FLIT_H_DEST_w, FLIT_H_SRC_w, FLIT_H_INTERFACE_w, FLIT_PAYLOAD_w, FLIT_TRAILER_w, FLIT_SELECTOR_i)
    begin
        case FLIT_SELECTOR_i is
            when "000" =>
                FLIT_o <= FLIT_H_DEST_w;
            when "001" =>
                FLIT_o <= FLIT_H_SRC_w;
            when "010" =>
                FLIT_o <= FLIT_H_INTERFACE_w;
            when "011" =>
                FLIT_o <= FLIT_PAYLOAD_w;
            when "100" =>
                FLIT_o <= FLIT_TRAILER_w;
            when others =>
                FLIT_o <= (others => '0');
        end case;
    end process;
end rtl;
