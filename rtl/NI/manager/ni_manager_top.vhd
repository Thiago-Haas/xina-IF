library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

entity ni_manager_top is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');

        p_BUFFER_DEPTH      : positive := c_BUFFER_DEPTH;
        p_USE_TMR_PACKETIZER: boolean  := c_ENABLE_TMR_PACKETIZER;
        p_USE_TMR_FLOW      : boolean  := c_ENABLE_TMR_FLOW_CTRL;
        p_USE_HAMMING       : boolean  := c_ENABLE_HAMMING_PROTECTION;
        p_USE_INTEGRITY     : boolean  := c_ENABLE_INTEGRITY_CHECK;

        -- Fine-grain ECC/TMR enables (manager path)
        p_USE_FE_INJ_META_HDR_HAMMING : boolean := c_ENABLE_MGR_FE_INJ_META_HDR_HAMMING;
        p_USE_FE_INJ_ADDR_HAMMING     : boolean := c_ENABLE_MGR_FE_INJ_ADDR_HAMMING;

        p_USE_BE_INJ_BUFFER_HAMMING    : boolean := c_ENABLE_MGR_BE_INJ_BUFFER_HAMMING;
        p_USE_BE_INJ_PKTZ_CTRL_TMR     : boolean := c_ENABLE_MGR_BE_INJ_PKTZ_CTRL_TMR;
        p_USE_BE_INJ_FLOW_CTRL_TMR     : boolean := c_ENABLE_MGR_BE_INJ_FLOW_CTRL_TMR;
        p_USE_BE_INJ_INTEGRITY_CHECK   : boolean := c_ENABLE_MGR_BE_INJ_INTEGRITY_CHECK;

        p_USE_BE_RX_BUFFER_HAMMING     : boolean := c_ENABLE_MGR_BE_RX_BUFFER_HAMMING;
        p_USE_BE_RX_INTERFACE_HDR_HAMMING : boolean := c_ENABLE_MGR_BE_RX_INTERFACE_HDR_HAMMING;
        p_USE_BE_RX_DEPKTZ_CTRL_TMR    : boolean := c_ENABLE_MGR_BE_RX_DEPKTZ_CTRL_TMR;
        p_USE_BE_RX_FLOW_CTRL_TMR      : boolean := c_ENABLE_MGR_BE_RX_FLOW_CTRL_TMR;
        p_USE_BE_RX_INTEGRITY_CHECK    : boolean := c_ENABLE_MGR_BE_RX_INTEGRITY_CHECK;

        DETECT_DOUBLE       : boolean  := c_ENABLE_HAMMING_DOUBLE_DETECT
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic := '1';

            -- Write request signals.
            AWVALID: in std_logic;
            AWREADY: out std_logic;
            AWID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
            AWADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
            AWLEN  : in std_logic_vector(7 downto 0) := (others => '0');
            AWBURST: in std_logic_vector(1 downto 0) := "01";

            -- Write data signals.
            WVALID : in std_logic;
            WREADY : out std_logic;
            WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
            WLAST  : in std_logic;

            -- Write response signals.
            BVALID : out std_logic;
            BREADY : in std_logic;
            BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
            BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

            -- Read request signals.
            ARVALID: in std_logic;
            ARREADY: out std_logic;
            ARID   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
            ARADDR : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
            ARLEN  : in std_logic_vector(7 downto 0) := (others => '0');
            ARBURST: in std_logic_vector(1 downto 0) := "01";

            -- Read response/data signals.
            RVALID : out std_logic;
            RREADY : in std_logic;
            RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
            RLAST  : out std_logic;
            RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
            RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

            -- Extra signals.
            CORRUPT_PACKET: out std_logic;

        -- Frontend injection Hamming detection flags
        OBS_FE_INJ_META_HDR_SINGLE_ERR_o: out std_logic;
        OBS_FE_INJ_META_HDR_DOUBLE_ERR_o: out std_logic;
        OBS_FE_INJ_ADDR_SINGLE_ERR_o    : out std_logic;
        OBS_FE_INJ_ADDR_DOUBLE_ERR_o    : out std_logic;
        OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o: out std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), DETECT_DOUBLE) - 1 downto 0);
        OBS_FE_INJ_HAM_ADDR_ENC_DATA_o    : out std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_FE_INJ_META_HDR_CORRECT_ERROR_i: in std_logic := '1';
        OBS_FE_INJ_ADDR_CORRECT_ERROR_i    : in std_logic := '1';

        -- XINA signals.
        l_in_data_i : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i  : out std_logic;
        l_in_ack_o  : in std_logic;
        l_out_data_o: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in std_logic;
        l_out_ack_i : out std_logic;

        -- Hamming/ECC ports (EXTERNAL, through backend_manager)
        -- Injection side
        OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic;
        OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic;

        -- Injection integrity checker (backend_manager_injection / integrity_control_send_hamming)
        OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in std_logic := '1';
        OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Injection flow control TMR (backend_manager_injection / send_control_tmr)
        OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o       : out std_logic;


        -- Injection packetizer control TMR detection (backend_manager_packetizer_control_tmr)
        OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o       : out std_logic;

        -- Reception side
        OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i  : in  std_logic;
        OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o     : out std_logic;
        OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o     : out std_logic;
        OBS_BE_RX_HAM_BUFFER_ENC_DATA_o       : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic;
        OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i : in std_logic := '1';
        OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);

        -- Reception integrity checker (backend_manager_reception / integrity_control_receive_hamming)
        OBS_BE_RX_INTEGRITY_CORRUPT_o       : out std_logic;
        OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in std_logic := '1';
        OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Reception flow control TMR (backend_manager_reception / receive_control_tmr)
        OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o       : out std_logic
    );
