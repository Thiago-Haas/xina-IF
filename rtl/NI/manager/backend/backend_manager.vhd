library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);

        p_BUFFER_DEPTH            : positive;
        p_USE_INJ_PKTZ_CTRL_TMR  : boolean;
        p_USE_INJ_FLOW_CTRL_TMR  : boolean;
        p_USE_INJ_INTEGRITY_CHECK: boolean;
        p_USE_INJ_BUFFER_HAMMING : boolean;
        p_USE_RX_DEPKTZ_CTRL_TMR : boolean;
        p_USE_RX_FLOW_CTRL_TMR   : boolean;
        p_USE_RX_INTEGRITY_CHECK : boolean;
        p_USE_RX_INTERFACE_HDR_HAMMING : boolean;
        p_USE_RX_BUFFER_HAMMING  : boolean;

        DETECT_DOUBLE       : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Signals (injection).
        START_SEND_PACKET_i: in std_logic;
        VALID_SEND_DATA_i  : in std_logic;
        LAST_SEND_DATA_i   : in std_logic;
        READY_SEND_PACKET_o: out std_logic;
        READY_SEND_DATA_o  : out std_logic;

        ADDR_i     : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        ID_i       : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        LENGTH_i   : in std_logic_vector(7 downto 0);
        BURST_i    : in std_logic_vector(1 downto 0);
        OPC_SEND_i : in std_logic;
        DATA_SEND_i: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Signals (reception).
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;

        VALID_RECEIVE_DATA_o: out std_logic;
        LAST_RECEIVE_DATA_o : out std_logic;

        ID_RECEIVE_o    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        STATUS_RECEIVE_o: out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        OPC_RECEIVE_o   : out std_logic;
        DATA_RECEIVE_o  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        CORRUPT_RECEIVE_o: out std_logic;

        -- XINA signals.
        l_in_data_i : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i  : out std_logic;
        l_in_ack_o  : in std_logic;
        l_out_data_o: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in std_logic;
        l_out_ack_i : out std_logic;

        -- Hamming/ECC ports (EXTERNAL)
        -- Injection side
        OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic;
        OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic;

        -- Injection integrity checker (integrity_control_send_hamming)
        OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Injection flow control TMR (send_control_tmr)
        OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o         : out std_logic;


        -- Injection packetizer control TMR (backend_manager_packetizer_control_tmr)
        OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o         : out std_logic;

        -- Reception side
        OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i  : in  std_logic;
        OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o     : out std_logic;
        OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o     : out std_logic;
        OBS_BE_RX_HAM_BUFFER_ENC_DATA_o       : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i     : in  std_logic := '1';
        OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_o             : out std_logic;
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic;
        OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i : in std_logic := '1';
        OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);

        -- Reception integrity checker (integrity_control_receive_hamming)
        OBS_BE_RX_INTEGRITY_CORRUPT_o           : out std_logic;
        OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic;
        OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Reception flow control TMR (receive_control_tmr)
        OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o         : out std_logic
    );
end backend_manager;

