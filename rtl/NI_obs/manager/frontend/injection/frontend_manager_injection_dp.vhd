library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Injection datapath (AXI -> backend send)
--  * Holds LARGE registers (intended for future ECC/Hamming protection).
--  * Registers address/ID/length/burst on request capture.
--  * Passes write data to backend (no buffering, preserves original behaviour).
entity frontend_manager_injection_dp is
  port(
    -- AMBA AXI clock / reset.
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Capture strobes (1-cycle pulses).
    i_CAP_AW : in std_logic;
    i_CAP_AR : in std_logic;

    -- Registered opcode from controller (0=write, 1=read).
    i_OPC_SEND : in std_logic;

    -- AXI header sources.
    i_AWID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    i_AWADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    i_AWLEN   : in std_logic_vector(7 downto 0);
    i_AWBURST : in std_logic_vector(1 downto 0);

    i_ARID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    i_ARADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    i_ARLEN   : in std_logic_vector(7 downto 0);
    i_ARBURST : in std_logic_vector(1 downto 0);

    -- AXI write data source.
    i_WVALID : in std_logic;
    i_WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Outputs to backend.
    o_ADDR      : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    o_ID        : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_LENGTH    : out std_logic_vector(7 downto 0);
    o_BURST     : out std_logic_vector(1 downto 0);
    o_DATA_SEND : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of frontend_manager_injection_dp is

  -- LARGE registers (candidate for ECC/Hamming).
  signal addr_r   : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal id_r     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal length_r : std_logic_vector(7 downto 0);
  signal burst_r  : std_logic_vector(1 downto 0);

begin

  ---------------------------------------------------------------------------------------------
  -- Register request header fields

  process (all)
  begin
    if (ARESETn = '0') then
      addr_r   <= (others => '0');
      id_r     <= (others => '0');
      length_r <= (others => '0');
      burst_r  <= (others => '0');
    elsif rising_edge(ACLK) then
      if (i_CAP_AW = '1') then
        addr_r   <= i_AWADDR;
        id_r     <= i_AWID;
        length_r <= i_AWLEN;
        burst_r  <= i_AWBURST;
      elsif (i_CAP_AR = '1') then
        addr_r   <= i_ARADDR;
        id_r     <= i_ARID;
        length_r <= i_ARLEN;
        burst_r  <= i_ARBURST;
      end if;
    end if;
  end process;

  o_ADDR   <= addr_r;
  o_ID     <= id_r;
  o_LENGTH <= length_r;
  o_BURST  <= burst_r;

  ---------------------------------------------------------------------------------------------
  -- Preserve original data-send behaviour:
  -- only meaningful for writes and only when WVALID=1, otherwise zeros.

  o_DATA_SEND <= i_WDATA when (i_OPC_SEND = '0' and i_WVALID = '1') else (others => '0');

end architecture;
