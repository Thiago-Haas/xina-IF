library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity manual_integration is
    generic(
       c_AXI_DATA_WIDTH: natural := 32;
       c_AXI_ID_WIDTH  : natural := 5;
       c_AXI_RESP_WIDTH: natural := 3;
       c_AXI_ADDR_WIDTH: natural := 64
       
    );
    port(
        -- AMBA-AXI 5 signals.
        ACLK  : std_logic;
        ARESETn: std_logic;
        --RESET : std_logic;
        -------------------
        -- MASTER SIGNALS.
        -- Write request signals.
        AWVALID: in std_logic;
        AWREADY: out std_logic;
        AWID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        AWADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        AWLEN  : in std_logic_vector(7 downto 0);
        AWBURST: in std_logic_vector(1 downto 0);

        -- Write data signals.
        WVALID : in std_logic;
        WREADY : out std_logic;
        WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        WLAST  : in std_logic;

        -- Write response signals.
        BVALID : out std_logic;
        BREADY : in std_logic;
        BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

        -- Read request signals.
        ARVALID: in std_logic;
        ARREADY: out std_logic;
        ARID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        ARADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        ARLEN  : in std_logic_vector(7 downto 0);
        ARBURST: in std_logic_vector(1 downto 0);

        -- Read response/data signals.
        RVALID : out std_logic;
        RREADY : in std_logic;
        RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        RLAST  : out std_logic;
        RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

        -- Extra signals.
        CORRUPT_PACKET: out std_logic 
    );
end manual_integration;

architecture Behavioral of manual_integration is

    ------------------------------------------------------------------------------------------------------
    -- SLAVE SIGNALS.

    -- AMBA-AXI 5 signals.
        -- Write request signals.
        signal w2_AWVALID: std_logic := '0';
        signal w2_AWREADY: std_logic := '0';
        signal w2_AWID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal w2_AWADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
        signal w2_AWLEN  : std_logic_vector(7 downto 0) := "00000000";
        signal w2_AWSIZE : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH / 8, 3));
        signal w2_AWBURST: std_logic_vector(1 downto 0) := "01";

        -- Write data signals.
        signal w2_WVALID : std_logic := '0';
        signal w2_WREADY : std_logic := '0';
        signal w2_WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
        signal w2_WLAST  : std_logic := '0';

        -- Write response signals.
        signal w2_BVALID : std_logic := '0';
        signal w2_BREADY : std_logic := '0';
        signal w2_BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal w2_BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Read request signals.
        signal w2_ARVALID: std_logic := '0';
        signal w2_ARREADY: std_logic := '0';
        signal w2_ARID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal w2_ARADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
        signal w2_ARLEN  : std_logic_vector(7 downto 0) := "00000000";
        signal w2_ARSIZE : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH / 8, 3));
        signal w2_ARBURST: std_logic_vector(1 downto 0) := "01";

        -- Read response/data signals.
        signal w2_RVALID : std_logic := '0';
        signal w2_RREADY : std_logic := '0';
        signal w2_RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
        signal w2_RLAST  : std_logic := '0';
        signal w2_RID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal w2_RRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Extra signals.
        signal w2_CORRUPT_PACKET: std_logic;

    ------------------------------------------------------------------------------------------------------
    -- NETWORK SIGNALS.

    -- Signals of master interface.
    signal w_l_in_data_i : std_logic_vector(data_width_c downto 0);
    signal w_l_in_val_i  : std_logic;
    signal w_l_in_ack_o  : std_logic;
    signal w_l_out_data_o: std_logic_vector(data_width_c downto 0);
    signal w_l_out_val_o : std_logic;
    signal w_l_out_ack_i : std_logic;

    -- Signals of slave interface.
    signal w2_l_in_data_i : std_logic_vector(data_width_c downto 0);
    signal w2_l_in_val_i  : std_logic;
    signal w2_l_in_ack_o  : std_logic;
    signal w2_l_out_data_o: std_logic_vector(data_width_c downto 0);
    signal w2_l_out_val_o : std_logic;
    signal w2_l_out_ack_i : std_logic;

    -- Signals of XINA.
    signal l_in_data_i : data_link_l_t;
    signal l_in_val_i  : ctrl_link_l_t;
    signal l_in_ack_o  : ctrl_link_l_t;
    signal l_out_data_o: data_link_l_t;
    signal l_out_val_o : ctrl_link_l_t;
    signal l_out_ack_i : ctrl_link_l_t;

