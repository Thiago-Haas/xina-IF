library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity backend_subordinate is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);

        p_BUFFER_DEPTH      : positive;
        p_USE_TMR_PACKETIZER: boolean;
        p_USE_TMR_FLOW      : boolean;
        p_USE_TMR_INTEGRITY : boolean;
        p_USE_HAMMING       : boolean;
        p_USE_RX_HAM_H_SRC      : boolean := c_ENABLE_SUB_BE_RX_SRC_HDR_HAMMING;
        p_USE_RX_HAM_H_INTERFACE: boolean := c_ENABLE_SUB_BE_RX_INTERFACE_HDR_HAMMING;
        p_USE_RX_HAM_H_ADDRESS  : boolean := c_ENABLE_SUB_BE_RX_ADDRESS_HDR_HAMMING;
        p_USE_INTEGRITY     : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Signals (injection).
        VALID_SEND_DATA_i: in std_logic;
        LAST_SEND_DATA_i : in std_logic;
        READY_SEND_DATA_o: out std_logic;

        DATA_SEND_i  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        STATUS_SEND_i: in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

        -- Signals (reception).
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;

        VALID_RECEIVE_PACKET_o: out std_logic;
        VALID_RECEIVE_DATA_o  : out std_logic;
        LAST_RECEIVE_DATA_o   : out std_logic;

        ID_RECEIVE_o     : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        LEN_RECEIVE_o    : out std_logic_vector(7 downto 0);
        BURST_RECEIVE_o  : out std_logic_vector(1 downto 0);
        OPC_RECEIVE_o    : out std_logic;
        ADDRESS_RECEIVE_o: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        DATA_RECEIVE_o   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        CORRUPT_RECEIVE_o: out std_logic;

        -- XINA signals.
        l_in_data_i : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i  : out std_logic;
        l_in_ack_o  : in std_logic;
        l_out_data_o: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in std_logic;
        l_out_ack_i : out std_logic;

        -- Injection-side FT observability/correction.
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

        -- Reception-side FT observability/correction.
        OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         : out std_logic := '0'
    );
end backend_subordinate;

architecture rtl of backend_subordinate is
    signal H_SRC_RECEIVE_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal H_INTERFACE_RECEIVE_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    signal HAS_REQUEST_PACKET_w: std_logic;
    signal HAS_FINISHED_RESPONSE_w: std_logic;

begin
    u_backend_subordinate_injection: entity work.backend_subordinate_injection
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
            ACLK    => ACLK,
            ARESETn => ARESETn,

            VALID_SEND_DATA_i => VALID_SEND_DATA_i,
            LAST_SEND_DATA_i  => LAST_SEND_DATA_i,
            READY_SEND_DATA_o => READY_SEND_DATA_o,

            DATA_SEND_i   => DATA_SEND_i,
            STATUS_SEND_i => STATUS_SEND_i,

            H_SRC_RECEIVE_i         => H_SRC_RECEIVE_w,
            H_INTERFACE_RECEIVE_i   => H_INTERFACE_RECEIVE_w,
            HAS_REQUEST_PACKET_i    => HAS_REQUEST_PACKET_w,
            HAS_FINISHED_RESPONSE_o => HAS_FINISHED_RESPONSE_w,

            l_in_data_i => l_in_data_i,
            l_in_val_i  => l_in_val_i,
            l_in_ack_o  => l_in_ack_o,

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
            OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o         => OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o
        );

    u_backend_subordinate_reception: entity work.backend_subordinate_reception
        generic map(
            p_BUFFER_DEPTH       => p_BUFFER_DEPTH,
            p_USE_TMR_PACKETIZER => p_USE_TMR_PACKETIZER,
            p_USE_TMR_FLOW       => p_USE_TMR_FLOW,
            p_USE_TMR_INTEGRITY  => p_USE_TMR_INTEGRITY,
            p_USE_HAMMING        => p_USE_HAMMING,
            p_USE_HAM_H_SRC      => p_USE_RX_HAM_H_SRC,
            p_USE_HAM_H_INTERFACE => p_USE_RX_HAM_H_INTERFACE,
            p_USE_HAM_H_ADDRESS  => p_USE_RX_HAM_H_ADDRESS,
            p_USE_INTEGRITY      => p_USE_INTEGRITY
        )

        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
            READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,

            VALID_RECEIVE_PACKET_o => VALID_RECEIVE_PACKET_o,
            VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_o,
            LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_o,
            DATA_RECEIVE_o         => DATA_RECEIVE_o,
            H_SRC_RECEIVE_o        => H_SRC_RECEIVE_w,
            H_INTERFACE_RECEIVE_o  => H_INTERFACE_RECEIVE_w,
            ADDRESS_RECEIVE_o      => ADDRESS_RECEIVE_o,

            CORRUPT_RECEIVE_o      => CORRUPT_RECEIVE_o,

            HAS_FINISHED_RESPONSE_i => HAS_FINISHED_RESPONSE_w,
            HAS_REQUEST_PACKET_o    => HAS_REQUEST_PACKET_w,

            l_out_data_o => l_out_data_o,
            l_out_val_o  => l_out_val_o,
            l_out_ack_i  => l_out_ack_i,

            OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i => OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o    => OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o      => OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o,
            OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
            OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o,
            OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i => OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o    => OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o      => OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o,
            OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i => OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o    => OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o      => OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o,
            OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i => OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o    => OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o      => OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o,
            OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
            OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o,
            OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
            OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o      => OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o,
            OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
            OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         => OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o,
            OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i => OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
            OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         => OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o
        );

    ID_RECEIVE_o    <= H_INTERFACE_RECEIVE_w(19 downto 15);
    LEN_RECEIVE_o   <= H_INTERFACE_RECEIVE_w(14 downto 7);
    BURST_RECEIVE_o <= H_INTERFACE_RECEIVE_w(6 downto 5);
    OPC_RECEIVE_o   <= H_INTERFACE_RECEIVE_w(1);
end rtl;
