library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity ni_subordinate_top is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');

        p_BUFFER_DEPTH      : positive := c_BUFFER_DEPTH;
        p_USE_TMR_PACKETIZER: boolean  := c_ENABLE_SUB_TMR_PACKETIZER;
        p_USE_TMR_FLOW      : boolean  := c_ENABLE_SUB_TMR_FLOW_CTRL;
        p_USE_TMR_INTEGRITY : boolean  := c_ENABLE_SUB_TMR_INTEGRITY_CHECK;
        p_USE_HAMMING       : boolean  := c_ENABLE_SUB_HAMMING_PROTECTION;
        p_USE_INTEGRITY     : boolean  := c_ENABLE_SUB_INTEGRITY_CHECK
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK: in std_logic;
        ARESETn: in std_logic := '1';

            -- Write request signals.
            AWVALID: out std_logic;
            AWREADY: in std_logic;
            AWID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
            AWADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
            AWLEN  : out std_logic_vector(7 downto 0);
            AWSIZE : out std_logic_vector(2 downto 0);
            AWBURST: out std_logic_vector(1 downto 0);

            -- Write data signals.
            WVALID : out std_logic;
            WREADY : in std_logic;
            WDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
            WLAST  : out std_logic;

            -- Write response signals.
            BVALID : in std_logic;
            BREADY : out std_logic;
            BID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
            BRESP  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

            -- Read request signals.
            ARVALID: out std_logic;
            ARREADY: in std_logic;
            ARID   : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
            ARADDR : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
            ARLEN  : out std_logic_vector(7 downto 0);
            ARSIZE : out std_logic_vector(2 downto 0);
            ARBURST: out std_logic_vector(1 downto 0);

            -- Read response/data signals.
            RVALID : in std_logic;
            RREADY : out std_logic;
            RDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
            RLAST  : in std_logic;
            RID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
            RRESP  : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

            -- Extra signals.
            CORRUPT_PACKET: out std_logic;

        -- XINA signals.
        l_in_data_i : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i  : out std_logic;
        l_in_ack_o  : in std_logic;
        l_out_data_o: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in std_logic;
        l_out_ack_i : out std_logic;

        -- Subordinate backend injection FT observability/correction.
        OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o         : out std_logic := '0';

        -- Subordinate backend reception FT observability/correction.
        OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         : out std_logic := '0'
    );
end ni_subordinate_top;

architecture rtl of ni_subordinate_top is
    -- Injection.
    signal VALID_SEND_DATA_w  : std_logic;
    signal LAST_SEND_DATA_w   : std_logic;
    signal READY_SEND_DATA_w  : std_logic;

    signal DATA_SEND_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal STATUS_SEND_w: std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    -- Reception.
    signal READY_RECEIVE_PACKET_w: std_logic;
    signal READY_RECEIVE_DATA_w  : std_logic;

    signal VALID_RECEIVE_PACKET_w: std_logic;
    signal VALID_RECEIVE_DATA_w  : std_logic;
    signal LAST_RECEIVE_DATA_w   : std_logic;

    signal ID_RECEIVE_w     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal LEN_RECEIVE_w    : std_logic_vector(7 downto 0);
    signal BURST_RECEIVE_w  : std_logic_vector(1 downto 0);
    signal OPC_RECEIVE_w    : std_logic;
    signal ADDRESS_RECEIVE_w: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal DATA_RECEIVE_w   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    signal CORRUPT_RECEIVE_w: std_logic;

