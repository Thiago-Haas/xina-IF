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
        i_START_SEND_PACKET: in std_logic;
        i_VALID_SEND_DATA  : in std_logic;
        i_LAST_SEND_DATA   : in std_logic;
        o_READY_SEND_PACKET: out std_logic;
        o_READY_SEND_DATA  : out std_logic;

        i_ADDR     : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
        i_ID       : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        i_LENGTH   : in std_logic_vector(7 downto 0);
        i_BURST    : in std_logic_vector(1 downto 0);
        i_OPC_SEND : in std_logic;
        i_DATA_SEND: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Signals (reception).
        i_READY_RECEIVE_PACKET: in std_logic;
        i_READY_RECEIVE_DATA  : in std_logic;

        o_VALID_RECEIVE_DATA: out std_logic;
        o_LAST_RECEIVE_DATA : out std_logic;

        o_ID_RECEIVE    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        o_STATUS_RECEIVE: out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        o_OPC_RECEIVE   : out std_logic;
        o_DATA_RECEIVE  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        o_CORRUPT_RECEIVE: out std_logic;

        -- XINA signals.
        l_in_data_i : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i  : out std_logic;
        l_in_ack_o  : in std_logic;
        l_out_data_o: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in std_logic;
        l_out_ack_i : out std_logic;

        -- Hamming/ECC ports (EXTERNAL)
        -- Injection side
        i_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR : in  std_logic;
        o_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR    : out std_logic;
        o_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR    : out std_logic;
        o_OBS_BE_INJ_HAM_BUFFER_ENC_DATA      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR         : out std_logic;

        -- Injection integrity checker (integrity_control_send_hamming)
        i_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR    : out std_logic;
        o_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR    : out std_logic;
        o_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Injection flow control TMR (send_control_tmr)
        i_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR : in  std_logic := '0';
        o_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR         : out std_logic;


        -- Injection packetizer control TMR (backend_manager_packetizer_control_tmr)
        i_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR : in  std_logic := '0';
        o_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR         : out std_logic;

        -- Reception side
        i_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR  : in  std_logic;
        o_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR     : out std_logic;
        o_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR     : out std_logic;
        o_OBS_BE_RX_HAM_BUFFER_ENC_DATA       : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        i_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR         : out std_logic;
        i_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR : in std_logic := '1';
        o_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR    : out std_logic;
        o_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR    : out std_logic;
        o_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);

        -- Reception integrity checker (integrity_control_receive_hamming)
        o_OBS_BE_RX_INTEGRITY_CORRUPT           : out std_logic;
        i_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR    : out std_logic;
        o_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR    : out std_logic;
        o_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Reception flow control TMR (receive_control_tmr)
        i_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR : in  std_logic := '0';
        o_OBS_BE_RX_TMR_FLOW_CTRL_ERROR         : out std_logic
    );
end backend_manager;

