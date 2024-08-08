library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_ft_pkg.all;

entity NI_shell_integration is
    generic(
        -- AMBA-AXI attributes.
        c_AXI_DATA_WIDTH: natural := 32;
        c_AXI_ID_WIDTH  : natural := 5;
        c_AXI_RESP_WIDTH: natural := 3;
        c_AXI_ADDR_WIDTH: natural := 64;
        -- Interface attributes.
        c_FLIT_WIDTH        : natural  := c_AXI_DATA_WIDTH + 1;
        c_BUFFER_DEPTH      : positive := 8;
        c_USE_HAMMING       : boolean  := true;
        c_USE_INTEGRITY     : boolean  := true;
        c_USE_TMR_PACKETIZER: boolean  := true;
        c_USE_TMR_FLOW      : boolean  := true;
        c_USE_TMR_INTEGRITY : boolean  := false
    );
    port(
        -- AMBA-AXI 5 signals.
        ACLK  : std_logic;
        ARESETn: std_logic;
------------------------------------------------------------------------------------------------------
        -- TOP MASTER OUTPUT SIGNALS.
        
            -- Write request signals.
    t00_AWVALID: in std_logic;
    t00_AWREADY: out std_logic;
    t00_AWID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    t00_AWADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    t00_AWLEN  : in std_logic_vector(7 downto 0);
    t00_AWBURST: in std_logic_vector(1 downto 0);

    -- Write data signals.
    t00_WVALID : in std_logic;
    t00_WREADY : out std_logic;
    t00_WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    t00_WLAST  : in std_logic;

    -- Write response signals.
    t00_BVALID : out std_logic;
    t00_BREADY : in std_logic;
    t00_BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    t00_BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    -- Read request signals.
    t00_ARVALID: in std_logic;
    t00_ARREADY: out std_logic;
    t00_ARID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    t00_ARADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    t00_ARLEN  : in std_logic_vector(7 downto 0);
    t00_ARBURST: in std_logic_vector(1 downto 0);

    -- Read response/data signals.
    t00_RVALID : out std_logic;
    t00_RREADY : in std_logic;
    t00_RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    t00_RLAST  : out std_logic;
    t00_RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    t00_RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    -- Extra signals.
    t00_CORRUPT_PACKET: out std_logic
-- INSERT_TOP_MASTER_OUTPUT_HERE --
        
------------------------------------------------------------------------------------------------------
    );
end NI_shell_integration;

architecture Behavioral of NI_shell_integration is

------------------------------------------------------------------------------------------------------
    -- TOP AXI SIGNALS.

    -- INSERT_TOP_AXI_SIGNALS_HERE --

------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
    -- AXI SIGNALS.

        --SLAVE--
    -- AMBA-AXI 5 signals.
    -- Write request signals.
    signal w10_AWVALID: std_logic := '0';
    signal w10_AWREADY: std_logic := '0';
    signal w10_AWID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    signal w10_AWADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal w10_AWLEN  : std_logic_vector(7 downto 0) := "00000000";
    signal w10_AWSIZE : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH / 8, 3));
    signal w10_AWBURST: std_logic_vector(1 downto 0) := "01";
    
    -- Write data signals.
    signal w10_WVALID : std_logic := '0';
    signal w10_WREADY : std_logic := '0';
    signal w10_WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal w10_WLAST  : std_logic := '0';
    
    -- Write response signals.
    signal w10_BVALID : std_logic := '0';
    signal w10_BREADY : std_logic := '0';
    signal w10_BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    signal w10_BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
    
    -- Read request signals.
    signal w10_ARVALID: std_logic := '0';
    signal w10_ARREADY: std_logic := '0';
    signal w10_ARID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    signal w10_ARADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal w10_ARLEN  : std_logic_vector(7 downto 0) := "00000000";
    signal w10_ARSIZE : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH / 8, 3));
    signal w10_ARBURST: std_logic_vector(1 downto 0) := "01";
    
    -- Read response/data signals.
    signal w10_RVALID : std_logic := '0';
    signal w10_RREADY : std_logic := '0';
    signal w10_RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal w10_RLAST  : std_logic := '0';
    signal w10_RID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    signal w10_RRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
    
    -- Extra signals.
    signal w10_CORRUPT_PACKET: std_logic;

-- INSERT_AXI_SIGNALS_HERE --