architecture rtl of backend_manager is
begin
    u_backend_manager_injection: entity work.backend_manager_injection
        generic map(
            p_SRC_X => p_SRC_X,
            p_SRC_Y => p_SRC_Y,

            p_BUFFER_DEPTH            => p_BUFFER_DEPTH,
            p_USE_INJ_PKTZ_CTRL_TMR  => p_USE_INJ_PKTZ_CTRL_TMR,
            p_USE_INJ_FLOW_CTRL_TMR  => p_USE_INJ_FLOW_CTRL_TMR,
            p_USE_INJ_INTEGRITY_CHECK=> p_USE_INJ_INTEGRITY_CHECK,
            p_USE_INJ_BUFFER_HAMMING => p_USE_INJ_BUFFER_HAMMING,

            DETECT_DOUBLE        => DETECT_DOUBLE
        )
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            START_SEND_PACKET_i => START_SEND_PACKET_i,
            VALID_SEND_DATA_i   => VALID_SEND_DATA_i,
            LAST_SEND_DATA_i    => LAST_SEND_DATA_i,
            READY_SEND_PACKET_o => READY_SEND_PACKET_o,
            READY_SEND_DATA_o   => READY_SEND_DATA_o,

            ADDR_i      => ADDR_i,
            ID_i        => ID_i,
            LENGTH_i    => LENGTH_i,
            BURST_i     => BURST_i,
            OPC_SEND_i  => OPC_SEND_i,
            DATA_SEND_i => DATA_SEND_i,

            l_in_data_i => l_in_data_i,
            l_in_val_i  => l_in_val_i,
            l_in_ack_o  => l_in_ack_o,

            -- Hamming/ECC ports (EXTERNAL WIRES)
            OBS_INJ_HAM_BUFFER_CORRECT_ERROR_i => OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_INJ_HAM_BUFFER_SINGLE_ERR_o    => OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR_o,
            OBS_INJ_HAM_BUFFER_DOUBLE_ERR_o    => OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_INJ_HAM_BUFFER_ENC_DATA_o      => OBS_BE_INJ_HAM_BUFFER_ENC_DATA_o,
            OBS_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o,

            OBS_INJ_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_INJ_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_INJ_HAM_INTEGRITY_ENC_DATA_o      => OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA_o,

            OBS_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_INJ_TMR_FLOW_CTRL_ERROR_o         => OBS_BE_INJ_TMR_FLOW_CTRL_ERROR_o,

            OBS_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i => OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
            OBS_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR_o
        );

    u_backend_manager_reception: entity work.backend_manager_reception
        generic map(
            p_BUFFER_DEPTH           => p_BUFFER_DEPTH,
            p_USE_RX_DEPKTZ_CTRL_TMR=> p_USE_RX_DEPKTZ_CTRL_TMR,
            p_USE_RX_FLOW_CTRL_TMR  => p_USE_RX_FLOW_CTRL_TMR,
            p_USE_RX_INTEGRITY_CHECK=> p_USE_RX_INTEGRITY_CHECK,
            p_USE_RX_INTERFACE_HDR_HAMMING => p_USE_RX_INTERFACE_HDR_HAMMING,
            p_USE_RX_BUFFER_HAMMING => p_USE_RX_BUFFER_HAMMING,

            DETECT_DOUBLE        => DETECT_DOUBLE
        )
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
            READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,

            VALID_RECEIVE_DATA_o => VALID_RECEIVE_DATA_o,
            LAST_RECEIVE_DATA_o  => LAST_RECEIVE_DATA_o,

            ID_RECEIVE_o     => ID_RECEIVE_o,
            STATUS_RECEIVE_o => STATUS_RECEIVE_o,
            OPC_RECEIVE_o    => OPC_RECEIVE_o,
            DATA_RECEIVE_o   => DATA_RECEIVE_o,

            CORRUPT_RECEIVE_o => CORRUPT_RECEIVE_o,

            l_out_data_o => l_out_data_o,
            l_out_val_o  => l_out_val_o,
            l_out_ack_i  => l_out_ack_i,

            -- Hamming/ECC ports (EXTERNAL WIRES)
            OBS_RX_HAM_BUFFER_CORRECT_ERROR_i => OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_RX_HAM_BUFFER_SINGLE_ERR_o    => OBS_BE_RX_HAM_BUFFER_SINGLE_ERR_o,
            OBS_RX_HAM_BUFFER_DOUBLE_ERR_o    => OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_RX_HAM_BUFFER_ENC_DATA_o      => OBS_BE_RX_HAM_BUFFER_ENC_DATA_o,
            OBS_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
            OBS_RX_TMR_DEPKTZ_CTRL_ERROR_o         => OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR_o,
            OBS_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR_o,
            OBS_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i => OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i,
            OBS_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o,
            OBS_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    => OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o,
            OBS_RX_HAM_INTERFACE_HDR_ENC_DATA_o      => OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA_o,

            OBS_RX_INTEGRITY_CORRUPT_o            => OBS_BE_RX_INTEGRITY_CORRUPT_o,
            OBS_RX_HAM_INTEGRITY_CORRECT_ERROR_i  => OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_RX_HAM_INTEGRITY_SINGLE_ERR_o     => OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_RX_HAM_INTEGRITY_DOUBLE_ERR_o     => OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_RX_HAM_INTEGRITY_ENC_DATA_o       => OBS_BE_RX_HAM_INTEGRITY_ENC_DATA_o,

            OBS_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_RX_TMR_FLOW_CTRL_ERROR_o         => OBS_BE_RX_TMR_FLOW_CTRL_ERROR_o
        );

end rtl;