architecture rtl of backend_manager is
begin
    u_INJECTION: entity work.backend_manager_injection
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

            i_START_SEND_PACKET => i_START_SEND_PACKET,
            i_VALID_SEND_DATA   => i_VALID_SEND_DATA,
            i_LAST_SEND_DATA    => i_LAST_SEND_DATA,
            o_READY_SEND_PACKET => o_READY_SEND_PACKET,
            o_READY_SEND_DATA   => o_READY_SEND_DATA,

            i_ADDR      => i_ADDR,
            i_ID        => i_ID,
            i_LENGTH    => i_LENGTH,
            i_BURST     => i_BURST,
            i_OPC_SEND  => i_OPC_SEND,
            i_DATA_SEND => i_DATA_SEND,

            l_in_data_i => l_in_data_i,
            l_in_val_i  => l_in_val_i,
            l_in_ack_o  => l_in_ack_o,

            -- Hamming/ECC ports (EXTERNAL WIRES)
            i_OBS_INJ_HAM_BUFFER_CORRECT_ERROR => i_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR,
            o_OBS_INJ_HAM_BUFFER_SINGLE_ERR    => o_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR,
            o_OBS_INJ_HAM_BUFFER_DOUBLE_ERR    => o_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR,
            o_OBS_INJ_HAM_BUFFER_ENC_DATA      => o_OBS_BE_INJ_HAM_BUFFER_ENC_DATA,
            i_OBS_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
            o_OBS_INJ_TMR_HAM_BUFFER_CTRL_ERROR         => o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR,

            i_OBS_INJ_HAM_INTEGRITY_CORRECT_ERROR => i_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR,
            o_OBS_INJ_HAM_INTEGRITY_SINGLE_ERR    => o_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR,
            o_OBS_INJ_HAM_INTEGRITY_DOUBLE_ERR    => o_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR,
            o_OBS_INJ_HAM_INTEGRITY_ENC_DATA      => o_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA,

            i_OBS_INJ_TMR_FLOW_CTRL_CORRECT_ERROR => i_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR,
            o_OBS_INJ_TMR_FLOW_CTRL_ERROR         => o_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR,

            i_OBS_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR => i_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR,
            o_OBS_INJ_TMR_PKTZ_CTRL_ERROR         => o_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR
        );

    u_RECEPTION: entity work.backend_manager_reception
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

            i_READY_RECEIVE_PACKET => i_READY_RECEIVE_PACKET,
            i_READY_RECEIVE_DATA   => i_READY_RECEIVE_DATA,

            o_VALID_RECEIVE_DATA => o_VALID_RECEIVE_DATA,
            o_LAST_RECEIVE_DATA  => o_LAST_RECEIVE_DATA,

            o_ID_RECEIVE     => o_ID_RECEIVE,
            o_STATUS_RECEIVE => o_STATUS_RECEIVE,
            o_OPC_RECEIVE    => o_OPC_RECEIVE,
            o_DATA_RECEIVE   => o_DATA_RECEIVE,

            o_CORRUPT_RECEIVE => o_CORRUPT_RECEIVE,

            l_out_data_o => l_out_data_o,
            l_out_val_o  => l_out_val_o,
            l_out_ack_i  => l_out_ack_i,

            -- Hamming/ECC ports (EXTERNAL WIRES)
            i_OBS_RX_HAM_BUFFER_CORRECT_ERROR => i_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR,
            o_OBS_RX_HAM_BUFFER_SINGLE_ERR    => o_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR,
            o_OBS_RX_HAM_BUFFER_DOUBLE_ERR    => o_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR,
            o_OBS_RX_HAM_BUFFER_ENC_DATA      => o_OBS_BE_RX_HAM_BUFFER_ENC_DATA,
            i_OBS_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR => i_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR,
            o_OBS_RX_TMR_HAM_BUFFER_CTRL_ERROR         => o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR,
            i_OBS_RX_HAM_INTERFACE_HDR_CORRECT_ERROR => i_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR,
            o_OBS_RX_HAM_INTERFACE_HDR_SINGLE_ERR    => o_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR,
            o_OBS_RX_HAM_INTERFACE_HDR_DOUBLE_ERR    => o_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR,
            o_OBS_RX_HAM_INTERFACE_HDR_ENC_DATA      => o_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA,

            o_OBS_RX_INTEGRITY_CORRUPT            => o_OBS_BE_RX_INTEGRITY_CORRUPT,
            i_OBS_RX_HAM_INTEGRITY_CORRECT_ERROR  => i_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR,
            o_OBS_RX_HAM_INTEGRITY_SINGLE_ERR     => o_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR,
            o_OBS_RX_HAM_INTEGRITY_DOUBLE_ERR     => o_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR,
            o_OBS_RX_HAM_INTEGRITY_ENC_DATA       => o_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA,

            i_OBS_RX_TMR_FLOW_CTRL_CORRECT_ERROR => i_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR,
            o_OBS_RX_TMR_FLOW_CTRL_ERROR         => o_OBS_BE_RX_TMR_FLOW_CTRL_ERROR
        );

end rtl;