------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
    -- TOP NETWORK SIGNALS.

    signal t00_l_in_data_i : std_logic_vector(data_width_c downto 0);
    signal t00_l_in_val_i  : std_logic;
    signal t00_l_in_ack_o  : std_logic;
    signal t00_l_out_data_o: std_logic_vector(data_width_c downto 0);
    signal t00_l_out_val_o : std_logic;
    signal t00_l_out_ack_i : std_logic;

-- INSERT_TOP_SIGNALS_HERE --

------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
    -- NETWORK SIGNALS.

        signal w10_l_in_data_i : std_logic_vector(data_width_c downto 0);
    signal w10_l_in_val_i  : std_logic;
    signal w10_l_in_ack_o  : std_logic;
    signal w10_l_out_data_o: std_logic_vector(data_width_c downto 0);
    signal w10_l_out_val_o : std_logic;
    signal w10_l_out_ack_i : std_logic;

-- INSERT_SIGNALS_HERE --

------------------------------------------------------------------------------------------------------
    
    -- Local signals of XINA.
    signal l_in_data_i : data_link_l_t;
    signal l_in_val_i  : ctrl_link_l_t;
    signal l_in_ack_o  : ctrl_link_l_t;
    signal l_out_data_o: data_link_l_t;
    signal l_out_val_o : ctrl_link_l_t;
    signal l_out_ack_i : ctrl_link_l_t;

begin

------------------------------------------------------------------------------------------------------
    -- TOP XINA signals.

        l_in_data_i(0, 0) <= t00_l_in_data_i;
    l_in_val_i(0, 0)  <= t00_l_in_val_i;
    t00_l_in_ack_o    <= l_in_ack_o(0, 0);
    t00_l_out_data_o  <= l_out_data_o(0, 0);
    t00_l_out_val_o   <= l_out_val_o(0, 0);
    l_out_ack_i(0, 0) <= t00_l_out_ack_i;

-- INSERT_TOP_XINA_SIGNALS_HERE --

------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
    -- XINA signals.

        l_in_data_i(1, 0) <= w10_l_in_data_i;
    l_in_val_i(1, 0)  <= w10_l_in_val_i;
    w10_l_in_ack_o    <= l_in_ack_o(1, 0);
    w10_l_out_data_o  <= l_out_data_o(1, 0);
    w10_l_out_val_o   <= l_out_val_o(1, 0);
    l_out_ack_i(1, 0) <= w10_l_out_ack_i;
-- INSERT_XINA_SIGNALS_HERE --

------------------------------------------------------------------------------------------------------

    u_xina_ft: entity work.xina_ft
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

------------------------------------------------------------------------------------------------------
    -- TOP NIs.

        -- Instances.
    t00_TOP_MASTER: entity work.tcc_top_master
    generic map(
            p_SRC_X => "0000000000000000",
            p_SRC_Y => "0000000000000000"
        )
        port map(
            -- AMBA AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,

                -- Write request signals.
                AWVALID => t00_AWVALID,
                AWREADY => t00_AWREADY,
                AWID    => t00_AWID,
                AWADDR  => t00_AWADDR,
                AWLEN   => t00_AWLEN,
                AWBURST => t00_AWBURST,

                -- Write data signals.
                WVALID  => t00_WVALID,
                WREADY  => t00_WREADY,
                WDATA   => t00_WDATA,
                WLAST   => t00_WLAST,

                -- Write response signals.
                BVALID  => t00_BVALID,
                BREADY  => t00_BREADY,
                BID     => t00_BID,
                BRESP   => t00_BRESP,

                -- Read request signals.
                ARVALID => t00_ARVALID,
                ARREADY => t00_ARREADY,
                ARID    => t00_ARID,
                ARADDR  => t00_ARADDR,
                ARLEN   => t00_ARLEN,
                ARBURST => t00_ARBURST,

                -- Read response/data signals.
                RVALID  => t00_RVALID,
                RREADY  => t00_RREADY,
                RDATA   => t00_RDATA,
                RLAST   => t00_RLAST,
                RID     => t00_RID,
                RRESP   => t00_RRESP,

                CORRUPT_PACKET => t00_CORRUPT_PACKET,

            -- XINA signals.
            l_in_data_i  => t00_l_in_data_i,
            l_in_val_i   => t00_l_in_val_i,
            l_in_ack_o   => t00_l_in_ack_o,
            l_out_data_o => t00_l_out_data_o,
            l_out_val_o  => t00_l_out_val_o,
            l_out_ack_i  => t00_l_out_ack_i
        );
-- INSERT_TOP_NI_HERE --

------------------------------------------------------------------------------------------------------
    
