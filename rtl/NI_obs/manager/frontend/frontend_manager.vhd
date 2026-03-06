library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

-- Frontend manager: top-level wrapper keeping the ORIGINAL interface/behaviour,
-- while splitting logic into injection/ejection + controller/datapath.
entity frontend_manager is
    port(
        -- AMBA AXI 5 signals.
        ACLK: in std_logic;
        ARESETn: in std_logic;

        -- Write request signals.
        AWVALID: in std_logic;
        AWREADY: out std_logic;
        AWID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        AWADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        AWLEN  : in std_logic_vector(7 downto 0);
        AWBURST: in std_logic_vector(1 downto 0);

        -- Write data signals.
        WVALID : in std_logic;
        WREADY : out std_logic;
        WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        WLAST  : in std_logic;

        -- Write response signals.
        BVALID : out std_logic;
        BREADY : in std_logic;
        BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Read request signals.
        ARVALID: in std_logic;
        ARREADY: out std_logic;
        ARID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        ARADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        ARLEN  : in std_logic_vector(7 downto 0);
        ARBURST: in std_logic_vector(1 downto 0);

        -- Read response/data signals.
        RVALID : out std_logic;
        RREADY : in std_logic;
        RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        RLAST  : out std_logic;
        RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
        RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

        -- Extra signals.
        CORRUPT_PACKET: out std_logic;

        -- Backend signals (injection).
        i_READY_SEND_DATA  : in std_logic;
        i_READY_SEND_PACKET: in std_logic;

        o_START_SEND_PACKET: out std_logic;
        o_VALID_SEND_DATA  : out std_logic;
        o_LAST_SEND_DATA   : out std_logic;

        o_ADDR     : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        o_ID       : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        o_LENGTH   : out std_logic_vector(7 downto 0);
        o_BURST    : out std_logic_vector(1 downto 0);
        o_OPC_SEND : out std_logic;
        o_DATA_SEND: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Backend signals (reception).
        i_VALID_RECEIVE_DATA: in std_logic;
        i_LAST_RECEIVE_DATA : in std_logic;

        i_ID_RECEIVE    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        i_STATUS_RECEIVE: in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        i_OPC_RECEIVE   : in std_logic;
        i_DATA_RECEIVE  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        i_CORRUPT_RECEIVE: in std_logic;

        o_READY_RECEIVE_PACKET: out std_logic;
        o_READY_RECEIVE_DATA  : out std_logic;

        -- Frontend injection Hamming detection flags (exported to top)
        o_OBS_FE_INJ_META_HDR_SINGLE_ERR : out std_logic;
        o_OBS_FE_INJ_META_HDR_DOUBLE_ERR : out std_logic;
        o_OBS_FE_INJ_ADDR_SINGLE_ERR     : out std_logic;
        o_OBS_FE_INJ_ADDR_DOUBLE_ERR     : out std_logic
    );
end frontend_manager;

architecture rtl of frontend_manager is

    -- Injection internal signals
    signal w_cap_aw    : std_logic;
    signal w_cap_ar    : std_logic;
    signal w_opc_send  : std_logic;

    -- Frontend injection Hamming detection flags
    signal w_fe_inj_meta_hdr_single_err : std_logic;
    signal w_fe_inj_meta_hdr_double_err : std_logic;
    signal w_fe_inj_addr_single_err     : std_logic;
    signal w_fe_inj_addr_double_err     : std_logic;

    -- Ejection internal signals
    signal w_bvalid_en : std_logic;
    signal w_rvalid_en : std_logic;

begin

    ---------------------------------------------------------------------------------------------
    -- Injection (AXI -> backend send)

    u_injection_ctrl: entity work.frontend_manager_injection_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

                i_AWVALID => AWVALID,
                i_ARVALID => ARVALID,
                i_WVALID  => WVALID,
                i_WLAST   => WLAST,

        i_READY_SEND_PACKET => i_READY_SEND_PACKET,
        i_READY_SEND_DATA   => i_READY_SEND_DATA,

        i_OPC_SEND_R => w_opc_send,

        o_CAP_AW => w_cap_aw,
        o_CAP_AR => w_cap_ar,

        o_START_SEND_PACKET => o_START_SEND_PACKET,
        o_VALID_SEND_DATA   => o_VALID_SEND_DATA,
        o_LAST_SEND_DATA    => o_LAST_SEND_DATA,

                o_AWREADY => AWREADY,
                o_ARREADY => ARREADY,
                o_WREADY  => WREADY
      );

    u_injection_dp: entity work.frontend_manager_injection_dp
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_CAP_AW => w_cap_aw,
        i_CAP_AR => w_cap_ar,

        AWID    => AWID,
        AWADDR  => AWADDR,
        AWLEN   => AWLEN,
        AWBURST => AWBURST,

        ARID    => ARID,
        ARADDR  => ARADDR,
        ARLEN   => ARLEN,
        ARBURST => ARBURST,

        WVALID => WVALID,
        WDATA  => WDATA,

        o_ADDR      => o_ADDR,
        o_ID        => o_ID,
        o_LENGTH    => o_LENGTH,
        o_BURST     => o_BURST,
        o_OPC_SEND  => w_opc_send,
        o_DATA_SEND => o_DATA_SEND,

        o_META_HDR_SINGLE_ERR => w_fe_inj_meta_hdr_single_err,
        o_META_HDR_DOUBLE_ERR => w_fe_inj_meta_hdr_double_err,
        o_ADDR_SINGLE_ERR     => w_fe_inj_addr_single_err,
        o_ADDR_DOUBLE_ERR     => w_fe_inj_addr_double_err
      );

    -- expose opcode to backend with the same name as before
    o_OPC_SEND <= w_opc_send;

    ---------------------------------------------------------------------------------------------
    -- Ejection (backend receive -> AXI)

    u_ejection_ctrl: entity work.frontend_manager_ejection_ctrl
      port map(
        i_VALID_RECEIVE_DATA => i_VALID_RECEIVE_DATA,
        i_OPC_RECEIVE        => i_OPC_RECEIVE,

        BREADY => BREADY,
        RREADY => RREADY,

        o_READY_RECEIVE_PACKET => o_READY_RECEIVE_PACKET,
        o_READY_RECEIVE_DATA   => o_READY_RECEIVE_DATA,

        o_BVALID_EN => w_bvalid_en,
        o_RVALID_EN => w_rvalid_en
      );

    u_ejection_dp: entity work.frontend_manager_ejection_dp
      port map(
        i_LAST_RECEIVE_DATA => i_LAST_RECEIVE_DATA,
        i_ID_RECEIVE        => i_ID_RECEIVE,
        i_STATUS_RECEIVE    => i_STATUS_RECEIVE,
        i_DATA_RECEIVE      => i_DATA_RECEIVE,
        i_CORRUPT_RECEIVE   => i_CORRUPT_RECEIVE,

        i_BVALID_EN => w_bvalid_en,
        i_RVALID_EN => w_rvalid_en,

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

    -- Export frontend injection Hamming detection flags
    o_OBS_FE_INJ_META_HDR_SINGLE_ERR <= w_fe_inj_meta_hdr_single_err;
    o_OBS_FE_INJ_META_HDR_DOUBLE_ERR <= w_fe_inj_meta_hdr_double_err;
    o_OBS_FE_INJ_ADDR_SINGLE_ERR     <= w_fe_inj_addr_single_err;
    o_OBS_FE_INJ_ADDR_DOUBLE_ERR     <= w_fe_inj_addr_double_err;

end rtl;