begin

    -- XINA signals.
    l_in_data_i(0, 0) <= w_l_in_data_i;
    l_in_data_i(1, 0) <= w2_l_in_data_i;

    l_in_val_i(0, 0) <= w_l_in_val_i;
    l_in_val_i(1, 0) <= w2_l_in_val_i;

    w_l_in_ack_o <= l_in_ack_o(0, 0);
    w2_l_in_ack_o <= l_in_ack_o(1, 0);

    w_l_out_data_o <= l_out_data_o(0, 0);
    w2_l_out_data_o <= l_out_data_o(1, 0);

    w_l_out_val_o <= l_out_val_o(0, 0);
    w2_l_out_val_o <= l_out_val_o(1, 0);

    l_out_ack_i(0, 0) <= w_l_out_ack_i;
    l_out_ack_i(1, 0) <= w2_l_out_ack_i;

    -- Instances.
    u_TOP_MASTER: entity work.tcc_top_master
    generic map(
            p_SRC_X => "0000000000000000",
            p_SRC_Y => "0000000000000000"
        )
        port map(
            -- AMBA AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,

                -- Write request signals.
                AWVALID => AWVALID,
                AWREADY => AWREADY,
                AWID    => AWID,
                AWADDR  => AWADDR,
                AWLEN   => AWLEN,
                AWBURST => AWBURST,

                -- Write data signals.
                WVALID  => WVALID,
                WREADY  => WREADY,
                WDATA   => WDATA,
                WLAST   => WLAST,

                -- Write response signals.
                BVALID  => BVALID,
                BREADY  => BREADY,
                BID     => BID,
                BRESP   => BRESP,

                -- Read request signals.
                ARVALID => ARVALID,
                ARREADY => ARREADY,
                ARID    => ARID,
                ARADDR  => ARADDR,
                ARLEN   => ARLEN,
                ARBURST => ARBURST,

                -- Read response/data signals.
                RVALID  => RVALID,
                RREADY  => RREADY,
                RDATA   => RDATA,
                RLAST   => RLAST,
                RID     => RID,
                RRESP   => RRESP,

                CORRUPT_PACKET => CORRUPT_PACKET,

            -- XINA signals.
            l_in_data_i  => w_l_in_data_i,
            l_in_val_i   => w_l_in_val_i,
            l_in_ack_o   => w_l_in_ack_o,
            l_out_data_o => w_l_out_data_o,
            l_out_val_o  => w_l_out_val_o,
            l_out_ack_i  => w_l_out_ack_i
        );

    u_TOP_SLAVE: entity work.tcc_top_slave
        generic map(
            p_SRC_X => "0000000000000001",
            p_SRC_Y => "0000000000000000"
        )

        port map(
            -- AMBA AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,

                -- Write request signals.
                AWVALID => w2_AWVALID,
                AWREADY => w2_AWREADY,
                AWID    => w2_AWID,
                AWADDR  => w2_AWADDR,
                AWLEN   => w2_AWLEN,
                AWSIZE  => w2_AWSIZE,
                AWBURST => w2_AWBURST,

                -- Write data signals.
                WVALID  => w2_WVALID,
                WREADY  => w2_WREADY,
                WDATA   => w2_WDATA,
                WLAST   => w2_WLAST,

                -- Write response signals.
                BVALID  => w2_BVALID,
                BREADY  => w2_BREADY,
                BRESP   => w2_BRESP,

                -- Read request signals.
                ARVALID => w2_ARVALID,
                ARREADY => w2_ARREADY,
                ARID    => w2_ARID,
                ARADDR  => w2_ARADDR,
                ARLEN   => w2_ARLEN,
                ARSIZE  => w2_ARSIZE,
                ARBURST => w2_ARBURST,

                -- Read response/data signals.
                RVALID  => w2_RVALID,
                RREADY  => w2_RREADY,
                RDATA   => w2_RDATA,
                RLAST   => w2_RLAST,
                RRESP   => w2_RRESP,

                -- Extra signals.
                CORRUPT_PACKET => w2_CORRUPT_PACKET,

            -- XINA signals.
            l_in_data_i  => w2_l_in_data_i,
            l_in_val_i   => w2_l_in_val_i,
            l_in_ack_o   => w2_l_in_ack_o,

            l_out_data_o => w2_l_out_data_o,
            l_out_val_o  => w2_l_out_val_o,
            l_out_ack_i  => w2_l_out_ack_i
        );

--    u_COMPRESSOR: entity work.ccsds_axifull_v1_0
--        generic map(
--            C_S00_AXI_ID_WIDTH => c_AXI_ID_WIDTH,
--            C_S00_AXI_DATA_WIDTH => c_AXI_DATA_WIDTH,
--            C_S00_AXI_ADDR_WIDTH => c_AXI_ADDR_WIDTH
--        )

