library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity NI_shell_integration_tb is
end NI_shell_integration_tb;

architecture Behavioral of NI_shell_integration_tb is

component NI_shell_integration is
    generic(
        -- AMBA-AXI attributes.
        c_AXI_DATA_WIDTH: natural := 32;
        c_AXI_ID_WIDTH  : natural := 5;
        c_AXI_RESP_WIDTH: natural := 3;
        c_AXI_ADDR_WIDTH: natural := 64;
        -- Interface attributes.
        c_FLIT_WIDTH        : natural  := c_AXI_DATA_WIDTH + 1;
        c_BUFFER_DEPTH      : positive := 8;
        c_USE_HAMMING       : boolean  := false;
        c_USE_INTEGRITY     : boolean  := false;
        c_USE_TMR_PACKETIZER: boolean  := false;
        c_USE_TMR_FLOW      : boolean  := false;
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
end component;

component adder_v1_0_S00_AXI is
        generic (
		  C_S_AXI_ID_WIDTH	: integer	:= 5;
		  C_S_AXI_DATA_WIDTH	: integer	:= 32;
		  C_S_AXI_ADDR_WIDTH	: integer	:= 64;
		  C_S_AXI_AWUSER_WIDTH	: integer	:= 0;
		  C_S_AXI_ARUSER_WIDTH	: integer	:= 0;
		  C_S_AXI_WUSER_WIDTH	: integer	:= 0;
		  C_S_AXI_RUSER_WIDTH	: integer	:= 0;
		  C_S_AXI_BUSER_WIDTH	: integer	:= 0
        );
        port (
            -- Global signals
            S_AXI_ACLK    : in std_logic; -- AXI clock signal
            S_AXI_ARESETN : in std_logic; -- AXI reset signal, active low
            
            -- Write address channel signals
            S_AXI_AWID    : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0); -- Write address ID
            S_AXI_AWADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0); -- Write address
            S_AXI_AWLEN   : in std_logic_vector(7 downto 0); -- Burst length (number of data transfers)
            S_AXI_AWSIZE  : in std_logic_vector(2 downto 0); -- Burst size (number of bytes per transfer)
            S_AXI_AWBURST : in std_logic_vector(1 downto 0); -- Burst type
            S_AXI_AWLOCK  : in std_logic; -- Lock type (for atomic operations)
            S_AXI_AWCACHE : in std_logic_vector(3 downto 0); -- Cache type
            S_AXI_AWPROT  : in std_logic_vector(2 downto 0); -- Protection type
            S_AXI_AWQOS   : in std_logic_vector(3 downto 0); -- Quality of Service
            S_AXI_AWREGION: in std_logic_vector(3 downto 0); -- Region identifier
            S_AXI_AWUSER  : in std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0) := (others => '0'); -- User-defined signal
            S_AXI_AWVALID : in std_logic; -- Write address valid
            S_AXI_AWREADY : out std_logic; -- Write address ready
            
            -- Write data channel signals
            S_AXI_WDATA   : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Write data
            S_AXI_WSTRB   : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0); -- Write strobe (byte enables)
            S_AXI_WLAST   : in std_logic; -- Write last (indicates the last data transfer in a burst)
            S_AXI_WUSER   : in std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0) := (others => '0'); -- User-defined signal
            S_AXI_WVALID  : in std_logic; -- Write valid
            S_AXI_WREADY  : out std_logic; -- Write ready
            
            -- Write response channel signals
            S_AXI_BID     : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0); -- Write response ID
            S_AXI_BRESP   : out std_logic_vector(2 downto 0); -- Write response (OKAY, EXOKAY, SLVERR, DECERR)
            S_AXI_BUSER   : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0) := (others => '0'); -- User-defined signal
            S_AXI_BVALID  : out std_logic; -- Write response valid
            S_AXI_BREADY  : in std_logic; -- Write response ready
            
            -- Read address channel signals
            S_AXI_ARID    : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0); -- Read address ID
            S_AXI_ARADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0); -- Read address
            S_AXI_ARLEN   : in std_logic_vector(7 downto 0); -- Burst length (number of data transfers)
            S_AXI_ARSIZE  : in std_logic_vector(2 downto 0); -- Burst size (number of bytes per transfer)
            S_AXI_ARBURST : in std_logic_vector(1 downto 0); -- Burst type
            S_AXI_ARLOCK  : in std_logic; -- Lock type (for atomic operations)
            S_AXI_ARCACHE : in std_logic_vector(3 downto 0); -- Cache type
            S_AXI_ARPROT  : in std_logic_vector(2 downto 0); -- Protection type
            S_AXI_ARQOS   : in std_logic_vector(3 downto 0); -- Quality of Service
            S_AXI_ARREGION: in std_logic_vector(3 downto 0); -- Region identifier
            S_AXI_ARUSER  : in std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0) := (others => '0'); -- User-defined signal
            S_AXI_ARVALID : in std_logic; -- Read address valid
            S_AXI_ARREADY : out std_logic; -- Read address ready
            
            -- Read data channel signals
            S_AXI_RID     : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0); -- Read ID
            S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Read data
            S_AXI_RRESP   : out std_logic_vector(2 downto 0); -- Read response (OKAY, EXOKAY, SLVERR, DECERR)
            S_AXI_RLAST   : out std_logic; -- Read last (indicates the last data transfer in a burst)
            S_AXI_RUSER   : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0) := (others => '0'); -- User-defined signal
            S_AXI_RVALID  : out std_logic; -- Read valid
            S_AXI_RREADY  : in std_logic  -- Read ready
        );
    end component;
    --Shared signals
    signal S_AXI_ACLK    : std_logic := '0'; -- AXI clock signal
    signal S_AXI_ARESETN : std_logic := '1'; -- AXI reset signal, active low
    -- Clock period definitions
    constant CLK_PERIOD : time := 10 ns; -- Clock period
    
    -- Signals for the AXI4 interface for the NI-ADDER
    signal S_AXI_AWID    : std_logic_vector(4 downto 0) := "00000"; -- Write address ID
    signal S_AXI_AWADDR  : std_logic_vector(63 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000"; -- Write address
    signal S_AXI_AWLEN   : std_logic_vector(7 downto 0) := "00000000"; -- Burst length (number of data transfers)
    signal S_AXI_AWSIZE  : std_logic_vector(2 downto 0) := "000"; -- Burst size (number of bytes per transfer)
    signal S_AXI_AWBURST : std_logic_vector(1 downto 0) := "00"; -- Burst type
    signal S_AXI_AWLOCK  : std_logic := '0'; -- Lock type (for atomic operations)
    signal S_AXI_AWCACHE : std_logic_vector(3 downto 0) := "0000"; -- Cache type
    signal S_AXI_AWPROT  : std_logic_vector(2 downto 0) := "000"; -- Protection type
    signal S_AXI_AWQOS   : std_logic_vector(3 downto 0) := "0000"; -- Quality of Service
    signal S_AXI_AWREGION: std_logic_vector(3 downto 0) := "0000"; -- Region identifier
    signal S_AXI_AWVALID : std_logic := '0'; -- Write address valid
    signal S_AXI_AWREADY : std_logic; -- Write address ready
    signal S_AXI_WDATA   : std_logic_vector(31 downto 0) := x"00000000"; -- Write data
    signal S_AXI_WSTRB   : std_logic_vector(3 downto 0) := "1111"; -- Write strobe (byte enables)
    signal S_AXI_WLAST   : std_logic := '0'; -- Write last (indicates the last data transfer in a burst)
    signal S_AXI_WVALID  : std_logic := '0'; -- Write valid
    signal S_AXI_WREADY  : std_logic; -- Write ready
    signal S_AXI_BID     : std_logic_vector(4 downto 0); -- Write response ID
    signal S_AXI_BRESP   : std_logic_vector(2 downto 0); -- Write response (OKAY, EXOKAY, SLVERR, DECERR)
    signal S_AXI_BVALID  : std_logic; -- Write response valid
    signal S_AXI_BREADY  : std_logic := '0'; -- Write response ready
    signal S_AXI_ARID    : std_logic_vector(4 downto 0) := "00000"; -- Read address ID
    signal S_AXI_ARADDR  : std_logic_vector(63 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000"; -- Read address
    signal S_AXI_ARLEN   : std_logic_vector(7 downto 0) := "00000000"; -- Burst length (number of data transfers)
    signal S_AXI_ARSIZE  : std_logic_vector(2 downto 0) := "000"; -- Burst size (number of bytes per transfer)
    signal S_AXI_ARBURST : std_logic_vector(1 downto 0) := "00"; -- Burst type
    signal S_AXI_ARLOCK  : std_logic := '0'; -- Lock type (for atomic operations)
    signal S_AXI_ARCACHE : std_logic_vector(3 downto 0) := "0000"; -- Cache type
    signal S_AXI_ARPROT  : std_logic_vector(2 downto 0) := "000"; -- Protection type
    signal S_AXI_ARQOS   : std_logic_vector(3 downto 0) := "0000"; -- Quality of Service
    signal S_AXI_ARREGION: std_logic_vector(3 downto 0) := "0000"; -- Region identifier
    signal S_AXI_ARVALID : std_logic := '0'; -- Read address valid
    signal S_AXI_ARREADY : std_logic; -- Read address ready
    signal S_AXI_RID     : std_logic_vector(4 downto 0); -- Read ID
    signal S_AXI_RDATA   : std_logic_vector(31 downto 0); -- Read data
    signal S_AXI_RRESP   : std_logic_vector(2 downto 0); -- Read response (OKAY, EXOKAY, SLVERR, DECERR)
    signal S_AXI_RLAST   : std_logic; -- Read last (indicates the last data transfer in a burst)
    signal S_AXI_RVALID  : std_logic; -- Read valid
    signal S_AXI_RREADY  : std_logic := '0'; -- Read ready
    
begin
    -- Instantiate the Unit Under Test (UUT)
    uut: NI_shell_integration
        port map (
            ACLK        => S_AXI_ACLK,
            ARESETn     => S_AXI_ARESETN,
            t00_AWID    => S_AXI_AWID,
            t00_AWADDR  => S_AXI_AWADDR,
            t00_AWLEN   => S_AXI_AWLEN,
            --          => S_AXI_AWSIZE,
            t00_AWBURST => S_AXI_AWBURST,
            --          => S_AXI_AWLOCK,
            --          => S_AXI_AWCACHE,
            --          => S_AXI_AWPROT,
            --          => S_AXI_AWQOS,
            --          => S_AXI_AWREGION,
            -- S_AXI_AWUSER  => open,  -- Width is zero
            t00_AWVALID => S_AXI_AWVALID,
            t00_AWREADY => S_AXI_AWREADY,
            t00_WDATA   => S_AXI_WDATA,
            --          => S_AXI_WSTRB,
            t00_WLAST   => S_AXI_WLAST,
            -- S_AXI_WUSER => open,  -- Width is zero
            t00_WVALID  => S_AXI_WVALID,
            t00_WREADY  => S_AXI_WREADY,
            t00_BID     => S_AXI_BID,
            t00_BRESP   => S_AXI_BRESP,
            -- S_AXI_BUSER => open,  -- Width is zero
            t00_BVALID  => S_AXI_BVALID,
            t00_BREADY  => S_AXI_BREADY,
            t00_ARID    => S_AXI_ARID,
            t00_ARADDR  => S_AXI_ARADDR,
            t00_ARLEN   => S_AXI_ARLEN,
            --          => S_AXI_ARSIZE,
            t00_ARBURST => S_AXI_ARBURST,
            --          => S_AXI_ARLOCK,
            --          => S_AXI_ARCACHE,
            --          => S_AXI_ARPROT,
            --          => S_AXI_ARQOS,
            --          => S_AXI_ARREGION,
            -- S_AXI_ARUSER  => open,  -- Width is zero
            t00_ARVALID => S_AXI_ARVALID,
            t00_ARREADY => S_AXI_ARREADY,
            t00_RID     => S_AXI_RID,
            t00_RDATA   => S_AXI_RDATA,
            t00_RRESP   => S_AXI_RRESP,
            t00_RLAST   => S_AXI_RLAST,
            -- S_AXI_RUSER   => open,  -- Width is zero
            t00_RVALID  => S_AXI_RVALID,
            t00_RREADY  => S_AXI_RREADY
        );
        
    -- Clock process definitions
    clk_process :process
    begin
        S_AXI_ACLK <= '0';
        wait for CLK_PERIOD/2;
        S_AXI_ACLK <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- Stimulus process NI-ADDER
    stim_proc: process
    begin
        -- Reset the system
        S_AXI_ARESETN <= '0';
        wait for 20 ns;
        S_AXI_ARESETN <= '1';
        wait for 20 ns;
        
        -- Write Address handshake
        S_AXI_AWADDR  <= x"0000000040000000";
        S_AXI_AWVALID <= '1';
        wait until rising_edge(S_AXI_ACLK) and S_AXI_AWREADY = '1';
        S_AXI_AWVALID <= '0';
        
        -- Data transfer handshake
        S_AXI_WDATA   <= x"12345678"; -- Data to write
        S_AXI_WVALID  <= '1';
        S_AXI_WLAST   <= '1';
        wait until rising_edge(S_AXI_ACLK) and S_AXI_WREADY = '1';
        S_AXI_WVALID  <= '0';
        S_AXI_WLAST   <= '0';
        
        -- Write response handshake
        S_AXI_BREADY <= '1';
        wait until rising_edge(S_AXI_ACLK) and S_AXI_BVALID = '1';
        S_AXI_BREADY <= '0';
        
        wait for 100 ns;
        -- Read address handshake 
        S_AXI_ARADDR <= x"0000000040000000";
        S_AXI_ARVALID <= '1';
        wait until rising_edge(S_AXI_ACLK) and S_AXI_ARREADY = '1';
        S_AXI_ARVALID <= '0';
        
        -- Read data handshake
        S_AXI_RREADY <= '1';
        wait until rising_edge(S_AXI_ACLK) and S_AXI_RVALID = '1';
        assert S_AXI_RDATA = x"12345678" report "Wrong read data!" severity error;
        S_AXI_RREADY <= '0';

        -- Stop simulation
        wait;
    end process;
   
end Behavioral;
