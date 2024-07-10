library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_manual_integration_v1_0_S00_AXI is
end tb_manual_integration_v1_0_S00_AXI;

architecture behavior of tb_manual_integration_v1_0_S00_AXI is

    -- Component Declaration for the Unit Under Test (UUT)
    component manual_integration_v1_0_S00_AXI is
        generic (
            C_S_AXI_ID_WIDTH : integer := 1;
            C_S_AXI_DATA_WIDTH : integer := 32;
            C_S_AXI_ADDR_WIDTH : integer := 6;
            C_S_AXI_AWUSER_WIDTH : integer := 0;
            C_S_AXI_ARUSER_WIDTH : integer := 0;
            C_S_AXI_WUSER_WIDTH : integer := 0;
            C_S_AXI_RUSER_WIDTH : integer := 0;
            C_S_AXI_BUSER_WIDTH : integer := 0
        );
        port (
            S_AXI_ACLK : in std_logic;
            S_AXI_ARESETN : in std_logic;
            S_AXI_AWID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
            S_AXI_AWADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            S_AXI_AWLEN : in std_logic_vector(7 downto 0);
            S_AXI_AWSIZE : in std_logic_vector(2 downto 0);
            S_AXI_AWBURST : in std_logic_vector(1 downto 0);
            S_AXI_AWLOCK : in std_logic;
            S_AXI_AWCACHE : in std_logic_vector(3 downto 0);
            S_AXI_AWPROT : in std_logic_vector(2 downto 0);
            S_AXI_AWQOS : in std_logic_vector(3 downto 0);
            S_AXI_AWREGION : in std_logic_vector(3 downto 0);
            S_AXI_AWUSER : in std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
            S_AXI_AWVALID : in std_logic;
            S_AXI_AWREADY : out std_logic;
            S_AXI_WDATA : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            S_AXI_WSTRB : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
            S_AXI_WLAST : in std_logic;
            S_AXI_WUSER : in std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
            S_AXI_WVALID : in std_logic;
            S_AXI_WREADY : out std_logic;
            S_AXI_BID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
            S_AXI_BRESP : out std_logic_vector(1 downto 0);
            S_AXI_BUSER : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
            S_AXI_BVALID : out std_logic;
            S_AXI_BREADY : in std_logic;
            S_AXI_ARID : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
            S_AXI_ARADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            S_AXI_ARLEN : in std_logic_vector(7 downto 0);
            S_AXI_ARSIZE : in std_logic_vector(2 downto 0);
            S_AXI_ARBURST : in std_logic_vector(1 downto 0);
            S_AXI_ARLOCK : in std_logic;
            S_AXI_ARCACHE : in std_logic_vector(3 downto 0);
            S_AXI_ARPROT : in std_logic_vector(2 downto 0);
            S_AXI_ARQOS : in std_logic_vector(3 downto 0);
            S_AXI_ARREGION : in std_logic_vector(3 downto 0);
            S_AXI_ARUSER : in std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
            S_AXI_ARVALID : in std_logic;
            S_AXI_ARREADY : out std_logic;
            S_AXI_RID : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
            S_AXI_RDATA : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            S_AXI_RRESP : out std_logic_vector(1 downto 0);
            S_AXI_RLAST : out std_logic;
            S_AXI_RUSER : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
            S_AXI_RVALID : out std_logic;
            S_AXI_RREADY : in std_logic
        );
    end component;

    -- Clock and Reset signals
    signal clk : std_logic := '0';
    signal resetn : std_logic := '0';

    -- AXI signals
    signal awid : std_logic_vector(0 downto 0) := (others => '0');
    signal awaddr : std_logic_vector(5 downto 0) := (others => '0');
    signal awlen : std_logic_vector(7 downto 0) := (others => '0');
    signal awsize : std_logic_vector(2 downto 0) := "010"; -- 4 bytes
    signal awburst : std_logic_vector(1 downto 0) := "01"; -- INCR
    signal awlock : std_logic := '0';
    signal awcache : std_logic_vector(3 downto 0) := (others => '0');
    signal awprot : std_logic_vector(2 downto 0) := (others => '0');
    signal awqos : std_logic_vector(3 downto 0) := (others => '0');
    signal awregion : std_logic_vector(3 downto 0) := (others => '0');
    signal awuser : std_logic_vector(0 downto 0) := (others => '0');
    signal awvalid : std_logic := '0';
    signal awready : std_logic;
    signal wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal wstrb : std_logic_vector(3 downto 0) := (others => '1');
    signal wlast : std_logic := '1';
    signal wuser : std_logic_vector(0 downto 0) := (others => '0');
    signal wvalid : std_logic := '0';
    signal wready : std_logic;
    signal bid : std_logic_vector(0 downto 0);
    signal bresp : std_logic_vector(1 downto 0);
    signal buser : std_logic_vector(0 downto 0);
    signal bvalid : std_logic;
    signal bready : std_logic := '0';
    signal arid : std_logic_vector(0 downto 0) := (others => '0');
    signal araddr : std_logic_vector(5 downto 0) := (others => '0');
    signal arlen : std_logic_vector(7 downto 0) := (others => '0');
    signal arsize : std_logic_vector(2 downto 0) := "010"; -- 4 bytes
    signal arburst : std_logic_vector(1 downto 0) := "01"; -- INCR
    signal arlock : std_logic := '0';
    signal arcache : std_logic_vector(3 downto 0) := (others => '0');
    signal arprot : std_logic_vector(2 downto 0) := (others => '0');
    signal arqos : std_logic_vector(3 downto 0) := (others => '0');
    signal arregion : std_logic_vector(3 downto 0) := (others => '0');
    signal aruser : std_logic_vector(0 downto 0) := (others => '0');
    signal arvalid : std_logic := '0';
    signal arready : std_logic;
    signal rid : std_logic_vector(0 downto 0);
    signal rdata : std_logic_vector(31 downto 0);
    signal rresp : std_logic_vector(1 downto 0);
    signal rlast : std_logic;
    signal ruser : std_logic_vector(0 downto 0);
    signal rvalid : std_logic;
    signal rready : std_logic := '0';

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: manual_integration_v1_0_S00_AXI
        port map (
            S_AXI_ACLK => clk,
            S_AXI_ARESETN => resetn,
            S_AXI_AWID => awid,
            S_AXI_AWADDR => awaddr,
            S_AXI_AWLEN => awlen,
            S_AXI_AWSIZE => awsize,
            S_AXI_AWBURST => awburst,
            S_AXI_AWLOCK => awlock,
            S_AXI_AWCACHE => awcache,
            S_AXI_AWPROT => awprot,
            S_AXI_AWQOS => awqos,
            S_AXI_AWREGION => awregion,
            S_AXI_AWVALID => awvalid,
            S_AXI_AWREADY => awready,
            S_AXI_WDATA => wdata,
            S_AXI_WSTRB => wstrb,
            S_AXI_WLAST => wlast,
            S_AXI_WVALID => wvalid,
            S_AXI_WREADY => wready,
            S_AXI_BID => bid,
            S_AXI_BRESP => bresp,
            S_AXI_BVALID => bvalid,
            S_AXI_BREADY => bready,
            S_AXI_ARID => arid,
            S_AXI_ARADDR => araddr,
            S_AXI_ARLEN => arlen,
            S_AXI_ARSIZE => arsize,
            S_AXI_ARBURST => arburst,
            S_AXI_ARLOCK => arlock,
            S_AXI_ARCACHE => arcache,
            S_AXI_ARPROT => arprot,
            S_AXI_ARQOS => arqos,
            S_AXI_ARREGION => arregion,
            S_AXI_ARVALID => arvalid,
            S_AXI_ARREADY => arready,
            S_AXI_RID => rid,
            S_AXI_RDATA => rdata,
            S_AXI_RRESP => rresp,
            S_AXI_RLAST => rlast,
            S_AXI_RVALID => rvalid,
            S_AXI_RREADY => rready
        );

    -- Clock generation
    clk_process :process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;

    -- Reset process
    reset_process: process
    begin
        resetn <= '0';
        wait for 20 ns;
        resetn <= '1';
        wait for 20 ns;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        wait for 50 ns;  -- wait for reset to complete
        
        -- Write transaction
        awaddr <= "000001"; -- Address to write
        wdata <= x"DEADBEEF"; -- Data to write
        awvalid <= '1';
        wvalid <= '1';
        wait until (awready = '1' and wready = '1');
        awvalid <= '0';
        wvalid <= '0';

        -- Write response
        wait until (bvalid = '1');
        bready <= '1';
        wait until (bvalid = '0');
        bready <= '0';

        wait for 20 ns;

        -- Read transaction
        araddr <= "000001"; -- Address to read
        arvalid <= '1';
        wait until (arready = '1');
        arvalid <= '0';

        -- Read data
        wait until (rvalid = '1');
        rready <= '1';
        wait until (rvalid = '0');
        rready <= '0';

        -- End of simulation
        wait;
    end process;

end behavior;
