library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity top_level_manual_integration is
    port(
        -- AMBA-AXI 5 signals.
        ACLK    : in std_logic;
        RESET   : in std_logic;
        ARESETn : in std_logic
    );
end top_level_manual_integration;

architecture Behavioral of top_level_manual_integration is

-- Write request signals.
signal w_AWVALID: std_logic := '0';
signal w_AWREADY: std_logic := '0';
signal w_AWID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal w_AWADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
signal w_AWLEN  : std_logic_vector(7 downto 0) := "00000000";
signal w_AWBURST: std_logic_vector(1 downto 0) := "01";

-- Write data signals.
signal w_WVALID : std_logic := '0';
signal w_WREADY : std_logic := '0';
signal w_WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
signal w_WLAST  : std_logic := '0';

-- Write response signals.
signal w_BVALID : std_logic := '0';
signal w_BREADY : std_logic := '0';
signal w_BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal w_BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

-- Read request signals.
signal w_ARVALID: std_logic := '0';
signal w_ARREADY: std_logic := '0';
signal w_ARID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal w_ARADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
signal w_ARLEN  : std_logic_vector(7 downto 0) := "00000000";
signal w_ARBURST: std_logic_vector(1 downto 0) := "01";

-- Read response/data signals.
signal w_RVALID : std_logic := '0';
signal w_RREADY : std_logic := '0';
signal w_RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
signal w_RLAST  : std_logic := '0';
signal w_RID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal w_RRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

-- Extra signals.
signal w_CORRUPT_PACKET: std_logic;

begin
    u_traffic_generator_for_manual_integration: entity work.traffic_generator_for_manual_integration
      port map(
        -- AMBA-AXI 5 signals.
        ACLK    => ACLK,
        RESET   => RESET,
        ARESETn => ARESETn,
        -------------------
        -- MASTER SIGNALS.
        -- Write request signals.
        AWVALID => w_AWVALID,
        AWREADY => w_AWREADY,
        AWID    => w_AWID,
        AWADDR  => w_AWADDR,
        AWLEN   => w_AWLEN,
        AWBURST => w_AWBURST,
 
         -- Write data signals.
        WVALID => w_WVALID,
        WREADY => w_WREADY,
        WDATA  => w_WDATA,
        WLAST  => w_WLAST,
 
        -- Write response signals.
        BVALID => w_BVALID,
        BREADY => w_BREADY,
        BID    => w_BID,
        BRESP  => w_BRESP,
 
        -- Read request signals.
        ARVALID => w_ARVALID,
        ARREADY => w_ARREADY,
        ARID    => w_ARID,
        ARADDR  => w_ARADDR,
        ARLEN   => w_ARLEN,
        ARBURST => w_ARBURST,
 
        -- Read response/data signals.
        RVALID => w_RVALID,
        RREADY => w_RREADY,
        RDATA  => w_RDATA,
        RLAST  => w_RLAST,
        RID    => w_RID,
        RRESP  => w_RRESP,
 
        -- Extra signals.
        CORRUPT_PACKET => w_CORRUPT_PACKET
    );
    u_manual_integration: entity work.manual_integration
        --generic(
        --    c_AXI_DATA_WIDTH: natural := 32;
        --    c_AXI_ID_WIDTH  : natural := 5;
        --    c_AXI_RESP_WIDTH: natural := 3;
        --    c_AXI_ADDR_WIDTH: natural := 64
        --);
        port map(
            -- AMBA-AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,
            --RESET   => RESET,
            -------------------
            -- MASTER SIGNALS.
            -- Write request signals.
            AWVALID  => w_AWVALID,
            AWREADY  => w_AWREADY,
            AWID     => w_AWID,
            AWADDR   => w_AWADDR,
            AWLEN    => w_AWLEN,
            AWBURST  => w_AWBURST,
    
            -- Write data signals.
            WVALID  => w_WVALID,
            WREADY  => w_WREADY,
            WDATA   => w_WDATA,
            WLAST   => w_WLAST,
    
            -- Write response signals.
            BVALID  => w_BVALID,
            BREADY  => w_BREADY,
            BID     => w_BID,
            BRESP   => w_BRESP,
    
            -- Read request signals.
            ARVALID  => w_ARVALID,
            ARREADY  => w_ARREADY,
            ARID     => w_ARID,
            ARADDR   => w_ARADDR,
            ARLEN    => w_ARLEN,
            ARBURST  => w_ARBURST,
    
            -- Read response/data signals.
            RVALID  => w_RVALID,
            RREADY  => w_RREADY,
            RDATA   => w_RDATA,
            RLAST   => w_RLAST,
            RID     => w_RID,
            RRESP   => w_RRESP,
    
            -- Extra signals.
            CORRUPT_PACKET => w_CORRUPT_PACKET
        );

end Behavioral;
