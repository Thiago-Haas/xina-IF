library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity tb_axifull_master is
end tb_axifull_master;

architecture rtl of tb_axifull_master is

    -- Top level component 
    component manual_integration_v1_0
        generic (
          C_S00_AXI_ID_WIDTH     : integer;
          C_S00_AXI_DATA_WIDTH   : integer;
          C_S00_AXI_ADDR_WIDTH   : integer;
          C_S00_AXI_AWUSER_WIDTH : integer;
          C_S00_AXI_ARUSER_WIDTH : integer;
          C_S00_AXI_WUSER_WIDTH  : integer;
          C_S00_AXI_RUSER_WIDTH  : integer;
          C_S00_AXI_BUSER_WIDTH  : integer
        );
        port (
          s00_axi_aclk     : in  std_logic;
          s00_axi_aresetn  : in  std_logic;
          s00_axi_awid     : in  std_logic_vector(C_S00_AXI_ID_WIDTH-1 downto 0);
          s00_axi_awaddr   : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
          s00_axi_awlen    : in  std_logic_vector(7 downto 0);
          s00_axi_awsize   : in  std_logic_vector(2 downto 0);
          s00_axi_awburst  : in  std_logic_vector(1 downto 0);
          s00_axi_awlock   : in  std_logic;
          s00_axi_awcache  : in  std_logic_vector(3 downto 0);
          s00_axi_awprot   : in  std_logic_vector(2 downto 0);
          s00_axi_awqos    : in  std_logic_vector(3 downto 0);
          s00_axi_awregion : in  std_logic_vector(3 downto 0);
          s00_axi_awuser   : in  std_logic_vector(C_S00_AXI_AWUSER_WIDTH-1 downto 0);
          s00_axi_awvalid  : in  std_logic;
          s00_axi_awready  : out std_logic;
          s00_axi_wdata    : in  std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
          s00_axi_wstrb    : in  std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
          s00_axi_wlast    : in  std_logic;
          s00_axi_wuser    : in  std_logic_vector(C_S00_AXI_WUSER_WIDTH-1 downto 0);
          s00_axi_wvalid   : in  std_logic;
          s00_axi_wready   : out std_logic;
          s00_axi_bid      : out std_logic_vector(C_S00_AXI_ID_WIDTH-1 downto 0);
          s00_axi_bresp    : out std_logic_vector(1 downto 0);
          s00_axi_buser    : out std_logic_vector(C_S00_AXI_BUSER_WIDTH-1 downto 0);
          s00_axi_bvalid   : out std_logic;
          s00_axi_bready   : in  std_logic;
          s00_axi_arid     : in  std_logic_vector(C_S00_AXI_ID_WIDTH-1 downto 0);
          s00_axi_araddr   : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
          s00_axi_arlen    : in  std_logic_vector(7 downto 0);
          s00_axi_arsize   : in  std_logic_vector(2 downto 0);
          s00_axi_arburst  : in  std_logic_vector(1 downto 0);
          s00_axi_arlock   : in  std_logic;
          s00_axi_arcache  : in  std_logic_vector(3 downto 0);
          s00_axi_arprot   : in  std_logic_vector(2 downto 0);
          s00_axi_arqos    : in  std_logic_vector(3 downto 0);
          s00_axi_arregion : in  std_logic_vector(3 downto 0);
          s00_axi_aruser   : in  std_logic_vector(C_S00_AXI_ARUSER_WIDTH-1 downto 0);
          s00_axi_arvalid  : in  std_logic;
          s00_axi_arready  : out std_logic;
          s00_axi_rid      : out std_logic_vector(C_S00_AXI_ID_WIDTH-1 downto 0);
          s00_axi_rdata    : out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
          s00_axi_rresp    : out std_logic_vector(1 downto 0);
          s00_axi_rlast    : out std_logic;
          s00_axi_ruser    : out std_logic_vector(C_S00_AXI_RUSER_WIDTH-1 downto 0);
          s00_axi_rvalid   : out std_logic;
          s00_axi_rready   : in  std_logic
        );
      end component;

    constant C_M_AXI_DATA_WIDTH : integer := 32;
    constant C_M_AXI_ADDR_WIDTH : integer := 64;

    -- AXI4 Full Interface signals
    signal M_AXI_AWID     : std_logic_vector(3 downto 0);
    signal M_AXI_AWADDR   : std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
    signal M_AXI_AWLEN    : std_logic_vector(7 downto 0);
    signal M_AXI_AWSIZE   : std_logic_vector(2 downto 0);
    signal M_AXI_AWBURST  : std_logic_vector(1 downto 0);
    signal M_AXI_AWLOCK   : std_logic;
    signal M_AXI_AWCACHE  : std_logic_vector(3 downto 0);
    signal M_AXI_AWPROT   : std_logic_vector(2 downto 0);
    signal M_AXI_AWQOS    : std_logic_vector(3 downto 0);
    signal M_AXI_AWVALID  : std_logic;
    signal M_AXI_AWREADY  : std_logic;

    signal M_AXI_WDATA    : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal M_AXI_WSTRB    : std_logic_vector((C_M_AXI_DATA_WIDTH/8)-1 downto 0);
    signal M_AXI_WLAST    : std_logic;
    signal M_AXI_WVALID   : std_logic;
    signal M_AXI_WREADY   : std_logic;

    signal M_AXI_BID      : std_logic_vector(3 downto 0);
    signal M_AXI_BRESP    : std_logic_vector(1 downto 0);
    signal M_AXI_BVALID   : std_logic;
    signal M_AXI_BREADY   : std_logic;

    signal M_AXI_ARID     : std_logic_vector(3 downto 0);
    signal M_AXI_ARADDR   : std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
    signal M_AXI_ARLEN    : std_logic_vector(7 downto 0);
    signal M_AXI_ARSIZE   : std_logic_vector(2 downto 0);
    signal M_AXI_ARBURST  : std_logic_vector(1 downto 0);
    signal M_AXI_ARLOCK   : std_logic;
    signal M_AXI_ARCACHE  : std_logic_vector(3 downto 0);
    signal M_AXI_ARPROT   : std_logic_vector(2 downto 0);
    signal M_AXI_ARQOS    : std_logic_vector(3 downto 0);
    signal M_AXI_ARVALID  : std_logic;
    signal M_AXI_ARREADY  : std_logic;

    signal M_AXI_RID      : std_logic_vector(3 downto 0);
    signal M_AXI_RDATA    : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal M_AXI_RRESP    : std_logic_vector(1 downto 0);
    signal M_AXI_RLAST    : std_logic;
    signal M_AXI_RVALID   : std_logic;
    signal M_AXI_RREADY   : std_logic;

    -- Clock and reset
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';

