library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

-- Frontend manager: top-level wrapper keeping the ORIGINAL interface/behaviour,
-- while splitting logic into injection/ejection + controller/datapath.
entity frontend_manager is
    generic(
        p_USE_HAMMING_META_HDR : boolean := c_ENABLE_MGR_FE_INJ_META_HDR_HAMMING;
        p_USE_HAMMING_ADDR     : boolean := c_ENABLE_MGR_FE_INJ_ADDR_HAMMING;
        p_HAMMING_DETECT_DOUBLE: boolean := c_ENABLE_HAMMING_DOUBLE_DETECT
    );
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
        READY_SEND_DATA_i  : in std_logic;
        READY_SEND_PACKET_i: in std_logic;

        START_SEND_PACKET_o: out std_logic;
        VALID_SEND_DATA_o  : out std_logic;
        LAST_SEND_DATA_o   : out std_logic;

        ADDR_o     : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        ID_o       : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        LENGTH_o   : out std_logic_vector(7 downto 0);
        BURST_o    : out std_logic_vector(1 downto 0);
        OPC_SEND_o : out std_logic;
        DATA_SEND_o: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Backend signals (reception).
        VALID_RECEIVE_DATA_i: in std_logic;
        LAST_RECEIVE_DATA_i : in std_logic;

        ID_RECEIVE_i    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        STATUS_RECEIVE_i: in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        OPC_RECEIVE_i   : in std_logic;
        DATA_RECEIVE_i  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        CORRUPT_RECEIVE_i: in std_logic;

        READY_RECEIVE_PACKET_o: out std_logic;
        READY_RECEIVE_DATA_o  : out std_logic;

        -- Frontend injection Hamming detection flags (exported to top)
        OBS_FE_INJ_META_HDR_SINGLE_ERR_o : out std_logic;
        OBS_FE_INJ_META_HDR_DOUBLE_ERR_o : out std_logic;
        OBS_FE_INJ_ADDR_SINGLE_ERR_o     : out std_logic;
        OBS_FE_INJ_ADDR_DOUBLE_ERR_o     : out std_logic;
        OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o : out std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), p_HAMMING_DETECT_DOUBLE) - 1 downto 0);
        OBS_FE_INJ_HAM_ADDR_ENC_DATA_o     : out std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0);

        -- Frontend injection Hamming correction enables (from top)
        OBS_FE_INJ_META_HDR_CORRECT_ERROR_i : in std_logic := '1';
        OBS_FE_INJ_ADDR_CORRECT_ERROR_i     : in std_logic := '1'
    );
end frontend_manager;

architecture rtl of frontend_manager is

    -- Injection internal signals
    signal cap_aw_w    : std_logic;
    signal cap_ar_w    : std_logic;
    signal opc_send_w  : std_logic;

    -- Frontend injection Hamming detection flags
    signal fe_inj_meta_hdr_single_err_w : std_logic;
    signal fe_inj_meta_hdr_double_err_w : std_logic;
    signal fe_inj_addr_single_err_w     : std_logic;
    signal fe_inj_addr_double_err_w     : std_logic;
    signal fe_inj_meta_hdr_enc_data_w   : std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), p_HAMMING_DETECT_DOUBLE) - 1 downto 0);
    signal fe_inj_addr_enc_data_w       : std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0);

    -- Ejection internal signals
    signal bvalid_en_w : std_logic;
    signal rvalid_en_w : std_logic;