end ni_manager_top;

architecture rtl of ni_manager_top is
    -- Injection.
    signal START_SEND_PACKET_w: std_logic;
    signal VALID_SEND_DATA_w  : std_logic;
    signal LAST_SEND_DATA_w   : std_logic;

    signal READY_SEND_PACKET_w: std_logic;
    signal READY_SEND_DATA_w  : std_logic;

    signal ADDR_w     : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    signal BURST_w    : std_logic_vector(1 downto 0);
    signal LENGTH_w   : std_logic_vector(7 downto 0);
    signal DATA_SEND_w: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal OPC_SEND_w : std_logic;
    signal ID_w       : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);

    -- Reception.
    signal READY_RECEIVE_PACKET_w: std_logic;
    signal READY_RECEIVE_DATA_w  : std_logic;

    signal VALID_RECEIVE_DATA_w: std_logic;
    signal LAST_RECEIVE_DATA_w : std_logic;

    signal ID_RECEIVE_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    signal STATUS_RECEIVE_w: std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
    signal OPC_RECEIVE_w   : std_logic;
    signal DATA_RECEIVE_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    signal CORRUPT_RECEIVE_w: std_logic;

    signal OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_w : std_logic;
    signal OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_w : std_logic;
    signal OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_w : std_logic;
    signal OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_w  : std_logic;
    signal OBS_BE_RX_INTEGRITY_CORRUPT_w    : std_logic;
    signal OBS_BE_RX_TMR_FLOW_CTRL_ERROR_w  : std_logic;

