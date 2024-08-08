library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity tb_manual_integration_ccsds is
end tb_manual_integration_ccsds;

architecture Behavioral of tb_manual_integration_ccsds is

signal tb_ACLK  : std_logic := '0';
signal tb_RESETn: std_logic := '1';
signal tb_RESET : std_logic := '0';
signal tb2_RESETn: std_logic := '1';

-- Write request signals.
signal tb_AWVALID: std_logic := '0';
signal tb_AWREADY: std_logic := '0';
signal tb_AWID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal tb_AWADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
signal tb_AWLEN  : std_logic_vector(7 downto 0) := "00000000";
signal tb_AWBURST: std_logic_vector(1 downto 0) := "01";

-- Write data signals.
signal tb_WVALID : std_logic := '0';
signal tb_WREADY : std_logic := '0';
signal tb_WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
signal tb_WLAST  : std_logic := '0';

-- Write response signals.
signal tb_BVALID : std_logic := '0';
signal tb_BREADY : std_logic := '0';
signal tb_BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal tb_BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

-- Read request signals.
signal tb_ARVALID: std_logic := '0';
signal tb_ARREADY: std_logic := '0';
signal tb_ARID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal tb_ARADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
signal tb_ARLEN  : std_logic_vector(7 downto 0) := "00000000";
signal tb_ARBURST: std_logic_vector(1 downto 0) := "01";

-- Read response/data signals.
signal tb_RVALID : std_logic := '0';
signal tb_RREADY : std_logic := '0';
signal tb_RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
signal tb_RLAST  : std_logic := '0';
signal tb_RID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal tb_RRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

-- Extra signals.
signal tb_CORRUPT_PACKET: std_logic;

begin
    u_manual_integration_ccsds: entity work.manual_integration_ccsds
    port map(
        -- AMBA AXI 5 signals.
        t_ACLK    => tb_ACLK,
        t_ARESETn => tb_RESETn,
        t_RESET   => tb_RESET,
        t2_RESETn  => tb2_RESETn,

            -- Write request signals.
            t_AWVALID => tb_AWVALID,
            t_AWREADY => tb_AWREADY,
            t_AWID    => tb_AWID,
            t_AWADDR  => tb_AWADDR,
            t_AWLEN   => tb_AWLEN,
            t_AWBURST => tb_AWBURST,

            -- Write data signals.
            t_WVALID  => tb_WVALID,
            t_WREADY  => tb_WREADY,
            t_WDATA   => tb_WDATA,
            t_WLAST   => tb_WLAST,

            -- Write response signals.
            t_BVALID  => tb_BVALID,
            t_BREADY  => tb_BREADY,
            t_BID     => tb_BID,
            t_BRESP   => tb_BRESP,

            -- Read request signals.
            t_ARVALID => tb_ARVALID,
            t_ARREADY => tb_ARREADY,
            t_ARID    => tb_ARID,
            t_ARADDR  => tb_ARADDR,
            t_ARLEN   => tb_ARLEN,
            t_ARBURST => tb_ARBURST,

            -- Read response/data signals.
            t_RVALID  => tb_RVALID,
            t_RREADY  => tb_RREADY,
            t_RDATA   => tb_RDATA,
            t_RLAST   => tb_RLAST,
            t_RID     => tb_RID,
            t_RRESP   => tb_RRESP,

            t_CORRUPT_PACKET => tb_CORRUPT_PACKET
    );

    ---------------------------------------------------------------------------------------------
    -- Clock.
    process
    begin
        wait for 50 ns;
        tb_ACLK <= not tb_ACLK;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Reset.
    process(tb_RESETn)
    begin
        tb_RESET <= not tb_RESETn;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Tests.
    process
    begin
        -- Reset slave.
        tb2_RESETn <= '0';
        wait for 100 ns;
        tb2_RESETn <= '1';

        ---------------------------------------------------------------------------------------------
        -- First transaction (write).
        tb_AWVALID <= '1';
        tb_AWADDR <= "0000000000000000" & "0000000000000000" & "0000000000000001" & "0000000000000000";
        tb_AWID <= "00001";
        tb_AWLEN <= "00000000";

        wait until rising_edge(tb_ACLK) and tb_AWREADY = '1';

        -- Reset.
        tb_AWVALID <= '0';
        tb_AWADDR <= (others => '0');
        tb_AWID <= (others => '0');
        tb_AWLEN <= (others => '0');

        -- Flit 1.
        tb_WVALID <= '1';
        tb_WDATA <= "00000000000000000000000000000001";
        tb_WLAST <= '1';
    
        wait until rising_edge(tb_ACLK) and tb_WREADY = '1';

        -- Reset.
        tb_WDATA <= (others => '0');
        tb_WVALID <= '0';
        tb_WLAST <= '0';

        ---------------------------------------------------------------------------------------------
        -- Receive first transaction response.
        tb_BREADY <= '1';

        wait until rising_edge(tb_ACLK) and tb_BVALID = '1';
        tb_BREADY <= '0';

        ---------------------------------------------------------------------------------------------
        -- Second transaction (read).
        tb_ARVALID <= '1';
        tb_ARADDR <= "0000000000000000" & "0000000000000000" & "0000000000000001" & "0000000000000000";
        tb_ARID <= "00010";
        tb_ARLEN <= "00000000";

        wait until rising_edge(tb_ACLK) and tb_ARREADY = '1';

        -- Reset.
        tb_ARVALID <= '0';
        tb_ARADDR <= (others => '0');
        tb_ARID <= (others => '0');
        tb_ARLEN <= (others => '0');

        ---------------------------------------------------------------------------------------------
        -- Receive second transaction response.
        tb_RREADY <= '1';

        wait until rising_edge(tb_ACLK) and tb_RVALID = '1' and tb_RLAST = '1';

        -- Reset.
        tb_RREADY <= '0';

        wait;
    end process;
end Behavioral;
