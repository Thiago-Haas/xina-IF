library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity tb_file_read is
end entity tb_file_read;

architecture sim of tb_file_read is
    -- Constants declaration
    constant c_CLK_PERIOD : time := 10 ns; -- Clock period

    -- Signals declaration
    signal s_CLK         : std_logic := '0'; -- Clock signal
    signal s_RESET       : std_logic := '0'; -- Reset signal

    -- Signals for AXI interface
    signal s_AWVALID     : std_logic := '0';
    signal s_AWREADY     : std_logic;
    signal s_AWID        : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    signal s_AWADDR      : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal s_AWLEN       : std_logic_vector(7 downto 0) := (others => '0');
    signal s_AWBURST     : std_logic_vector(1 downto 0) := "01";

    signal s_WVALID      : std_logic := '0';
    signal s_WREADY      : std_logic;
    signal s_WDATA       : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_WLAST       : std_logic := '0';

    signal s_BVALID      : std_logic;
    signal s_BREADY      : std_logic := '0';
    signal s_BID         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal s_BRESP       : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    signal s_ARVALID     : std_logic := '0';
    signal s_ARREADY     : std_logic;
    signal s_ARID        : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    signal s_ARADDR      : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal s_ARLEN       : std_logic_vector(7 downto 0) := (others => '0');
    signal s_ARBURST     : std_logic_vector(1 downto 0) := "01";

    signal s_RVALID      : std_logic;
    signal s_RREADY      : std_logic := '0';
    signal s_RDATA       : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal s_RLAST       : std_logic;
    signal s_RID         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal s_RRESP       : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    -- Signals for XINA interface
    signal s_l_in_data_i    : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal s_l_in_val_i     : std_logic;
    signal s_l_in_ack_o     : std_logic;
    signal s_l_out_data_o   : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal s_l_out_val_o    : std_logic;
    signal s_l_out_ack_i    : std_logic;

begin
    -- DUT instantiation
    DUT: entity work.tcc_top_master
    port map (
        -- AXI interface
        ACLK           => s_CLK,
        ARESETn        => s_RESET,
        AWVALID        => s_AWVALID,
        AWREADY        => s_AWREADY,
        AWID           => s_AWID,
        AWADDR         => s_AWADDR,
        AWLEN          => s_AWLEN,
        AWBURST        => s_AWBURST,
        WVALID         => s_WVALID,
        WREADY         => s_WREADY,
        WDATA          => s_WDATA,
        WLAST          => s_WLAST,
        BVALID         => s_BVALID,
        BREADY         => s_BREADY,
        BID            => s_BID,
        BRESP          => s_BRESP,
        ARVALID        => s_ARVALID,
        ARREADY        => s_ARREADY,
        ARID           => s_ARID,
        ARADDR         => s_ARADDR,
        ARLEN          => s_ARLEN,
        ARBURST        => s_ARBURST,
        RVALID         => s_RVALID,
        RREADY         => s_RREADY,
        RDATA          => s_RDATA,
        RLAST          => s_RLAST,
        RID            => s_RID,
        RRESP          => s_RRESP,
        -- Extra signals
        CORRUPT_PACKET => open,
        -- XINA signals
        l_in_data_i    => s_l_in_data_i,
        l_in_val_i     => s_l_in_val_i,
        l_in_ack_o     => s_l_in_ack_o,
        l_out_data_o   => s_l_out_data_o,
        l_out_val_o    => s_l_out_val_o,
        l_out_ack_i    => s_l_out_ack_i
    );

    -- Clock generation process
    clk_gen_proc: process
    begin
        while true loop
            s_CLK <= not s_CLK;
            wait for c_CLK_PERIOD / 2;
        end loop;
    end process clk_gen_proc;
    
    -- Xina generation process
    Xina_gen_proc: process
    begin
        s_l_in_data_i <= (others => '0'); -- Initialize data
        s_l_in_val_i <= '0'; -- Set initial value to low

        -- Wait for one clock cycle if flow mode is Moore
        --if flow_mode_p = 0 then
        wait for 4*c_CLK_PERIOD;
        --end if;

        -- Drive valid signal high
        s_l_in_val_i <= '1';

        -- Drive acknowledgment signal high
        s_l_in_ack_o <= '1';

        -- Wait for one clock cycle
        wait for 4*c_CLK_PERIOD;

        -- Drive valid and acknowledgment signals low
        s_l_in_val_i <= '0';
        s_l_in_ack_o <= '0';

        -- Wait for one clock cycle
        wait for 4*c_CLK_PERIOD;
    end process Xina_gen_proc;

end architecture sim;


