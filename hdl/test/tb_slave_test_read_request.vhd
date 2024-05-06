library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_slave_test_read_request is
end tb_slave_test_read_request;

architecture arch_tb_master_injection_write of tb_slave_test_read_request is
    -- AMBA-AXI 5 signals.
    signal t_ACLK  : std_logic := '0';
    signal t_RESETn: std_logic := '1';
    signal t_RESET : std_logic := '0';

        -- Write request signals.
        signal t_AWVALID: std_logic := '0';
        signal t_AWREADY: std_logic := '0';
        signal t_AWID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal t_AWADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
        signal t_AWLEN  : std_logic_vector(7 downto 0) := (others => '0');
        signal t_AWSIZE : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c_AXI_DATA_WIDTH/8, 3)); --this signal is not present in the master
        signal t_AWBURST: std_logic_vector(1 downto 0) := "01";

        -- Write data signals.
        signal t_WVALID : std_logic := '0';
        signal t_WREADY : std_logic := '0';
        signal t_WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
        signal t_WLAST  : std_logic := '0';

        -- Write response signals.
        signal t_BVALID : std_logic := '0';
        signal t_BREADY : std_logic := '0';
        signal t_BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal t_BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Read request signals.
        signal t_ARVALID: std_logic := '0';
        signal t_ARREADY: std_logic := '0';
        signal t_ARID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal t_ARADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
        signal t_ARLEN  : std_logic_vector(7 downto 0) := "00000000";
        signal t_ARSIZE : std_logic_vector(2 downto 0) := "000"; --this signal is not present in the master
        signal t_ARBURST: std_logic_vector(1 downto 0) := "01";

        -- Read response/data signals.
        signal t_RVALID : std_logic := '0';
        signal t_RREADY : std_logic := '0';
        signal t_RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
        signal t_RLAST  : std_logic := '0';
        signal t_RID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        signal t_RRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Extra signals.
        signal t_CORRUPT_PACKET: std_logic;

    -- Signals between backend and XINA router.
    signal t_l_in_data_i : std_logic_vector(data_width_c downto 0);
    signal t_l_in_val_i  : std_logic;
    signal t_l_in_ack_o  : std_logic;
    signal t_l_out_data_o: std_logic_vector(data_width_c downto 0);
    signal t_l_out_val_o : std_logic;
    signal t_l_out_ack_i : std_logic;
    signal counter : std_logic_vector(31 downto 0) := (others => '0'); -- clock cycle counter
    
    constant n_packets : integer := 262144; --number of messages that will be used on the testebench 262144 equals 1MB


   begin    
   u_TOP_SLAVE: entity work.tcc_top_slave
    port map(
        -- AMBA AXI 5 signals.
        ACLK => t_ACLK,
        ARESETn => t_RESETn,

            -- Write request signals.
            AWVALID => t_AWVALID,
            AWREADY => t_AWREADY,
            AWID    => t_AWID,
            AWADDR  => t_AWADDR,
            AWLEN   => t_AWLEN,
            AWSIZE  => t_AWSIZE, --this signal is not present in the master
            AWBURST => t_AWBURST,

            -- Write data signals.
            WVALID => t_WVALID,
            WREADY => t_WREADY,
            WDATA  => t_WDATA,
            WLAST  => t_WLAST,

            -- Write response signals.
            BVALID => t_BVALID,
            BREADY => t_BREADY,
            BID    => t_BID,
            BRESP  => t_BRESP,

            -- Read request signals.
            ARVALID => t_ARVALID,
            ARREADY => t_ARREADY,
            ARID    => t_ARID,
            ARADDR  => t_ARADDR,
            ARLEN   => t_ARLEN,
            ARSIZE  => t_ARSIZE, --this signal is not present in the master
            ARBURST => t_ARBURST,

            -- Read response/data signals.
            RVALID => t_RVALID,
            RREADY => t_RREADY,
            RDATA  => t_RDATA,
            RLAST  => t_RLAST,
            RID    => t_RID,
            RRESP  => t_RRESP,

            -- Extra signals.
            CORRUPT_PACKET => t_CORRUPT_PACKET,

            -- XINA signals.
            l_in_data_i  => t_l_in_data_i,
            l_in_val_i   => t_l_in_val_i,
            l_in_ack_o   => t_l_in_ack_o,
            l_out_data_o => t_l_out_data_o,
            l_out_val_o  => t_l_out_val_o,
            l_out_ack_i  => t_l_out_ack_i
    );

    ---------------------------------------------------------------------------------------------
    -- Clock.
    process
    begin
        wait for 50 ns;
        t_ACLK <= not t_ACLK;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Reset.
    process(t_RESETn)
    begin
        t_RESET <= not t_RESETn;
    end process;
    
        --Clock cycle counter
    process(t_ACLK)
    begin
    if rising_edge(t_ACLK) then
        counter <= std_logic_vector(unsigned(counter) + 1); -- Convert to unsigned, increment, and convert back to std_logic_vector
    end if;
    end process;
    

    -- Read Payload AXI P1
    process
    file txt_reader : text open read_mode is ("/home/haas/Documents/Github/XINA-IF/traffic/input_PAYLOAD_traffic.txt");
    variable v_iline : line;
    variable temporary_read_value : std_logic_vector(31 downto 0);
    variable packet_count : integer := 0; -- Initialize packet counter
    begin       
        while (packet_count < n_packets) loop -- Continue reading until the packet count reaches the limit
    
            t_l_out_val_o <= '1';
            t_l_out_data_o <= "100000000000000010000000000000001"; -- Header_dest
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '1';
            t_l_out_val_o <= '0';
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '0';
                    
            t_l_out_val_o <= '1';
            t_l_out_data_o <= "000000000000000010000000000000000"; -- Header_src
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '1';
            t_l_out_val_o <= '0';
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '0';
 
            t_l_out_val_o <= '1';
            t_l_out_data_o <= "000000000000000001000000000100010"; -- Header_NI 
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '1';
            t_l_out_val_o <= '0';
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '0';
                  
            t_l_out_val_o <= '1';
            readline(txt_reader, v_ILINE);
            read(v_ILINE, temporary_read_value);
            t_l_out_data_o <= '0' & temporary_read_value; --ADRRESS/Payload
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '1';
            t_l_out_val_o <= '0';
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '0';
                    
            t_l_out_val_o <= '1';
            t_l_out_data_o <= "100000000000000000000000000000000"; -- Trailer
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '1';
            t_l_out_val_o <= '0';
            wait until rising_edge(t_ACLK) and t_l_out_ack_i = '0';

            t_l_out_data_o <= (32 downto 0 => '0');
            packet_count := packet_count + 1;  
        end loop;
        wait;
    end process;
   
       --Process 2 Exit
    process
    variable v_oline:line;
    file log_writer : text open write_mode is ("/home/haas/Documents/Github/XINA-IF/traffic/output_P2_SLAVE_traffic.txt");
    begin
        wait until rising_edge(t_ACLK) and t_ARVALID='1'; 
        write(v_oline, t_ARADDR);
        writeline(log_writer, v_oline);
        wait until  t_ARVALID='0';
    end process;
    
    --Read Payload P3
    process
    file txt_reader : text open read_mode is ("/home/haas/Documents/Github/XINA-IF/traffic/input_PAYLOAD_traffic.txt");
    variable v_iline : line;
    variable temporary_read_value : std_logic_vector(31 downto 0);
    variable packet_count : integer := 0; -- Initialize packet counter
    begin
        while (packet_count < n_packets) loop -- Continue reading until the packet count reaches the limit
    
            t_ARREADY <= '1';
            wait until rising_edge(t_ACLK) and t_ARVALID = '1'; 
            
            t_ARREADY <= '0';
            
            t_RVALID <= '1';
            readline(txt_reader, v_ILINE);
            read(v_ILINE, temporary_read_value);
            t_RDATA  <= temporary_read_value;
            t_RRESP  <= "101";
            t_RLAST  <= '1';
            
            wait until rising_edge(t_ACLK) and t_RREADY = '1';
            t_RVALID <= '0';
            t_RLAST  <= '0';
            t_RRESP  <= "000";
            
            packet_count := packet_count + 1;  
        end loop;
        wait;
    end process;
    
    --Response NoC P4
    process
    variable v_oline:line;
    file log_writer : text open write_mode is ("/home/haas/Documents/Github/XINA-IF/traffic/output_P4_SLAVE_traffic.txt");
    begin
        t_l_in_ack_o <= '0';  
        --t_RREADY<='1';
        wait until rising_edge(t_ACLK) and t_l_in_val_i = '1';
        t_l_in_ack_o <= '1';
        write(v_oline,t_l_in_data_i);  
        writeline(log_writer,v_oline);
        wait until rising_edge(t_ACLK) and t_l_in_val_i='0';
        t_l_in_ack_o <= '0';
    end process;



end arch_tb_master_injection_write;