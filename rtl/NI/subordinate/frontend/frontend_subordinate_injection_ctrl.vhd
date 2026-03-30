library IEEE;
use IEEE.std_logic_1164.all;

entity frontend_subordinate_injection_ctrl is
    port(
        BVALID_i : in std_logic;
        RVALID_i : in std_logic;
        RLAST_i  : in std_logic;

        READY_SEND_DATA_i : in std_logic;
        OPC_RECEIVE_i     : in std_logic;

        VALID_SEND_DATA_o : out std_logic;
        LAST_SEND_DATA_o  : out std_logic;

        BREADY_o : out std_logic;
        RREADY_o : out std_logic
    );
end frontend_subordinate_injection_ctrl;

architecture rtl of frontend_subordinate_injection_ctrl is
    signal valid_send_data_w : std_logic;
    signal last_send_data_w  : std_logic;
    signal bready_w          : std_logic;
    signal rready_w          : std_logic;

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of valid_send_data_w : signal is "TRUE";
    attribute DONT_TOUCH of last_send_data_w : signal is "TRUE";
    attribute DONT_TOUCH of bready_w : signal is "TRUE";
    attribute DONT_TOUCH of rready_w : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of valid_send_data_w : signal is true;
    attribute syn_preserve of last_send_data_w : signal is true;
    attribute syn_preserve of bready_w : signal is true;
    attribute syn_preserve of rready_w : signal is true;
begin
    valid_send_data_w <= '1' when (BVALID_i = '1' or RVALID_i = '1') else '0';
    last_send_data_w  <= RLAST_i;

    bready_w <= '1' when (OPC_RECEIVE_i = '0' and READY_SEND_DATA_i = '1') else '0';
    rready_w <= '1' when (OPC_RECEIVE_i = '1' and READY_SEND_DATA_i = '1') else '0';

    VALID_SEND_DATA_o <= valid_send_data_w;
    LAST_SEND_DATA_o  <= last_send_data_w;
    BREADY_o          <= bready_w;
    RREADY_o          <= rready_w;
end rtl;
