library IEEE;
use IEEE.std_logic_1164.all;

entity frontend_subordinate_reception_ctrl is
    port(
        OPC_RECEIVE_i          : in std_logic;
        VALID_RECEIVE_PACKET_i : in std_logic;
        VALID_RECEIVE_DATA_i   : in std_logic;

        AWREADY_i : in std_logic;
        ARREADY_i : in std_logic;
        WREADY_i  : in std_logic;

        READY_RECEIVE_PACKET_o : out std_logic;
        READY_RECEIVE_DATA_o   : out std_logic;

        AWVALID_EN_o : out std_logic;
        WVALID_EN_o  : out std_logic;
        ARVALID_EN_o : out std_logic
    );
end frontend_subordinate_reception_ctrl;

architecture rtl of frontend_subordinate_reception_ctrl is
    signal ready_receive_packet_w : std_logic;
    signal ready_receive_data_w   : std_logic;
    signal awvalid_en_w           : std_logic;
    signal wvalid_en_w            : std_logic;
    signal arvalid_en_w           : std_logic;

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of ready_receive_packet_w : signal is "TRUE";
    attribute DONT_TOUCH of ready_receive_data_w : signal is "TRUE";
    attribute DONT_TOUCH of awvalid_en_w : signal is "TRUE";
    attribute DONT_TOUCH of wvalid_en_w : signal is "TRUE";
    attribute DONT_TOUCH of arvalid_en_w : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of ready_receive_packet_w : signal is true;
    attribute syn_preserve of ready_receive_data_w : signal is true;
    attribute syn_preserve of awvalid_en_w : signal is true;
    attribute syn_preserve of wvalid_en_w : signal is true;
    attribute syn_preserve of arvalid_en_w : signal is true;
begin
    ready_receive_packet_w <= '1' when (OPC_RECEIVE_i = '0' and AWREADY_i = '1') or
                                       (OPC_RECEIVE_i = '1' and ARREADY_i = '1') else '0';
    ready_receive_data_w <= WREADY_i;

    awvalid_en_w <= '1' when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_PACKET_i = '1') else '0';
    wvalid_en_w  <= '1' when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_DATA_i = '1') else '0';
    arvalid_en_w <= '1' when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_PACKET_i = '1') else '0';

    READY_RECEIVE_PACKET_o <= ready_receive_packet_w;
    READY_RECEIVE_DATA_o   <= ready_receive_data_w;
    AWVALID_EN_o           <= awvalid_en_w;
    WVALID_EN_o            <= wvalid_en_w;
    ARVALID_EN_o           <= arvalid_en_w;
end rtl;