begin
    u_frontend_manager: entity work.frontend_manager
        generic map(
            p_USE_HAMMING_META_HDR  => (p_USE_HAMMING and p_USE_FE_INJ_META_HDR_HAMMING),
            p_USE_HAMMING_ADDR      => (p_USE_HAMMING and p_USE_FE_INJ_ADDR_HAMMING),
            p_HAMMING_DETECT_DOUBLE => DETECT_DOUBLE
        )
        port map(
            -- AMBA AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,

                -- Write request signals.
                AWVALID => AWVALID,
                AWREADY => AWREADY,
                AWID    => AWID,
                AWADDR  => AWADDR,
                AWLEN   => AWLEN,
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

                -- Frontend injection Hamming detection flags
                OBS_FE_INJ_META_HDR_SINGLE_ERR_o => OBS_FE_INJ_META_HDR_SINGLE_ERR_o,
                OBS_FE_INJ_META_HDR_DOUBLE_ERR_o => OBS_FE_INJ_META_HDR_DOUBLE_ERR_o,
                OBS_FE_INJ_ADDR_SINGLE_ERR_o     => OBS_FE_INJ_ADDR_SINGLE_ERR_o,
                OBS_FE_INJ_ADDR_DOUBLE_ERR_o     => OBS_FE_INJ_ADDR_DOUBLE_ERR_o,
                OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o => OBS_FE_INJ_HAM_META_HDR_ENC_DATA_o,
                OBS_FE_INJ_HAM_ADDR_ENC_DATA_o     => OBS_FE_INJ_HAM_ADDR_ENC_DATA_o,
                OBS_FE_INJ_META_HDR_CORRECT_ERROR_i => OBS_FE_INJ_META_HDR_CORRECT_ERROR_i,
                OBS_FE_INJ_ADDR_CORRECT_ERROR_i     => OBS_FE_INJ_ADDR_CORRECT_ERROR_i,

            -- Backend signals (injection).
            READY_SEND_PACKET_i => READY_SEND_PACKET_w,
            READY_SEND_DATA_i   => READY_SEND_DATA_w,

            START_SEND_PACKET_o => START_SEND_PACKET_w,
            VALID_SEND_DATA_o   => VALID_SEND_DATA_w,
            LAST_SEND_DATA_o    => LAST_SEND_DATA_w,

            ADDR_o      => ADDR_w,
            BURST_o     => BURST_w,
            LENGTH_o    => LENGTH_w,
            DATA_SEND_o => DATA_SEND_w,
            OPC_SEND_o  => OPC_SEND_w,
            ID_o        => ID_w,

            -- Backend signals (reception).
            VALID_RECEIVE_DATA_i => VALID_RECEIVE_DATA_w,
            LAST_RECEIVE_DATA_i  => LAST_RECEIVE_DATA_w,

            ID_RECEIVE_i     => ID_RECEIVE_w,
            STATUS_RECEIVE_i => STATUS_RECEIVE_w,
            OPC_RECEIVE_i    => OPC_RECEIVE_w,
            DATA_RECEIVE_i   => DATA_RECEIVE_w,

            CORRUPT_RECEIVE_i => CORRUPT_RECEIVE_w,

            READY_RECEIVE_PACKET_o => READY_RECEIVE_PACKET_w,
            READY_RECEIVE_DATA_o   => READY_RECEIVE_DATA_w
        );

    u_backend_manager: entity work.backend_manager
        generic map(
            p_SRC_X => p_SRC_X,
            p_SRC_Y => p_SRC_Y,

            p_BUFFER_DEPTH            => p_BUFFER_DEPTH,
            p_USE_INJ_PKTZ_CTRL_TMR  => (p_USE_TMR_PACKETIZER and p_USE_BE_INJ_PKTZ_CTRL_TMR),
            p_USE_INJ_FLOW_CTRL_TMR  => (p_USE_TMR_FLOW and p_USE_BE_INJ_FLOW_CTRL_TMR),
            p_USE_INJ_INTEGRITY_CHECK=> (p_USE_INTEGRITY and p_USE_BE_INJ_INTEGRITY_CHECK),
            p_USE_INJ_BUFFER_HAMMING => (p_USE_HAMMING and p_USE_BE_INJ_BUFFER_HAMMING),
            p_USE_RX_DEPKTZ_CTRL_TMR => (p_USE_TMR_PACKETIZER and p_USE_BE_RX_DEPKTZ_CTRL_TMR),
            p_USE_RX_FLOW_CTRL_TMR   => (p_USE_TMR_FLOW and p_USE_BE_RX_FLOW_CTRL_TMR),
            p_USE_RX_INTEGRITY_CHECK => (p_USE_INTEGRITY and p_USE_BE_RX_INTEGRITY_CHECK),
            p_USE_RX_INTERFACE_HDR_HAMMING => (p_USE_HAMMING and p_USE_BE_RX_INTERFACE_HDR_HAMMING),
            p_USE_RX_BUFFER_HAMMING  => (p_USE_HAMMING and p_USE_BE_RX_BUFFER_HAMMING),

            DETECT_DOUBLE        => DETECT_DOUBLE
        )
        port map(
            -- AMBA AXI 5 signals.
            ACLK    => ACLK,
            ARESETn => ARESETn,

            -- Backend signals (injection).
            START_SEND_PACKET_i => START_SEND_PACKET_w,
            VALID_SEND_DATA_i   => VALID_SEND_DATA_w,
            LAST_SEND_DATA_i    => LAST_SEND_DATA_w,
            READY_SEND_DATA_o   => READY_SEND_DATA_w,
            READY_SEND_PACKET_o => READY_SEND_PACKET_w,

            ADDR_i      => ADDR_w,
            BURST_i     => BURST_w,
            LENGTH_i    => LENGTH_w,
            DATA_SEND_i => DATA_SEND_w,
            OPC_SEND_i  => OPC_SEND_w,
            ID_i        => ID_w,

            -- Backend signals (reception).
            READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_w,
            READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_w,

            VALID_RECEIVE_DATA_o => VALID_RECEIVE_DATA_w,
            LAST_RECEIVE_DATA_o  => LAST_RECEIVE_DATA_w,

            ID_RECEIVE_o     => ID_RECEIVE_w,
            STATUS_RECEIVE_o => STATUS_RECEIVE_w,
            OPC_RECEIVE_o    => OPC_RECEIVE_w,
            DATA_RECEIVE_o   => DATA_RECEIVE_w,

            CORRUPT_RECEIVE_o => CORRUPT_RECEIVE_w,

            -- XINA signals.
            l_in_data_i  => l_in_data_i,
            l_in_val_i   => l_in_val_i,
            l_in_ack_o   => l_in_ack_o,
            l_out_data_o => l_out_data_o,
            l_out_val_o  => l_out_val_o,
            l_out_ack_i  => l_out_ack_i,

            -- Hamming/ECC ports (EXTERNAL WIRES)
            OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o    => OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o,
            OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o    => OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o      => OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o,
            OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_w,

            OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o      => OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o,

            OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o         => OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_w,

            OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
            OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_w,

            OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i  => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o     => OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o,
            OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o     => OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_BE_RX_HAM_BUFFER_ENC_DATA_o       => OBS_BE_RX_HAM_BUFFER_ENC_DATA_o,
            OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_w,
            OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i,
            OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o,
            OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o,
            OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o      => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o,

            OBS_BE_RX_INTEGRITY_CORRUPT_o           => OBS_BE_RX_INTEGRITY_CORRUPT_w,
            OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o      => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o,

            OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o         => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_w
        );

    OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o <= OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_w;
    OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o <= OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_w;
    OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o <= OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_w;
    OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o  <= OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_w;
    OBS_BE_RX_INTEGRITY_CORRUPT_o    <= OBS_BE_RX_INTEGRITY_CORRUPT_w;
    OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o  <= OBS_BE_RX_TMR_FLOW_CTRL_ERROR_w;

end rtl;
