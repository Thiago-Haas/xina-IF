library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Injection datapath: registers AW/AR header fields and opcode.
entity frontend_manager_injection_dp is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Capture strobes (1-cycle pulses)
    i_CAP_AW : in std_logic;
    i_CAP_AR : in std_logic;

    -- AXI header sources
    AWID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : in std_logic_vector(7 downto 0);
    AWBURST : in std_logic_vector(1 downto 0);

    ARID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : in std_logic_vector(7 downto 0);
    ARBURST : in std_logic_vector(1 downto 0);

    -- AXI data source
    WVALID : in std_logic;
    WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Outputs to backend
    o_ADDR      : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    o_ID        : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_LENGTH    : out std_logic_vector(7 downto 0);
    o_BURST     : out std_logic_vector(1 downto 0);
    o_OPC_SEND  : out std_logic;
    o_DATA_SEND : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of frontend_manager_injection_dp is
  signal opc_send_r : std_logic := '0';
  signal addr_r     : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal id_r       : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0)   := (others => '0');
  signal len_r      : std_logic_vector(7 downto 0)                    := (others => '0');
  signal burst_r    : std_logic_vector(1 downto 0)                    := (others => '0');
begin

  -- Registering transaction information.
  -- NOTE: No reset behaviour is applied to preserve original module semantics.
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if i_CAP_AW = '1' then
        -- Write request
        opc_send_r <= '0';
        addr_r    <= AWADDR;
        id_r      <= AWID;
        len_r     <= AWLEN;
        burst_r   <= AWBURST;
      elsif i_CAP_AR = '1' then
        -- Read request
        opc_send_r <= '1';
        addr_r    <= ARADDR;
        id_r      <= ARID;
        len_r     <= ARLEN;
        burst_r   <= ARBURST;
      end if;
    end if;
  end process;

  o_OPC_SEND <= opc_send_r;
  o_ADDR     <= addr_r;
  o_ID       <= id_r;
  o_LENGTH   <= len_r;
  o_BURST    <= burst_r;

  -- Preserve original data send behaviour (only meaningful for writes and when WVALID=1)
  o_DATA_SEND <= WDATA when (opc_send_r = '0' and WVALID = '1') else (others => '0');

end architecture;