begin

    -- Clock generation
    clk_process : process
    begin
        while True loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Reset generation
    reset_process : process
    begin
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait;
    end process;
   
  -- Instantiate the AXI4 Master DUT (Device Under Test)
  manual_integration_v1_0_inst : manual_integration_v1_0
  generic map (
    C_S00_AXI_ID_WIDTH     => 4,
    C_S00_AXI_DATA_WIDTH   => 32,
    C_S00_AXI_ADDR_WIDTH   => 64,
    C_S00_AXI_AWUSER_WIDTH => 1,
    C_S00_AXI_ARUSER_WIDTH => 1,
    C_S00_AXI_WUSER_WIDTH  => 1,
    C_S00_AXI_RUSER_WIDTH  => 1,
    C_S00_AXI_BUSER_WIDTH  => 1
  )
  port map (
    s00_axi_aclk     => clk,
    s00_axi_aresetn  => reset,
    s00_axi_awid     => M_AXI_AWID,
    s00_axi_awaddr   => M_AXI_AWADDR,
    s00_axi_awlen    => M_AXI_AWLEN,
    s00_axi_awsize   => M_AXI_AWSIZE,
    s00_axi_awburst  => M_AXI_AWBURST,
    s00_axi_awlock   => M_AXI_AWLOCK,
    s00_axi_awcache  => M_AXI_AWCACHE,
    s00_axi_awprot   => M_AXI_AWPROT,
    s00_axi_awqos    => M_AXI_AWQOS,
    s00_axi_awregion => "0000",
    s00_axi_awuser   => '0',
    s00_axi_awvalid  => M_AXI_AWVALID,
    s00_axi_awready  => M_AXI_AWREADY,
    s00_axi_wdata    => M_AXI_WDATA,
    s00_axi_wstrb    => M_AXI_WSTRB,
    s00_axi_wlast    => M_AXI_WLAST,
    s00_axi_wuser    => '0',
    s00_axi_wvalid   => M_AXI_WVALID,
    s00_axi_wready   => M_AXI_WREADY,
    s00_axi_bid      => M_AXI_BID,
    s00_axi_bresp    => M_AXI_BRESP,
    s00_axi_buser    => '0',
    s00_axi_bvalid   => M_AXI_BVALID,
    s00_axi_bready   => M_AXI_BREADY,
    s00_axi_arid     => M_AXI_ARID,
    s00_axi_araddr   => M_AXI_ARADDR,
    s00_axi_arlen    => M_AXI_ARLEN,
    s00_axi_arsize   => M_AXI_ARSIZE,
    s00_axi_arburst  => M_AXI_ARBURST,
    s00_axi_arlock   => M_AXI_ARLOCK,
    s00_axi_arcache  => M_AXI_ARCACHE,
    s00_axi_arprot   => M_AXI_ARPROT,
    s00_axi_arqos    => M_AXI_ARQOS,
    s00_axi_arregion => "0000",
    s00_axi_aruser   => '0',
    s00_axi_arvalid  => M_AXI_ARVALID,
    s00_axi_arready  => M_AXI_ARREADY,
    s00_axi_rid      => M_AXI_RID,
    s00_axi_rdata    => M_AXI_RDATA,
    s00_axi_rresp    => M_AXI_RRESP,
    s00_axi_rlast    => M_AXI_RLAST,
    s00_axi_ruser    => '0',
    s00_axi_rvalid   => M_AXI_RVALID,
    s00_axi_rready   => M_AXI_RREADY
  );

