library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity frontend_subordinate is
    port(
        -- AMBA AXI 5 signals.
        ACLK: in std_logic;
        ARESETn: in std_logic;

            -- Write request signals.
            AWVALID: out std_logic;
            AWREADY: in std_logic;
            AWID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
            AWADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
            AWLEN  : out std_logic_vector(7 downto 0) := (others => '0');
            AWSIZE : out std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH / 8, 3));
            AWBURST: out std_logic_vector(1 downto 0) := "01";

            -- Write data signals.
            WVALID : out std_logic;
            WREADY : in std_logic;
            WDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
            WLAST  : out std_logic;

            -- Write response signals.
            BVALID : in std_logic;
            BREADY : out std_logic;
            BID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
            BRESP  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

            -- Read request signals.
            ARVALID: out std_logic;
            ARREADY: in std_logic;
            ARID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
            ARADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
            ARLEN  : out std_logic_vector(7 downto 0) := (others => '0');
            ARSIZE : out std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH / 8, 3));
            ARBURST: out std_logic_vector(1 downto 0) := "01";

            -- Read response/data signals.
            RVALID : in std_logic;
            RREADY : out std_logic;
            RDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
            RLAST  : in std_logic;
            RID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
            RRESP  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

            -- Extra signals.
            CORRUPT_PACKET: out std_logic;

        -- Backend signals (injection).
        READY_SEND_DATA_i: in std_logic;
        VALID_SEND_DATA_o: out std_logic;
        LAST_SEND_DATA_o : out std_logic;

        DATA_SEND_o  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        STATUS_SEND_o: out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

        -- Backend signals (reception).
        VALID_RECEIVE_PACKET_i: in std_logic;
        VALID_RECEIVE_DATA_i  : in std_logic;
        LAST_RECEIVE_DATA_i   : in std_logic;

        ID_RECEIVE_i     : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        LEN_RECEIVE_i    : in std_logic_vector(7 downto 0);
        BURST_RECEIVE_i  : in std_logic_vector(1 downto 0);
        OPC_RECEIVE_i    : in std_logic;
        ADDRESS_RECEIVE_i: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        DATA_RECEIVE_i   : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        CORRUPT_RECEIVE_i: in std_logic;

        READY_RECEIVE_PACKET_o: out std_logic;
        READY_RECEIVE_DATA_o  : out std_logic
    );
end frontend_subordinate;

architecture rtl of frontend_subordinate is
    signal valid_send_data_w : std_logic;
    signal last_send_data_w  : std_logic;
    signal data_send_w       : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal status_send_w     : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    signal ready_receive_packet_w : std_logic;
    signal ready_receive_data_w   : std_logic;
    signal awvalid_en_w           : std_logic;
    signal wvalid_en_w            : std_logic;
    signal arvalid_en_w           : std_logic;

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of valid_send_data_w : signal is "TRUE";
    attribute DONT_TOUCH of last_send_data_w : signal is "TRUE";
    attribute DONT_TOUCH of data_send_w : signal is "TRUE";
    attribute DONT_TOUCH of status_send_w : signal is "TRUE";
    attribute DONT_TOUCH of ready_receive_packet_w : signal is "TRUE";
    attribute DONT_TOUCH of ready_receive_data_w : signal is "TRUE";
    attribute DONT_TOUCH of awvalid_en_w : signal is "TRUE";
    attribute DONT_TOUCH of wvalid_en_w : signal is "TRUE";
    attribute DONT_TOUCH of arvalid_en_w : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of valid_send_data_w : signal is true;
    attribute syn_preserve of last_send_data_w : signal is true;
    attribute syn_preserve of data_send_w : signal is true;
    attribute syn_preserve of status_send_w : signal is true;
    attribute syn_preserve of ready_receive_packet_w : signal is true;
    attribute syn_preserve of ready_receive_data_w : signal is true;
    attribute syn_preserve of awvalid_en_w : signal is true;
    attribute syn_preserve of wvalid_en_w : signal is true;
    attribute syn_preserve of arvalid_en_w : signal is true;
