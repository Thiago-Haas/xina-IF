library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_reception is
    generic(
        p_BUFFER_DEPTH           : positive;
        p_USE_RX_DEPKTZ_CTRL_TMR: boolean;
        p_USE_RX_FLOW_CTRL_TMR  : boolean;
        p_USE_RX_INTEGRITY_CHECK: boolean;
        p_USE_RX_INTERFACE_HDR_HAMMING: boolean;
        p_USE_RX_BUFFER_HAMMING : boolean;

        DETECT_DOUBLE : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;

        VALID_RECEIVE_DATA_o: out std_logic;
        LAST_RECEIVE_DATA_o : out std_logic;

        ID_RECEIVE_o    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        STATUS_RECEIVE_o: out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        OPC_RECEIVE_o   : out std_logic;
        DATA_RECEIVE_o  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        CORRUPT_RECEIVE_o: out std_logic := '0';

        -- XINA signals.
        l_out_data_o: in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in  std_logic;
        l_out_ack_i : out std_logic;

        -- Hamming (buffer) - EXTERNAL
        OBS_RX_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic;
        OBS_RX_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
        OBS_RX_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
        OBS_RX_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i     : in  std_logic := '1';
        OBS_RX_TMR_DEPKTZ_CTRL_ERROR_o             : out std_logic := '0';
        OBS_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_RX_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';
        -- Hamming (interface header register) - EXTERNAL
        OBS_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o    : out std_logic := '0';
        OBS_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_RX_HAM_INTERFACE_HDR_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);

        -- Integrity receive checker (integrity_control_receive_hamming) - EXTERNAL
        -- Meaningful when p_USE_RX_INTEGRITY_CHECK = TRUE.
        OBS_RX_INTEGRITY_CORRUPT_o        : out std_logic := '0';
        -- Meaningful when p_USE_RX_INTEGRITY_CHECK = TRUE.
        OBS_RX_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_RX_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_RX_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_RX_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Receive flow control TMR (receive_control_tmr) - EXTERNAL
        -- Meaningful when p_USE_RX_FLOW_CTRL_TMR = TRUE.
        OBS_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_RX_TMR_FLOW_CTRL_ERROR_o       : out std_logic := '0'
    );
end backend_manager_reception;

architecture rtl of backend_manager_reception is
    signal ARESET_w: std_logic;

    -- Depacketizer.
    signal FLIT_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- Registers.
    signal WRITE_H_INTERFACE_REG_w: std_logic;
    signal H_INTERFACE_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- Integrity (receive) outputs.
    signal OBS_RX_INTEGRITY_CORRUPT_w : std_logic;

    -- Checksum.
    signal ADD_w: std_logic;
    signal COMPARE_w: std_logic;
    signal INTEGRITY_RESETn_w: std_logic;

    -- FIFO.
    signal WRITE_BUFFER_w   : std_logic;
    signal WRITE_OK_BUFFER_w: std_logic;
    signal READ_BUFFER_w    : std_logic;
    signal READ_OK_BUFFER_w : std_logic;