-- Test process
test_process : process
begin
    -- Wait for reset de-assertion
    wait until reset = '0';

    -- Test AXI Write Transaction
    -- Write Address Channel
    M_AXI_AWID     <= x"0";
    M_AXI_AWADDR   <= x"0000000000000000";
    M_AXI_AWLEN    <= "00000000";  -- Single transfer
    M_AXI_AWSIZE   <= "010";       -- 32-bit transfer
    M_AXI_AWBURST  <= "01";        -- INCR burst type
    M_AXI_AWLOCK   <= '0';
    M_AXI_AWCACHE  <= "0010";      -- Normal Non-cacheable Bufferable
    M_AXI_AWPROT   <= "000";       -- Data, Secure, Non-privileged
    M_AXI_AWQOS    <= "0000";
    M_AXI_AWVALID  <= '1';

    wait until M_AXI_AWREADY = '1';
    M_AXI_AWVALID  <= '0';

    -- Write Data Channel
    M_AXI_WDATA    <= x"DEADBEEF";
    M_AXI_WSTRB    <= "1111";      -- All bytes are valid
    M_AXI_WLAST    <= '1';
    M_AXI_WVALID   <= '1';

    wait until M_AXI_WREADY = '1';
    M_AXI_WVALID   <= '0';

    -- Write Response Channel
    M_AXI_BREADY   <= '1';
    wait until M_AXI_BVALID = '1';
    assert M_AXI_BRESP = "00" report "Write response error" severity error;
    M_AXI_BREADY   <= '0';

    -- Test AXI Read Transaction
    -- Read Address Channel
    M_AXI_ARID     <= x"0";
    M_AXI_ARADDR   <= x"0000000000000000";
    M_AXI_ARLEN    <= "00000000";  -- Single transfer
    M_AXI_ARSIZE   <= "010";       -- 32-bit transfer
    M_AXI_ARBURST  <= "01";        -- INCR burst type
    M_AXI_ARLOCK   <= '0';
    M_AXI_ARCACHE  <= "0010";      -- Normal Non-cacheable Bufferable
    M_AXI_ARPROT   <= "000";       -- Data, Secure, Non-privileged
    M_AXI_ARQOS    <= "0000";
    M_AXI_ARVALID  <= '1';

    wait until M_AXI_ARREADY = '1';
    M_AXI_ARVALID  <= '0';

    -- Read Data Channel
    M_AXI_RREADY   <= '1';
    wait until M_AXI_RVALID = '1';
    assert M_AXI_RDATA = x"DEADBEEF" report "Read data mismatch" severity error;
    assert M_AXI_RRESP = "00" report "Read response error" severity error;
    M_AXI_RREADY   <= '0';

    -- End of test
    wait;
end process;

end architecture;