begin
    u_frontend_subordinate_injection_ctrl: entity work.frontend_subordinate_injection_ctrl
        port map(
            BVALID_i => BVALID,
            RVALID_i => RVALID,
            RLAST_i  => RLAST,

            READY_SEND_DATA_i => READY_SEND_DATA_i,
            OPC_RECEIVE_i     => OPC_RECEIVE_i,

            VALID_SEND_DATA_o => valid_send_data_w,
            LAST_SEND_DATA_o  => last_send_data_w,

            BREADY_o => BREADY,
            RREADY_o => RREADY
        );

    u_frontend_subordinate_injection_dp: entity work.frontend_subordinate_injection_dp
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            VALID_SEND_DATA_i => valid_send_data_w,
            BVALID_i          => BVALID,
            BRESP_i           => BRESP,
            RVALID_i          => RVALID,
            RRESP_i           => RRESP,
            RDATA_i           => RDATA,

            DATA_SEND_o   => data_send_w,
            STATUS_SEND_o => status_send_w
        );

    u_frontend_subordinate_reception_ctrl: entity work.frontend_subordinate_reception_ctrl
        port map(
            OPC_RECEIVE_i          => OPC_RECEIVE_i,
            VALID_RECEIVE_PACKET_i => VALID_RECEIVE_PACKET_i,
            VALID_RECEIVE_DATA_i   => VALID_RECEIVE_DATA_i,

            AWREADY_i => AWREADY,
            ARREADY_i => ARREADY,
            WREADY_i  => WREADY,

            READY_RECEIVE_PACKET_o => ready_receive_packet_w,
            READY_RECEIVE_DATA_o   => ready_receive_data_w,

            AWVALID_EN_o => awvalid_en_w,
            WVALID_EN_o  => wvalid_en_w,
            ARVALID_EN_o => arvalid_en_w
        );

    u_frontend_subordinate_reception_dp: entity work.frontend_subordinate_reception_dp
        port map(
            VALID_RECEIVE_DATA_i => VALID_RECEIVE_DATA_i,
            LAST_RECEIVE_DATA_i  => LAST_RECEIVE_DATA_i,

            ID_RECEIVE_i      => ID_RECEIVE_i,
            LEN_RECEIVE_i     => LEN_RECEIVE_i,
            BURST_RECEIVE_i   => BURST_RECEIVE_i,
            OPC_RECEIVE_i     => OPC_RECEIVE_i,
            ADDRESS_RECEIVE_i => ADDRESS_RECEIVE_i,
            DATA_RECEIVE_i    => DATA_RECEIVE_i,
            CORRUPT_RECEIVE_i => CORRUPT_RECEIVE_i,

            AWVALID_EN_i => awvalid_en_w,
            WVALID_EN_i  => wvalid_en_w,
            ARVALID_EN_i => arvalid_en_w,

            AWVALID_o => AWVALID,
            AWID_o    => AWID,
            AWADDR_o  => AWADDR,
            AWLEN_o   => AWLEN,
            AWBURST_o => AWBURST,

            WVALID_o => WVALID,
            WDATA_o  => WDATA,
            WLAST_o  => WLAST,

            ARVALID_o => ARVALID,
            ARID_o    => ARID,
            ARADDR_o  => ARADDR,
            ARLEN_o   => ARLEN,
            ARBURST_o => ARBURST,

            CORRUPT_PACKET_o => CORRUPT_PACKET
        );

    VALID_SEND_DATA_o     <= valid_send_data_w;
    LAST_SEND_DATA_o      <= last_send_data_w;
    DATA_SEND_o           <= data_send_w;
    STATUS_SEND_o         <= status_send_w;
    READY_RECEIVE_PACKET_o <= ready_receive_packet_w;
    READY_RECEIVE_DATA_o   <= ready_receive_data_w;
end rtl;
