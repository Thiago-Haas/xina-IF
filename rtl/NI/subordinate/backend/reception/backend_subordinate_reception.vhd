library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity backend_subordinate_reception is
    generic(
        p_BUFFER_DEPTH      : positive;
        p_USE_TMR_PACKETIZER: boolean;
        p_USE_TMR_FLOW      : boolean;
        p_USE_TMR_INTEGRITY : boolean;
        p_USE_HAMMING       : boolean;
        p_USE_HAM_H_SRC     : boolean := c_ENABLE_SUB_BE_RX_SRC_HDR_HAMMING;
        p_USE_HAM_H_INTERFACE: boolean := c_ENABLE_SUB_BE_RX_INTERFACE_HDR_HAMMING;
        p_USE_HAM_H_ADDRESS : boolean := c_ENABLE_SUB_BE_RX_ADDRESS_HDR_HAMMING;
        p_USE_INTEGRITY     : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;

        VALID_RECEIVE_PACKET_o: out std_logic;
        VALID_RECEIVE_DATA_o  : out std_logic;
        LAST_RECEIVE_DATA_o   : out std_logic;

        DATA_RECEIVE_o       : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        H_SRC_RECEIVE_o      : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        H_INTERFACE_RECEIVE_o: out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        ADDRESS_RECEIVE_o    : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        CORRUPT_RECEIVE_o: out std_logic := '0';

        -- Signals from injection.
        HAS_FINISHED_RESPONSE_i: in std_logic;
        HAS_REQUEST_PACKET_o   : out std_logic;

        -- XINA signals.
        l_out_data_o: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in std_logic;
        l_out_ack_i : out std_logic;

        -- Reception FIFO Hamming.
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

        -- Reception integrity checksum Hamming.
        OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');

        -- Reception flow and depacketizer TMR.
        OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o         : out std_logic := '0'
    );
end backend_subordinate_reception;

architecture rtl of backend_subordinate_reception is
    signal ARESET_w: std_logic;

    -- Depacketizer.
    signal FLIT_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- Registers.
    signal WRITE_H_SRC_REG_w: std_logic;
    signal WRITE_H_INTERFACE_REG_w: std_logic;
    signal WRITE_H_ADDRESS_REG_w  : std_logic;

    signal H_SRC_r_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal H_INTERFACE_r_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal H_ADDRESS_r_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- Checksum.
    signal ADD_w: std_logic;
    signal COMPARE_w: std_logic;
    signal INTEGRITY_RESETn_w: std_logic;

    -- FIFO.
    signal WRITE_BUFFER_w   : std_logic;
    signal WRITE_OK_BUFFER_w: std_logic;
    signal READ_BUFFER_w    : std_logic;
    signal READ_OK_BUFFER_w : std_logic;

    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