--        port map(
--            s00_axi_aclk    => ACLK,
--            s00_axi_aresetn    => RESETn,

--            -- Write request channel.
--            s00_axi_awid    => w2_AWID,
--            s00_axi_awaddr    => w2_AWADDR,
--            s00_axi_awlen   => w2_AWLEN,
--            s00_axi_awsize  => w2_AWSIZE,
--            s00_axi_awburst => w2_AWBURST,
--            s00_axi_awprot    => "000",
--            s00_axi_awvalid    => w2_AWVALID,
--            s00_axi_awready    => w2_AWREADY,

--            -- Write data channel.
--            s00_axi_wdata    => w2_WDATA,
--            s00_axi_wstrb    => "1111",
--            s00_axi_wlast    => w2_WLAST,
--            s00_axi_wvalid    => w2_WVALID,
--            s00_axi_wready    => w2_WREADY,

--            -- Write response channel.
--            s00_axi_bid     => w2_BID,
--            s00_axi_bresp    => w2_BRESP(1 downto 0),
--            s00_axi_bvalid    => w2_BVALID,
--            s00_axi_bready    => w2_BREADY,

--            -- Read request channel.
--            s00_axi_arid    => w2_ARID,
--            s00_axi_araddr    => w2_ARADDR,
--            s00_axi_arlen   => w2_ARLEN,
--            s00_axi_arsize  => w2_ARSIZE,
--            s00_axi_arburst => w2_ARBURST,
--            s00_axi_arprot    => "000",
--            s00_axi_arvalid    => w2_ARVALID,
--            s00_axi_arready    => w2_ARREADY,

--            -- Read data channel.
--            s00_axi_rid      => w2_RID,
--            s00_axi_rdata    => w2_RDATA,
--            s00_axi_rresp    => w2_RRESP(1 downto 0),
--            s00_axi_rlast    => w2_RLAST,
--            s00_axi_rvalid    => w2_RVALID,
--            s00_axi_rready    => w2_RREADY
--        );
        
        u_ADDER: entity work.adder_full_v1_0
        generic map(
            C_S00_AXI_ID_WIDTH => c_AXI_ID_WIDTH,
            C_S00_AXI_DATA_WIDTH => c_AXI_DATA_WIDTH,
            C_S00_AXI_ADDR_WIDTH => c_AXI_ADDR_WIDTH
        )

        port map(
            s00_axi_aclk    => ACLK,
            s00_axi_aresetn => ARESETn,

            -- Write request channel.
            s00_axi_awid    => w2_AWID,
            s00_axi_awaddr    => w2_AWADDR,
            s00_axi_awlen   => w2_AWLEN,
            s00_axi_awsize  => w2_AWSIZE,
            s00_axi_awburst => w2_AWBURST,
            s00_axi_awprot    => "000",
            s00_axi_awvalid    => w2_AWVALID,
            s00_axi_awready    => w2_AWREADY,

            -- Write data channel.
            s00_axi_wdata    => w2_WDATA,
            s00_axi_wstrb    => "1111",
            s00_axi_wlast    => w2_WLAST,
            s00_axi_wvalid    => w2_WVALID,
            s00_axi_wready    => w2_WREADY,

            -- Write response channel.
            s00_axi_bid     => w2_BID,
            s00_axi_bresp    => w2_BRESP(1 downto 0),
            s00_axi_bvalid    => w2_BVALID,
            s00_axi_bready    => w2_BREADY,

            -- Read request channel.
            s00_axi_arid    => w2_ARID,
            s00_axi_araddr    => w2_ARADDR,
            s00_axi_arlen   => w2_ARLEN,
            s00_axi_arsize  => w2_ARSIZE,
            s00_axi_arburst => w2_ARBURST,
            s00_axi_arprot    => "000",
            s00_axi_arvalid    => w2_ARVALID,
            s00_axi_arready    => w2_ARREADY,

            -- Read data channel.
            s00_axi_rid      => w2_RID,
            s00_axi_rdata    => w2_RDATA,
            s00_axi_rresp    => w2_RRESP(1 downto 0),
            s00_axi_rlast    => w2_RLAST,
            s00_axi_rvalid    => w2_RVALID,
            s00_axi_rready    => w2_RREADY
        );

    u_XINA_NETWORK: entity work.xina
        generic map(
            rows_p => 1,
            cols_p => 2
        )

        port map(
            clk_i => ACLK,
            rst_i => not(ARESETn),

            l_in_data_i  => l_in_data_i,
            l_in_val_i   => l_in_val_i,
            l_in_ack_o   => l_in_ack_o,
            l_out_data_o => l_out_data_o,
            l_out_val_o  => l_out_val_o,
            l_out_ack_i  => l_out_ack_i
        );

end Behavioral;
