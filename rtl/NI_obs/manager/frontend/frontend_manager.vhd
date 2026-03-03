library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

-- Frontend manager
--  * Keeps the ORIGINAL external interface.
--  * Internally split into injection/ejection paths.
--  * Each path is split into controller + datapath.
--
-- Naming convention (aligned with backend style):
--  * *_r  : registered elements
--  * *_w  : combinational wires
entity frontend_manager is
    port(
        -- AMBA AXI 5 signals.
        ACLK    : in  std_logic;
        ARESETn : in  std_logic;

        -- Write request signals.
        AWVALID : in  std_logic;
        AWREADY : out std_logic;
        AWID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        AWADDR  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        AWLEN   : in  std_logic_vector(7 downto 0);
        AWBURST : in  std_logic_vector(1 downto 0);

        -- Write data signals.
        WVALID : in  std_logic;
        WREADY : out std_logic;
        WDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        WLAST  : in  std_logic;

        -- Write response signals.
        BVALID : out std_logic;
        BREADY : in  std_logic;
        BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Read request signals.
        ARVALID : in  std_logic;
        ARREADY : out std_logic;
        ARID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        ARADDR  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        ARLEN   : in  std_logic_vector(7 downto 0);
        ARBURST : in  std_logic_vector(1 downto 0);

        -- Read response/data signals.
        RVALID : out std_logic;
        RREADY : in  std_logic;
        RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        RLAST  : out std_logic;
        RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Extra signals.
        CORRUPT_PACKET : out std_logic;

        -- Backend signals (injection).
        i_READY_SEND_DATA   : in std_logic;
        i_READY_SEND_PACKET : in std_logic;

        o_START_SEND_PACKET : out std_logic;
        o_VALID_SEND_DATA   : out std_logic;
        o_LAST_SEND_DATA    : out std_logic;

        o_ADDR      : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        o_ID        : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        o_LENGTH    : out std_logic_vector(7 downto 0);
        o_BURST     : out std_logic_vector(1 downto 0);
        o_OPC_SEND  : out std_logic;
        o_DATA_SEND : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Backend signals (reception).
        i_VALID_RECEIVE_DATA : in std_logic;
        i_LAST_RECEIVE_DATA  : in std_logic;

        i_ID_RECEIVE     : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        i_STATUS_RECEIVE : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        i_OPC_RECEIVE    : in std_logic;
        i_DATA_RECEIVE   : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        i_CORRUPT_RECEIVE : in std_logic;

        o_READY_RECEIVE_PACKET : out std_logic;
        o_READY_RECEIVE_DATA   : out std_logic
    );
end frontend_manager;

architecture rtl of frontend_manager is

    ---------------------------------------------------------------------------------------------
    -- Injection internal signals

    signal cap_aw_w   : std_logic;
    signal cap_ar_w   : std_logic;
    signal opc_send_w : std_logic;

    ---------------------------------------------------------------------------------------------
    -- Ejection internal signals

    signal bvalid_en_w : std_logic;
    signal rvalid_en_w : std_logic;

begin

    ---------------------------------------------------------------------------------------------
    -- Injection path (AXI -> backend send)

    u_frontend_manager_injection_ctrl: entity work.frontend_manager_injection_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_AWVALID => AWVALID,
        i_ARVALID => ARVALID,
        i_WVALID  => WVALID,
        i_WLAST   => WLAST,

        i_READY_SEND_PACKET => i_READY_SEND_PACKET,
        i_READY_SEND_DATA   => i_READY_SEND_DATA,

        -- Opcode comes from datapath registered header bundle (future ECC target)
        i_OPC_SEND => opc_send_w,

        o_CAP_AW => cap_aw_w,
        o_CAP_AR => cap_ar_w,

        o_START_SEND_PACKET => o_START_SEND_PACKET,
        o_VALID_SEND_DATA   => o_VALID_SEND_DATA,
        o_LAST_SEND_DATA    => o_LAST_SEND_DATA,

        o_AWREADY => AWREADY,
        o_ARREADY => ARREADY,
        o_WREADY  => WREADY
      );

    u_frontend_manager_injection_dp: entity work.frontend_manager_injection_dp
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_CAP_AW => cap_aw_w,
        i_CAP_AR => cap_ar_w,

        i_AWID    => AWID,
        i_AWADDR  => AWADDR,
        i_AWLEN   => AWLEN,
        i_AWBURST => AWBURST,

        i_ARID    => ARID,
        i_ARADDR  => ARADDR,
        i_ARLEN   => ARLEN,
        i_ARBURST => ARBURST,

        i_WVALID => WVALID,
        i_WDATA  => WDATA,

        o_ADDR      => o_ADDR,
        o_ID        => o_ID,
        o_LENGTH    => o_LENGTH,
        o_BURST     => o_BURST,
        o_OPC_SEND  => opc_send_w,
        o_DATA_SEND => o_DATA_SEND
      );

    -- Expose opcode to backend with the original port name.
    o_OPC_SEND <= opc_send_w;

    ---------------------------------------------------------------------------------------------
    -- Ejection path (backend receive -> AXI)

    u_frontend_manager_ejection_ctrl: entity work.frontend_manager_ejection_ctrl
      port map(
        i_VALID_RECEIVE_DATA => i_VALID_RECEIVE_DATA,
        i_OPC_RECEIVE        => i_OPC_RECEIVE,

        BREADY => BREADY,
        RREADY => RREADY,

        o_READY_RECEIVE_PACKET => o_READY_RECEIVE_PACKET,
        o_READY_RECEIVE_DATA   => o_READY_RECEIVE_DATA,

        o_BVALID_EN => bvalid_en_w,
        o_RVALID_EN => rvalid_en_w
      );

    u_frontend_manager_ejection_dp: entity work.frontend_manager_ejection_dp
      port map(
        i_LAST_RECEIVE_DATA => i_LAST_RECEIVE_DATA,
        i_ID_RECEIVE        => i_ID_RECEIVE,
        i_STATUS_RECEIVE    => i_STATUS_RECEIVE,
        i_DATA_RECEIVE      => i_DATA_RECEIVE,
        i_CORRUPT_RECEIVE   => i_CORRUPT_RECEIVE,

        i_BVALID_EN => bvalid_en_w,
        i_RVALID_EN => rvalid_en_w,

        BVALID => BVALID,
        BID    => BID,
        BRESP  => BRESP,

        RVALID => RVALID,
        RDATA  => RDATA,
        RLAST  => RLAST,
        RID    => RID,
        RRESP  => RRESP,

        CORRUPT_PACKET => CORRUPT_PACKET
      );

end rtl;