begin
    u_h_src_hamming_register: entity work.hamming_register
        generic map(
            DATA_WIDTH     => c_FLIT_WIDTH,
            HAMMING_ENABLE => p_USE_HAM_H_SRC,
            DETECT_DOUBLE  => c_ENABLE_HAMMING_DOUBLE_DETECT,
            RESET_VALUE    => (c_FLIT_WIDTH - 1 downto 0 => '0'),
            INJECT_ERROR   => false
        )
        port map(
            correct_en_i => OBS_SUB_RX_HAM_H_SRC_CORRECT_ERROR_i,
            write_en_i   => WRITE_H_SRC_REG_w,
            data_i       => FLIT_w,
            rstn_i       => ARESETn,
            clk_i        => ACLK,
            single_err_o => OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o,
            double_err_o => OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o,
            enc_data_o   => OBS_SUB_RX_HAM_H_SRC_ENC_DATA_o,
            data_o       => H_SRC_r_w
        );

    u_h_interface_hamming_register: entity work.hamming_register
        generic map(
            DATA_WIDTH     => c_FLIT_WIDTH,
            HAMMING_ENABLE => p_USE_HAM_H_INTERFACE,
            DETECT_DOUBLE  => c_ENABLE_HAMMING_DOUBLE_DETECT,
            RESET_VALUE    => (c_FLIT_WIDTH - 1 downto 0 => '0'),
            INJECT_ERROR   => false
        )
        port map(
            correct_en_i => OBS_SUB_RX_HAM_H_INTERFACE_CORRECT_ERROR_i,
            write_en_i   => WRITE_H_INTERFACE_REG_w,
            data_i       => FLIT_w,
            rstn_i       => ARESETn,
            clk_i        => ACLK,
            single_err_o => OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o,
            double_err_o => OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o,
            enc_data_o   => OBS_SUB_RX_HAM_H_INTERFACE_ENC_DATA_o,
            data_o       => H_INTERFACE_r_w
        );

    u_h_address_hamming_register: entity work.hamming_register
        generic map(
            DATA_WIDTH     => c_FLIT_WIDTH,
            HAMMING_ENABLE => p_USE_HAM_H_ADDRESS,
            DETECT_DOUBLE  => c_ENABLE_HAMMING_DOUBLE_DETECT,
            RESET_VALUE    => (c_FLIT_WIDTH - 1 downto 0 => '0'),
            INJECT_ERROR   => false
        )
        port map(
            correct_en_i => OBS_SUB_RX_HAM_H_ADDRESS_CORRECT_ERROR_i,
            write_en_i   => WRITE_H_ADDRESS_REG_w,
            data_i       => FLIT_w,
            rstn_i       => ARESETn,
            clk_i        => ACLK,
            single_err_o => OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o,
            double_err_o => OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o,
            enc_data_o   => OBS_SUB_RX_HAM_H_ADDRESS_ENC_DATA_o,
            data_o       => H_ADDRESS_r_w
        );

    H_SRC_RECEIVE_o       <= H_SRC_r_w;
    H_INTERFACE_RECEIVE_o <= H_INTERFACE_r_w;
    ADDRESS_RECEIVE_o     <= H_ADDRESS_r_w(c_FLIT_WIDTH - 2 downto 0);
    DATA_RECEIVE_o        <= FLIT_w(31 downto 0);

    u_DEPACKETIZER_CONTROL:
    if (p_USE_TMR_PACKETIZER) generate
        u_backend_subordinate_depacketizer_control_tmr: entity work.backend_subordinate_depacketizer_control_tmr
            port map(
                ACLK => ACLK,
                ARESETn => ARESETn,

                READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
                READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,
                VALID_RECEIVE_PACKET_o => VALID_RECEIVE_PACKET_o,
                VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_o,
                LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_o,

                HAS_FINISHED_RESPONSE_i => HAS_FINISHED_RESPONSE_i,
                HAS_REQUEST_PACKET_o    => HAS_REQUEST_PACKET_o,

                FLIT_i => FLIT_w,
                READ_BUFFER_o => READ_BUFFER_w,
                READ_OK_BUFFER_i => READ_OK_BUFFER_w,

                H_INTERFACE_i => H_INTERFACE_r_w,

                WRITE_H_SRC_REG_o       => WRITE_H_SRC_REG_w,
                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w,
                WRITE_H_ADDRESS_REG_o   => WRITE_H_ADDRESS_REG_w,

                ADD_o     => ADD_w,
                COMPARE_o => COMPARE_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w,

                correct_error_i => OBS_SUB_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o
            );
    else generate
        attribute DONT_TOUCH of u_backend_subordinate_depacketizer_control : label is "TRUE";
        attribute syn_preserve of u_backend_subordinate_depacketizer_control : label is true;
        attribute KEEP_HIERARCHY of u_backend_subordinate_depacketizer_control : label is "TRUE";
    begin
        u_backend_subordinate_depacketizer_control: entity work.backend_subordinate_depacketizer_control
            port map(
                ACLK => ACLK,
                ARESETn => ARESETn,

                READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
                READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,
                VALID_RECEIVE_PACKET_o => VALID_RECEIVE_PACKET_o,
                VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_o,
                LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_o,

                HAS_FINISHED_RESPONSE_i => HAS_FINISHED_RESPONSE_i,
                HAS_REQUEST_PACKET_o    => HAS_REQUEST_PACKET_o,

                FLIT_i => FLIT_w,
                READ_BUFFER_o => READ_BUFFER_w,
                READ_OK_BUFFER_i => READ_OK_BUFFER_w,

                H_INTERFACE_i => H_INTERFACE_r_w,

                WRITE_H_SRC_REG_o => WRITE_H_SRC_REG_w,
                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w,
                WRITE_H_ADDRESS_REG_o   => WRITE_H_ADDRESS_REG_w,

                ADD_o     => ADD_w,
                COMPARE_o => COMPARE_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w
            );

        OBS_SUB_RX_TMR_DEPKTZ_CTRL_ERROR_o <= '0';
    end generate;

    u_INTEGRITY_CONTROL_RECEIVE:
    if (p_USE_INTEGRITY and p_USE_TMR_INTEGRITY) generate
        u_integrity_control_receive_hamming: entity work.integrity_control_receive_hamming
            port map(
                ACLK    => ACLK,
                ARESETn => INTEGRITY_RESETn_w,

                ADD_i           => ADD_w,
                VALUE_ADD_i     => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),
                COMPARE_i       => COMPARE_w,
                VALUE_COMPARE_i => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                CORRUPT_o  => CORRUPT_RECEIVE_o,
                correct_error_i => OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
                error_o         => open,
                OBS_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
                OBS_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o,
                OBS_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
                OBS_HAM_INTEGRITY_ENC_DATA_o      => OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o
            );
    elsif (p_USE_INTEGRITY) generate
        u_integrity_control_receive: entity work.integrity_control_receive
            port map(
                ACLK    => ACLK,
                ARESETn => INTEGRITY_RESETn_w,

                ADD_i           => ADD_w,
                VALUE_ADD_i     => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),
                COMPARE_i       => COMPARE_w,
                VALUE_COMPARE_i => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                CORRUPT_o  => CORRUPT_RECEIVE_o
            );

        OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o <= '0';
        OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o <= '0';
        OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o   <= (others => '0');
    else generate
        CORRUPT_RECEIVE_o <= '0';
        OBS_SUB_RX_HAM_INTEGRITY_SINGLE_ERR_o <= '0';
        OBS_SUB_RX_HAM_INTEGRITY_DOUBLE_ERR_o <= '0';
        OBS_SUB_RX_HAM_INTEGRITY_ENC_DATA_o   <= (others => '0');
    end generate;

    u_BUFFER_FIFO:
    if (p_USE_HAMMING) generate
        u_buffer_fifo_ham: entity work.buffer_fifo_ham
            generic map(
                p_DATA_WIDTH   => c_FLIT_WIDTH,
                p_BUFFER_DEPTH => p_BUFFER_DEPTH
            )
            port map(
                ACLK   => ACLK,
                ARESET => ARESET_w,

                READ_OK_o  => READ_OK_BUFFER_w,
                READ_i     => READ_BUFFER_w,
                DATA_o     => FLIT_w,

                WRITE_OK_o => WRITE_OK_BUFFER_w,
                WRITE_i    => WRITE_BUFFER_w,
                DATA_i     => l_out_data_o,
                correct_error_i => OBS_SUB_RX_HAM_BUFFER_CORRECT_ERROR_i,
                single_err_o    => OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o,
                double_err_o    => OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o,
                enc_stage_data_o => OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o,
                OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
                OBS_HAM_FIFO_CTRL_TMR_ERROR_o         => OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o
            );
    else generate
        attribute DONT_TOUCH of u_buffer_fifo : label is "TRUE";
        attribute syn_preserve of u_buffer_fifo : label is true;
        attribute KEEP_HIERARCHY of u_buffer_fifo : label is "TRUE";
    begin
        u_buffer_fifo: entity work.buffer_fifo
            generic map(
                p_DATA_WIDTH   => c_FLIT_WIDTH,
                p_BUFFER_DEPTH => p_BUFFER_DEPTH
            )
            port map(
                ACLK   => ACLK,
                ARESET => ARESET_w,

                READ_OK_o  => READ_OK_BUFFER_w,
                READ_i     => READ_BUFFER_w,
                DATA_o     => FLIT_w,

                WRITE_OK_o => WRITE_OK_BUFFER_w,
                WRITE_i    => WRITE_BUFFER_w,
                DATA_i     => l_out_data_o
            );

        OBS_SUB_RX_HAM_BUFFER_SINGLE_ERR_o <= '0';
        OBS_SUB_RX_HAM_BUFFER_DOUBLE_ERR_o <= '0';
        OBS_SUB_RX_HAM_BUFFER_ENC_DATA_o   <= (others => '0');
        OBS_SUB_RX_TMR_HAM_BUFFER_CTRL_ERROR_o <= '0';
    end generate;

    u_RECEIVE_CONTROL:
    if (p_USE_TMR_FLOW) generate
        u_receive_control_tmr: entity work.receive_control_TMR
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i,

                correct_error_i => OBS_SUB_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o
            );
    else generate
        attribute DONT_TOUCH of u_receive_control : label is "TRUE";
        attribute syn_preserve of u_receive_control : label is true;
        attribute KEEP_HIERARCHY of u_receive_control : label is "TRUE";
    begin
        u_receive_control: entity work.receive_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i
            );

        OBS_SUB_RX_TMR_FLOW_CTRL_ERROR_o <= '0';
    end generate;

    ARESET_w <= not ARESETn;
end rtl;
