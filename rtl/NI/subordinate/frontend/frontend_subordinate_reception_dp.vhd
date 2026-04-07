library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity frontend_subordinate_reception_dp is
    port(
        VALID_RECEIVE_DATA_i : in std_logic;
        LAST_RECEIVE_DATA_i  : in std_logic;

        ID_RECEIVE_i      : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        LEN_RECEIVE_i     : in std_logic_vector(7 downto 0);
        BURST_RECEIVE_i   : in std_logic_vector(1 downto 0);
        OPC_RECEIVE_i     : in std_logic;
        ADDRESS_RECEIVE_i : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        DATA_RECEIVE_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        CORRUPT_RECEIVE_i : in std_logic;

        AWVALID_EN_i : in std_logic;
        WVALID_EN_i  : in std_logic;
        ARVALID_EN_i : in std_logic;

        AWVALID_o : out std_logic;
        AWID_o    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        AWADDR_o  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        AWLEN_o   : out std_logic_vector(7 downto 0);
        AWBURST_o : out std_logic_vector(1 downto 0);

        WVALID_o : out std_logic;
        WDATA_o  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        WLAST_o  : out std_logic;

        ARVALID_o : out std_logic;
        ARID_o    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        ARADDR_o  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        ARLEN_o   : out std_logic_vector(7 downto 0);
        ARBURST_o : out std_logic_vector(1 downto 0);

        CORRUPT_PACKET_o : out std_logic
    );
end frontend_subordinate_reception_dp;

architecture rtl of frontend_subordinate_reception_dp is
    signal awvalid_w : std_logic;
    signal awid_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal awaddr_w  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    signal awlen_w   : std_logic_vector(7 downto 0);
    signal awburst_w : std_logic_vector(1 downto 0);
    signal wvalid_w  : std_logic;
    signal wdata_w   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal arvalid_w : std_logic;
    signal arid_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal araddr_w  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    signal arlen_w   : std_logic_vector(7 downto 0);
    signal arburst_w : std_logic_vector(1 downto 0);

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of awvalid_w : signal is "TRUE";
    attribute DONT_TOUCH of awid_w : signal is "TRUE";
    attribute DONT_TOUCH of awaddr_w : signal is "TRUE";
    attribute DONT_TOUCH of awlen_w : signal is "TRUE";
    attribute DONT_TOUCH of awburst_w : signal is "TRUE";
    attribute DONT_TOUCH of wvalid_w : signal is "TRUE";
    attribute DONT_TOUCH of wdata_w : signal is "TRUE";
    attribute DONT_TOUCH of arvalid_w : signal is "TRUE";
    attribute DONT_TOUCH of arid_w : signal is "TRUE";
    attribute DONT_TOUCH of araddr_w : signal is "TRUE";
    attribute DONT_TOUCH of arlen_w : signal is "TRUE";
    attribute DONT_TOUCH of arburst_w : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of awvalid_w : signal is true;
    attribute syn_preserve of awid_w : signal is true;
    attribute syn_preserve of awaddr_w : signal is true;
    attribute syn_preserve of awlen_w : signal is true;
    attribute syn_preserve of awburst_w : signal is true;
    attribute syn_preserve of wvalid_w : signal is true;
    attribute syn_preserve of wdata_w : signal is true;
    attribute syn_preserve of arvalid_w : signal is true;
    attribute syn_preserve of arid_w : signal is true;
    attribute syn_preserve of araddr_w : signal is true;
    attribute syn_preserve of arlen_w : signal is true;
    attribute syn_preserve of arburst_w : signal is true;
begin
    awvalid_w <= AWVALID_EN_i;
    awid_w    <= ID_RECEIVE_i when AWVALID_EN_i = '1' else (others => '0');
    awaddr_w  <= ADDRESS_RECEIVE_i & (0 to c_AXI_DATA_WIDTH - 1 => '0') when AWVALID_EN_i = '1' else (others => '0');
    awlen_w   <= LEN_RECEIVE_i when AWVALID_EN_i = '1' else (others => '0');
    awburst_w <= BURST_RECEIVE_i when AWVALID_EN_i = '1' else (others => '0');

    wvalid_w <= WVALID_EN_i;
    wdata_w  <= DATA_RECEIVE_i when VALID_RECEIVE_DATA_i = '1' else (others => '0');

    arvalid_w <= ARVALID_EN_i;
    arid_w    <= ID_RECEIVE_i when ARVALID_EN_i = '1' else (others => '0');
    araddr_w  <= ADDRESS_RECEIVE_i & (0 to c_AXI_DATA_WIDTH - 1 => '0') when ARVALID_EN_i = '1' else (others => '0');
    arlen_w   <= LEN_RECEIVE_i when ARVALID_EN_i = '1' else (others => '0');
    arburst_w <= BURST_RECEIVE_i when ARVALID_EN_i = '1' else (others => '0');

    AWVALID_o <= awvalid_w;
    AWID_o    <= awid_w;
    AWADDR_o  <= awaddr_w;
    AWLEN_o   <= awlen_w;
    AWBURST_o <= awburst_w;

    WVALID_o <= wvalid_w;
    WDATA_o  <= wdata_w;
    WLAST_o  <= LAST_RECEIVE_DATA_i;

    ARVALID_o <= arvalid_w;
    ARID_o    <= arid_w;
    ARADDR_o  <= araddr_w;
    ARLEN_o   <= arlen_w;
    ARBURST_o <= arburst_w;

    CORRUPT_PACKET_o <= CORRUPT_RECEIVE_i;
end rtl;