------------------------------------------------------------------------------------------------------
    -- NIs.

    w10_TOP_SLAVE: entity work.tcc_top_slave
        generic map(
            p_SRC_X => "0000000000000001",
            p_SRC_Y => "0000000000000000"
        )

        port map(
            -- AMBA AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,

            -- Write request signals.
            AWVALID => w10_AWVALID,
            AWREADY => w10_AWREADY,
            AWID    => w10_AWID,
            AWADDR  => w10_AWADDR,
            AWLEN   => w10_AWLEN,
            AWSIZE  => w10_AWSIZE,
            AWBURST => w10_AWBURST,

            -- Write data signals.
            WVALID  => w10_WVALID,
            WREADY  => w10_WREADY,
            WDATA   => w10_WDATA,
            WLAST   => w10_WLAST,

            -- Write response signals.
            BVALID  => w10_BVALID,
            BREADY  => w10_BREADY,
            BRESP   => w10_BRESP,

            -- Read request signals.
            ARVALID => w10_ARVALID,
            ARREADY => w10_ARREADY,
            ARID    => w10_ARID,
            ARADDR  => w10_ARADDR,
            ARLEN   => w10_ARLEN,
            ARSIZE  => w10_ARSIZE,
            ARBURST => w10_ARBURST,

            -- Read response/data signals.
            RVALID  => w10_RVALID,
            RREADY  => w10_RREADY,
            RDATA   => w10_RDATA,
            RLAST   => w10_RLAST,
            RRESP   => w10_RRESP,

            -- Extra signals.
            CORRUPT_PACKET => w10_CORRUPT_PACKET,

            -- XINA signals.
            l_in_data_i  => w10_l_in_data_i,
            l_in_val_i   => w10_l_in_val_i,
            l_in_ack_o   => w10_l_in_ack_o,

            l_out_data_o => w10_l_out_data_o,
            l_out_val_o  => w10_l_out_val_o,
            l_out_ack_i  => w10_l_out_ack_i
        );
-- INSERT_NI_HERE --

------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
    -- TOP AXI COMPONENTS.

    -- INSERT_TOP_AXI_COMPONENTS_HERE --

------------------------------------------------------------------------------------------------------
    
------------------------------------------------------------------------------------------------------
    -- AXI COMPONENTS.

        w10_ADDER: entity work.adder_full_v1_0
        generic map(
            C_S00_AXI_ID_WIDTH   => c_AXI_ID_WIDTH,
            C_S00_AXI_DATA_WIDTH => c_AXI_DATA_WIDTH,
            C_S00_AXI_ADDR_WIDTH => c_AXI_ADDR_WIDTH
        )

        port map(
            s00_axi_aclk    => ACLK,
            s00_axi_aresetn => ARESETn,

            -- Write request channel.
            s00_axi_awid    => w10_AWID,
            s00_axi_awaddr  => w10_AWADDR,
            s00_axi_awlen   => w10_AWLEN,
            s00_axi_awsize  => w10_AWSIZE,
            s00_axi_awburst => w10_AWBURST,
            s00_axi_awprot  => "000",
            s00_axi_awvalid => w10_AWVALID,
            s00_axi_awready => w10_AWREADY,

            -- Write data channel.
            s00_axi_wdata  => w10_WDATA,
            s00_axi_wstrb  => "1111",
            s00_axi_wlast  => w10_WLAST,
            s00_axi_wvalid => w10_WVALID,
            s00_axi_wready => w10_WREADY,

            -- Write response channel.
            s00_axi_bid    => w10_BID,
            s00_axi_bresp  => w10_BRESP(1 downto 0),
            s00_axi_bvalid => w10_BVALID,
            s00_axi_bready => w10_BREADY,

            -- Read request channel.
            s00_axi_arid    => w10_ARID,
            s00_axi_araddr  => w10_ARADDR,
            s00_axi_arlen   => w10_ARLEN,
            s00_axi_arsize  => w10_ARSIZE,
            s00_axi_arburst => w10_ARBURST,
            s00_axi_arprot  => "000",
            s00_axi_arvalid => w10_ARVALID,
            s00_axi_arready => w10_ARREADY,

            -- Read data channel.
            s00_axi_rid    => w10_RID,
            s00_axi_rdata  => w10_RDATA,
            s00_axi_rresp  => w10_RRESP(1 downto 0),
            s00_axi_rlast  => w10_RLAST,
            s00_axi_rvalid => w10_RVALID,
            s00_axi_rready => w10_RREADY
        );
-- INSERT_AXI_COMPONENTS_HERE --

------------------------------------------------------------------------------------------------------
    

end Behavioral;

