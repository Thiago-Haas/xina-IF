library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity tg_manager_datapath is
  generic(
    p_AWID  : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    p_ARID  : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    p_LEN   : std_logic_vector(7 downto 0) := x"00";
    p_BURST : std_logic_vector(1 downto 0) := "01"
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- inputs
    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);

    i_lfsr_value    : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    i_load_wdata    : in  std_logic;

    i_rdata_in       : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    i_capture_rdata  : in  std_logic;

    -- outputs to AXI
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);

    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic;

    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);

    -- optional debug
    o_rdata_captured : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of tg_manager_datapath is
  signal r_wdata : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal r_rdata : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
begin

  -- Constant fields
  AWADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  AWID    <= p_AWID;
  AWLEN   <= p_LEN;
  AWBURST <= p_BURST;

  ARADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  ARID    <= p_ARID;
  ARLEN   <= p_LEN;
  ARBURST <= p_BURST;

  -- Single-beat
  WLAST <= '1';

  -- Output data
  WDATA <= r_wdata;

  o_rdata_captured <= r_rdata;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_wdata <= (others => '0');
        r_rdata <= (others => '0');
      else
        -- Hold WDATA stable; load only when controller says so
        if i_load_wdata = '1' then
          r_wdata <= i_lfsr_value;
        end if;

        -- Optional: capture RDATA at end of read
        if i_capture_rdata = '1' then
          r_rdata <= i_rdata_in;
        end if;
      end if;
    end if;
  end process;

end rtl;