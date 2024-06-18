library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity traffic_generator_for_manual_integration is
    port(
      -- AMBA-AXI 5 signals.
      ACLK  : in std_logic;
      RESET : in std_logic;
      ARESETn : in std_logic;
      -------------------
      -- MASTER SIGNALS.
      -- Write request signals.
      AWVALID: out std_logic;
      AWREADY: in std_logic;
      AWID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
      AWADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
      AWLEN  : out std_logic_vector(7 downto 0);
      AWBURST: out std_logic_vector(1 downto 0);
      -- Write data signals.
      WVALID : out std_logic;
      WREADY : in std_logic;
      WDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
      WLAST  : out std_logic;

       -- Write response signals.
      BVALID : in std_logic;
      BREADY : out std_logic;
      BID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
      BRESP  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

      -- Read request signals.
      ARVALID: out std_logic;
      ARREADY: in std_logic;
      ARID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
      ARADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
      ARLEN  : out std_logic_vector(7 downto 0);
      ARBURST: out std_logic_vector(1 downto 0);

      -- Read response/data signals.
      RVALID : in std_logic;
      RREADY : out std_logic;
      RDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
      RLAST  : in std_logic;
      RID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
      RRESP  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
 
      -- Extra signals.
      CORRUPT_PACKET: in std_logic 
    );
end traffic_generator_for_manual_integration;

architecture Behavioral of traffic_generator_for_manual_integration is
signal w_ACLK  : std_logic := '0';

-- Write request signals.
signal w_AWVALID: std_logic := '0';
--signal w_AWREADY: std_logic := '0';
signal w_AWID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal w_AWADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
signal w_AWLEN  : std_logic_vector(7 downto 0) := "00000000";
signal w_AWBURST: std_logic_vector(1 downto 0) := "01";

-- Write data signals.
signal w_WVALID : std_logic := '0';
--signal w_WREADY : std_logic := '0';
signal w_WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
signal w_WLAST  : std_logic := '0';

-- Write response signals.
--signal w_BVALID : std_logic := '0';
signal w_BREADY : std_logic := '0';
--signal w_BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
--signal w_BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

-- Read request signals.
signal w_ARVALID: std_logic := '0';
--signal w_ARREADY: std_logic := '0';
signal w_ARID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
signal w_ARADDR : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
signal w_ARLEN  : std_logic_vector(7 downto 0) := "00000000";
signal w_ARBURST: std_logic_vector(1 downto 0) := "01";

-- Read response/data signals.
signal w_RVALID : std_logic := '0';
signal w_RREADY : std_logic := '0';
--signal w_RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
--signal w_RLAST  : std_logic := '0';
--signal w_RID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
--signal w_RRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

-- Extra signals.
--signal w_CORRUPT_PACKET: std_logic;

--FSM                                     
signal current_state : std_logic := '0';  
signal next_state    : std_logic;         
signal state_w: integer range 0 to 5 := 0;
signal n_counter  : integer := 0;
signal n_vector   : std_logic_vector(31 downto 0) := (others => '0');