begin

    ---------------------------------------------------------------------------------------------
    -- Injection (AXI -> backend send)

    u_injection_ctrl: entity work.frontend_manager_injection_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

                AWVALID_i => AWVALID,
                ARVALID_i => ARVALID,
                WVALID_i  => WVALID,
                WLAST_i   => WLAST,

        READY_SEND_PACKET_i => READY_SEND_PACKET_i,
        READY_SEND_DATA_i   => READY_SEND_DATA_i,

        OPC_SEND_R_i => opc_send_w,

        CAP_AW_o => cap_aw_w,
        CAP_AR_o => cap_ar_w,

        START_SEND_PACKET_o => START_SEND_PACKET_o,
        VALID_SEND_DATA_o   => VALID_SEND_DATA_o,
        LAST_SEND_DATA_o    => LAST_SEND_DATA_o,

                AWREADY_o => AWREADY,
                ARREADY_o => ARREADY,
                WREADY_o  => WREADY
      );

    u_injection_dp: entity work.frontend_manager_injection_dp
      generic map(
        p_USE_HAMMING_META_HDR => p_USE_HAMMING_META_HDR,
        p_USE_HAMMING_ADDR     => p_USE_HAMMING_ADDR,
        p_HAMMING_DETECT_DOUBLE=> p_HAMMING_DETECT_DOUBLE
      )
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        CAP_AW_i => cap_aw_w,
        CAP_AR_i => cap_ar_w,

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

        META_HDR_CORRECT_ERROR_i => OBS_FE_INJ_META_HDR_CORRECT_ERROR_i,
        ADDR_CORRECT_ERROR_i     => OBS_FE_INJ_ADDR_CORRECT_ERROR_i,

        ADDR_o      => ADDR_o,
        ID_o        => ID_o,
        LENGTH_o    => LENGTH_o,
        BURST_o     => BURST_o,
        OPC_SEND_o  => opc_send_w,
        DATA_SEND_o => DATA_SEND_o,

        META_HDR_SINGLE_ERR_o => fe_inj_meta_hdr_single_err_w,
        META_HDR_DOUBLE_ERR_o => fe_inj_meta_hdr_double_err_w,
        ADDR_SINGLE_ERR_o     => fe_inj_addr_single_err_w,
        ADDR_DOUBLE_ERR_o     => fe_inj_addr_double_err_w,
        META_HDR_ENC_DATA_o   => fe_inj_meta_hdr_enc_data_w,
        ADDR_ENC_DATA_o       => fe_inj_addr_enc_data_w
      );

    -- expose opcode to backend with the same name as before
    OPC_SEND_o <= opc_send_w;

    ---------------------------------------------------------------------------------------------
    -- Ejection (backend receive -> AXI)

    u_ejection_ctrl: entity work.frontend_manager_ejection_ctrl
      port map(
        VALID_RECEIVE_DATA_i => VALID_RECEIVE_DATA_i,
        OPC_RECEIVE_i        => OPC_RECEIVE_i,

        BREADY => BREADY,
        RREADY => RREADY,

        READY_RECEIVE_PACKET_o => READY_RECEIVE_PACKET_o,
        READY_RECEIVE_DATA_o   => READY_RECEIVE_DATA_o,

        BVALID_EN_o => bvalid_en_w,
        RVALID_EN_o => rvalid_en_w
      );

    u_ejection_dp: entity work.frontend_manager_ejection_dp
      port map(
        LAST_RECEIVE_DATA_i => LAST_RECEIVE_DATA_i,
        ID_RECEIVE_i        => ID_RECEIVE_i,
        STATUS_RECEIVE_i    => STATUS_RECEIVE_i,
        DATA_RECEIVE_i      => DATA_RECEIVE_i,
        CORRUPT_RECEIVE_i   => CORRUPT_RECEIVE_i,

        BVALID_EN_i => bvalid_en_w,
        RVALID_EN_i => rvalid_en_w,

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
    OBS_FE_INJ_META_HDR_SINGLE_ERR_o <= fe_inj_meta_hdr_single_err_w;
    OBS_FE_INJ_META_HDR_DOUBLE_ERR_o <= fe_inj_meta_hdr_double_err_w;
    OBS_FE_INJ_ADDR_SINGLE_ERR_o     <= fe_inj_addr_single_err_w;
    OBS_FE_INJ_ADDR_DOUBLE_ERR_o     <= fe_inj_addr_double_err_w;
    OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o <= fe_inj_meta_hdr_enc_data_w;
    OBS_FE_INJ_HAM_ADDR_ENC_DATA_o     <= fe_inj_addr_enc_data_w;

end rtl;