begin
    u_backend_manager_reception_h_interface_reg: entity work.backend_manager_reception_h_interface_reg
        generic map(
            p_USE_HAMMING           => p_USE_RX_INTERFACE_HDR_HAMMING,
            p_HAMMING_DETECT_DOUBLE => DETECT_DOUBLE
        )
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            WRITE_EN_i => WRITE_H_INTERFACE_REG_w,
            DATA_i     => FLIT_w,
            DATA_o     => H_INTERFACE_w,

            OBS_HAM_CORRECT_ERROR_i => OBS_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i,
            OBS_HAM_SINGLE_ERR_o    => OBS_RX_HAM_INTERFACE_HDR_SINGLE_ERR_o,
            OBS_HAM_DOUBLE_ERR_o    => OBS_RX_HAM_INTERFACE_HDR_DOUBLE_ERR_o,
            OBS_HAM_ENC_DATA_o      => OBS_RX_HAM_INTERFACE_HDR_ENC_DATA_o
        );

    ID_RECEIVE_o     <= H_INTERFACE_w(19 downto 15);
    STATUS_RECEIVE_o <= H_INTERFACE_w(4 downto 2);
    OPC_RECEIVE_o    <= H_INTERFACE_w(1);
    DATA_RECEIVE_o   <= FLIT_w(31 downto 0);

    u_DEPACKETIZER_CONTROL:
    if (p_USE_RX_DEPKTZ_CTRL_TMR) generate
        u_backend_manager_depacketizer_control_tmr: entity work.backend_manager_depacketizer_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
                READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,
                VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_o,
                LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_o,

                FLIT_i           => FLIT_w,
                READ_OK_BUFFER_i => READ_OK_BUFFER_w,
                READ_BUFFER_o    => READ_BUFFER_w,

                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w,

                ADD_o              => ADD_w,
                COMPARE_o          => COMPARE_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w,
                correct_error_i    => OBS_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i,
                error_o            => OBS_RX_TMR_DEPKTZ_CTRL_ERROR_o
            );
    else generate
        u_backend_manager_depacketizer_control: entity work.backend_manager_depacketizer_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
                READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,
                VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_o,
                LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_o,

                FLIT_i           => FLIT_w,
                READ_OK_BUFFER_i => READ_OK_BUFFER_w,
                READ_BUFFER_o    => READ_BUFFER_w,

                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w,

                ADD_o              => ADD_w,
                COMPARE_o          => COMPARE_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w
            );
        OBS_RX_TMR_DEPKTZ_CTRL_ERROR_o <= '0';
    end generate;

    u_INTEGRITY_CONTROL_RECEIVE:
    if (p_USE_RX_INTEGRITY_CHECK) generate
        u_integrity_control_receive_hamming: entity work.integrity_control_receive_hamming
            port map(
                ACLK    => ACLK,
                ARESETn => INTEGRITY_RESETn_w,

                ADD_i           => ADD_w,
                VALUE_ADD_i     => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                COMPARE_i       => COMPARE_w,
                VALUE_COMPARE_i => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                CORRUPT_o       => OBS_RX_INTEGRITY_CORRUPT_w,

                correct_error_i => OBS_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
                error_o         => open,

                OBS_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_RX_HAM_INTEGRITY_CORRECT_ERROR_i,
                OBS_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_RX_HAM_INTEGRITY_SINGLE_ERR_o,
                OBS_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_RX_HAM_INTEGRITY_DOUBLE_ERR_o,
                OBS_HAM_INTEGRITY_ENC_DATA_o      => OBS_RX_HAM_INTEGRITY_ENC_DATA_o
            );
    else generate
        -- Integrity disabled.
        OBS_RX_INTEGRITY_CORRUPT_w  <= '0';
        OBS_RX_HAM_INTEGRITY_SINGLE_ERR_o <= '0';
        OBS_RX_HAM_INTEGRITY_DOUBLE_ERR_o <= '0';
        OBS_RX_HAM_INTEGRITY_ENC_DATA_o   <= (others => '0');
    end generate;

    -- Export integrity checker outputs with descriptive names.
    CORRUPT_RECEIVE_o   <= OBS_RX_INTEGRITY_CORRUPT_w;
    OBS_RX_INTEGRITY_CORRUPT_o <= OBS_RX_INTEGRITY_CORRUPT_w;

    u_BUFFER_FIFO:
    if (p_USE_RX_BUFFER_HAMMING) generate
        u_buffer_fifo_ham: entity work.buffer_fifo_ham
            generic map(
                p_DATA_WIDTH   => c_FLIT_WIDTH,
                p_BUFFER_DEPTH => p_BUFFER_DEPTH,
                DETECT_DOUBLE  => DETECT_DOUBLE
            )
            port map(
                ACLK   => ACLK,
                ARESET => ARESET_w,

                -- Read
                READ_OK_o => READ_OK_BUFFER_w,
                READ_i    => READ_BUFFER_w,
                DATA_o    => FLIT_w,

                -- Write
                WRITE_OK_o => WRITE_OK_BUFFER_w,
                WRITE_i    => WRITE_BUFFER_w,
                DATA_i     => l_out_data_o,

                -- Hamming status/control (EXTERNAL WIRES)
                correct_error_i => OBS_RX_HAM_BUFFER_CORRECT_ERROR_i,
                single_err_o    => OBS_RX_HAM_BUFFER_SINGLE_ERR_o,
                double_err_o    => OBS_RX_HAM_BUFFER_DOUBLE_ERR_o,
                enc_stage_data_o => OBS_RX_HAM_BUFFER_ENC_DATA_o,
                OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i => OBS_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
                OBS_HAM_FIFO_CTRL_TMR_ERROR_o         => OBS_RX_TMR_HAM_BUFFER_CTRL_ERROR_o
            );
    else generate
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

        OBS_RX_HAM_BUFFER_ENC_DATA_o <= (others => '0');
        OBS_RX_TMR_HAM_BUFFER_CTRL_ERROR_o <= '0';
    end generate;

    u_RECEIVE_CONTROL:
    if (p_USE_RX_FLOW_CTRL_TMR) generate
        u_receive_control_tmr: entity work.receive_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i,

                correct_error_i => OBS_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_RX_TMR_FLOW_CTRL_ERROR_o
            );
    else generate
        u_receive_control: entity work.receive_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i
            );

        OBS_RX_TMR_FLOW_CTRL_ERROR_o <= '0';
    end generate;

    ARESET_w <= not ARESETn;

end rtl;