begin
    u_frontend_subordinate: entity work.frontend_subordinate
        port map(
            -- AMBA AXI 5 signals.
            ACLK => ACLK,
            ARESETn => ARESETn,

                -- Write request signals.
                AWVALID => AWVALID,
                AWREADY => AWREADY,
                AWID    => AWID,
                AWADDR  => AWADDR,
                AWLEN   => AWLEN,
                AWSIZE  => AWSIZE,
                AWBURST => AWBURST,

                -- Write data signals.
                WVALID  => WVALID,
                WREADY  => WREADY,
                WDATA   => WDATA,
                WLAST   => WLAST,

                -- Write response signals.
                BVALID  => BVALID,
                BREADY  => BREADY,
                BID     => BID,
                BRESP   => BRESP,

                -- Read request signals.
                ARVALID => ARVALID,
                ARREADY => ARREADY,
                ARID    => ARID,
                ARADDR  => ARADDR,
                ARLEN   => ARLEN,
                ARSIZE  => ARSIZE,
                ARBURST => ARBURST,

                -- Read response/data signals.
                RVALID  => RVALID,
                RREADY  => RREADY,
                RDATA   => RDATA,
                RLAST   => RLAST,
                RID     => RID,
                RRESP   => RRESP,

                -- Extra signals.
                CORRUPT_PACKET => CORRUPT_PACKET,

            -- Backend signals (injection).
            VALID_SEND_DATA_o   => VALID_SEND_DATA_w,
            LAST_SEND_DATA_o    => LAST_SEND_DATA_w,
            READY_SEND_DATA_i   => READY_SEND_DATA_w,

            DATA_SEND_o   => DATA_SEND_w,
            STATUS_SEND_o => STATUS_SEND_w,

            -- Backend signals (reception).
            READY_RECEIVE_PACKET_o => READY_RECEIVE_PACKET_w,
            READY_RECEIVE_DATA_o   => READY_RECEIVE_DATA_w,

            VALID_RECEIVE_PACKET_i => VALID_RECEIVE_PACKET_w,
            VALID_RECEIVE_DATA_i   => VALID_RECEIVE_DATA_w,
            LAST_RECEIVE_DATA_i    => LAST_RECEIVE_DATA_w,

            ID_RECEIVE_i      => ID_RECEIVE_w,
            LEN_RECEIVE_i     => LEN_RECEIVE_w,
            BURST_RECEIVE_i   => BURST_RECEIVE_w,
            OPC_RECEIVE_i     => OPC_RECEIVE_w,
            ADDRESS_RECEIVE_i => ADDRESS_RECEIVE_w,
            DATA_RECEIVE_i    => DATA_RECEIVE_w,

            CORRUPT_RECEIVE_i => CORRUPT_RECEIVE_w
        );

    u_backend_subordinate: entity work.backend_subordinate
        generic map(
            p_SRC_X => p_SRC_X,
            p_SRC_Y => p_SRC_Y,

            p_BUFFER_DEPTH       => p_BUFFER_DEPTH,
            p_USE_TMR_PACKETIZER => p_USE_TMR_PACKETIZER,
            p_USE_TMR_FLOW       => p_USE_TMR_FLOW,
            p_USE_TMR_INTEGRITY  => p_USE_TMR_INTEGRITY,
            p_USE_HAMMING        => p_USE_HAMMING,
            p_USE_INTEGRITY      => p_USE_INTEGRITY
        )

        port map(
            -- AMBA AXI 5 signals.
            ACLK => ACLK,
            ARESETn => ARESETn,

            -- Backend signals (injection).
            VALID_SEND_DATA_i   => VALID_SEND_DATA_w,
            LAST_SEND_DATA_i    => LAST_SEND_DATA_w,
            READY_SEND_DATA_o   => READY_SEND_DATA_w,

            DATA_SEND_i   => DATA_SEND_w,
            STATUS_SEND_i => STATUS_SEND_w,

            -- Backend signals (reception).
            READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_w,
            READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_w,

            VALID_RECEIVE_PACKET_o => VALID_RECEIVE_PACKET_w,
            VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_w,
            LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_w,

            ID_RECEIVE_o      => ID_RECEIVE_w,
            LEN_RECEIVE_o     => LEN_RECEIVE_w,
            BURST_RECEIVE_o   => BURST_RECEIVE_w,
            OPC_RECEIVE_o     => OPC_RECEIVE_w,
            ADDRESS_RECEIVE_o => ADDRESS_RECEIVE_w,
            DATA_RECEIVE_o    => DATA_RECEIVE_w,

            CORRUPT_RECEIVE_o => CORRUPT_RECEIVE_w,

            -- XINA signals.
            l_in_data_i  => l_in_data_i,
            l_in_val_i   => l_in_val_i,
            l_in_ack_o   => l_in_ack_o,
            l_out_data_o => l_out_data_o,
            l_out_val_o  => l_out_val_o,
            l_out_ack_i  => l_out_ack_i,

            OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i => OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o    => OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o,
            OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o    => OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o      => OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o,
            OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o,
            OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o      => OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o,
            OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o,
            OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
            OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o,

            OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i => OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o    => OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o      => OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o,
            OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o,
            OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o      => OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o,
            OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         => OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o,
            OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
            OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         => OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o
        );
end rtl;
