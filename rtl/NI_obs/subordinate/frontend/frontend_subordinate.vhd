library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

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
    signal VALID_SEND_DATA_w: std_logic;
    signal STATUS_SEND_r_w : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

begin
    ---------------------------------------------------------------------------------------------
    -- Injection.

    -- Registering transaction information.
    registering: process(all)
    begin
        if (rising_edge(ACLK)) then
            if (VALID_SEND_DATA_w = '1') then
                if (BVALID = '1') then
                    -- Registering write signals.
                    STATUS_SEND_r_w <= BRESP;
                elsif (RVALID = '1') then
                    -- Registering read signals.
                    STATUS_SEND_r_w <= RRESP;
                end if;
            end if;
        end if;
    end process registering;

    STATUS_SEND_o <= STATUS_SEND_r_w;

    -- Control information.
    VALID_SEND_DATA_w   <= '1' when (BVALID = '1' or RVALID = '1') else '0';
    VALID_SEND_DATA_o   <= VALID_SEND_DATA_w;

    LAST_SEND_DATA_o    <= RLAST;
    DATA_SEND_o         <= RDATA when (RVALID = '1') else (c_AXI_DATA_WIDTH - 1 downto 0 => '0');

    -- Ready information to IP.
    BREADY <= '1' when (OPC_RECEIVE_i = '0' and READY_SEND_DATA_i = '1') else '0';
    RREADY <= '1' when (OPC_RECEIVE_i = '1' and READY_SEND_DATA_i = '1') else '0';

    ---------------------------------------------------------------------------------------------
    -- Reception.
    READY_RECEIVE_PACKET_o <= '1' when (OPC_RECEIVE_i = '0' and AWREADY = '1') or
                                       (OPC_RECEIVE_i = '1' and ARREADY = '1') else '0';
    READY_RECEIVE_DATA_o   <= WREADY;

    AWVALID <= '1' when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_PACKET_i = '1') else '0';
    AWID    <= ID_RECEIVE_i when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_PACKET_i = '1') else (c_AXI_ID_WIDTH - 1 downto 0 => '0');
    AWADDR  <= ADDRESS_RECEIVE_i & (0 to c_AXI_DATA_WIDTH - 1 => '0') when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_PACKET_i = '1') else (c_AXI_ADDR_WIDTH - 1 downto 0 => '0');
    AWLEN   <= LEN_RECEIVE_i when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_PACKET_i = '1') else (7 downto 0 => '0');
    AWBURST <= BURST_RECEIVE_i when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_PACKET_i = '1') else (1 downto 0 => '0');

    WVALID <= '1' when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_DATA_i = '1') else '0';
    WDATA  <= DATA_RECEIVE_i when (VALID_RECEIVE_DATA_i = '1') else (c_AXI_DATA_WIDTH - 1 downto 0 => '0');
    WLAST  <= LAST_RECEIVE_DATA_i;

    ARVALID <= '1' when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_PACKET_i = '1') else '0';
    ARID    <= ID_RECEIVE_i when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_PACKET_i = '1') else (c_AXI_ID_WIDTH - 1 downto 0 => '0');
    ARADDR  <= ADDRESS_RECEIVE_i & (0 to c_AXI_DATA_WIDTH - 1 => '0') when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_PACKET_i = '1') else (c_AXI_ADDR_WIDTH - 1 downto 0 => '0');
    ARLEN   <= LEN_RECEIVE_i when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_PACKET_i = '1') else (7 downto 0 => '0');
    ARBURST <= BURST_RECEIVE_i when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_PACKET_i = '1') else (1 downto 0 => '0');

    CORRUPT_PACKET <= CORRUPT_RECEIVE_i;
end rtl;