begin
    -- AMBA-AXI 5 signals.
    --ACLK   <= w_ACLK;
    --RESETn <= w_RESETn;
    -------------------
    -- MASTER SIGNALS.
    -- Write request signals.
    AWVALID <= w_AWVALID;
    --AWREADY <= w_AWREADY;
    AWID    <= w_AWID;
    AWADDR  <= w_AWADDR;
    AWLEN   <= w_AWLEN;
    AWBURST <= w_AWBURST;

    -- Write data signals.
    WVALID <= w_WVALID;
    --WREADY <= w_WREADY;
    WDATA  <= w_WDATA;
    WLAST  <= w_WLAST;

    -- Write response signals.
    --BVALID <= w_BVALID;
    BREADY <= w_BREADY;
    --BID    <= w_BID;
    --BRESP  <= w_BRESP;

    -- Read request signals.
    ARVALID <= w_ARVALID;
    --ARREADY <= w_ARREADY;
    ARID    <= w_ARID;
    ARADDR  <= w_ARADDR;
    ARLEN   <= w_ARLEN;
    ARBURST <= w_ARBURST;

    -- Read response/data signals.
    --RVALID <= w_RVALID;
    RREADY <= w_RREADY;
    --RDATA  <= w_RDATA;
    --RLAST  <= w_RLAST;
    --RID    <= w_RID;
    --RRESP  <= w_RRESP;

    -- Extra signals.
    --CORRUPT_PACKET <= w_CORRUPT_PACKET;
    
  --FSM
  process (all)
  begin
    if (RESET = '1') then
        current_state <= '0';
    elsif (rising_edge(ACLK)) then
        current_state <= next_state;
    end if;
  end process;

  process(all)
    begin
      if state_w = 0 then
        null;
        
      elsif state_w = 1 then
        -- Reset.
        w_RREADY <= '0'; 
        
        w_AWVALID <= '1';
        w_AWADDR <= "0000000000000000" & "0000000000000000" & "0000000000000001" & "0000000000000000";
        w_AWID <= "00001";
        w_AWLEN <= "00000000";
        
        
      elsif state_w = 2 then
        -- Reset.
        w_AWVALID <= '0';
        w_AWADDR <= (others => '0');
        w_AWID <= (others => '0');
        w_AWLEN <= (others => '0');

        -- Flit 1.
        w_WVALID <= '1';
        --w_WDATA <= "00000000000000000000000000000001";
        w_WDATA <= std_logic_vector(unsigned(n_vector) + n_counter);
        w_WLAST <= '1';
        
      elsif state_w = 3 then
        -- Reset.
        w_WDATA <= (others => '0');
        w_WVALID <= '0';
        w_WLAST <= '0';
        ---------------------------------------------------------------------------------------------
        -- Receive first transaction response.
        w_BREADY <= '1';  
        
 
      elsif state_w = 4 then
        w_BREADY <= '0';
        ---------------------------------------------------------------------------------------------
        -- Second transaction (read).
        w_ARVALID <= '1';
        w_ARADDR <= "0000000000000000" & "0000000000000000" & "0000000000000001" & "0000000000000000";
        w_ARID <= "00010";
        w_ARLEN <= "00000000";
         
      elsif state_w = 5 then
        -- Reset.
        w_ARVALID <= '0';
        w_ARADDR <= (others => '0');
        w_ARID <= (others => '0');
        w_ARLEN <= (others => '0');
        ---------------------------------------------------------------------------------------------
        -- Receive second transaction response.
        w_RREADY <= '1'; 
        
      --elsif state_w = 6 then
        -- Reset.
        --w_RREADY <= '0'; 
      end if;
  end process;

  process(all)
    begin
      if (RESET = '1') then
        state_w <= 0;
      elsif(rising_edge(ACLK)) then
        if (ARESETn = '0') then
          state_w <= 1;
        elsif (AWREADY = '1' and state_w = 1) then
          state_w <= 2;
        elsif (WREADY = '1' and state_w = 2) then
          state_w <= 3;
        elsif (BVALID = '1' and state_w = 3) then 
          state_w <= 4;
        elsif (ARREADY = '1' and state_w = 4) then 
          state_w <= 5;
        elsif (RVALID = '1' and RLAST = '1' and state_w = 5) then
          state_w <= 1;
          n_counter<=n_counter+1;
        end if;
      end if;
  end process;

  process (all)
  begin
    case current_state is
      when '0' =>
        if (ACLK = '1') then
          next_state <= '1';
        else
          next_state <= '0';
        end if;
      when '1' =>
        if (ACLK = '0') then
          next_state <= '0';
        else
          next_state <= '1';
        end if;
     when others => next_state <= '0';
    end case;
  end process;

end Behavioral;