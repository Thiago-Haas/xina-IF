library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity backend_subordinate_injection is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);

        p_BUFFER_DEPTH      : positive;
        p_USE_TMR_PACKETIZER: boolean;
        p_USE_TMR_FLOW      : boolean;
        p_USE_TMR_INTEGRITY : boolean;
        p_USE_HAMMING       : boolean;
        p_USE_INTEGRITY     : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        VALID_SEND_DATA_i: in std_logic;
        LAST_SEND_DATA_i : in std_logic;
        READY_SEND_DATA_o: out std_logic;

        DATA_SEND_i  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        STATUS_SEND_i: in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

        -- Signals from reception.
        H_SRC_RECEIVE_i        : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        H_INTERFACE_RECEIVE_i  : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        HAS_REQUEST_PACKET_i   : in std_logic;
        HAS_FINISHED_RESPONSE_o: out std_logic;

        -- XINA signals.
        l_in_data_i: out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i : out std_logic;
        l_in_ack_o : in std_logic;

        -- Injection FIFO Hamming.
        OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
        OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';

        -- Injection integrity checksum Hamming.
        OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');

        -- Injection flow and packetizer TMR.
        OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o         : out std_logic := '0';
        OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o         : out std_logic := '0'
    );
end backend_subordinate_injection;

architecture rtl of backend_subordinate_injection is
    signal ARESET_w: std_logic;

    -- Packetizer.
    signal FLIT_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal FLIT_SELECTOR_w: std_logic_vector(2 downto 0);

    -- Checksum.
    signal ADD_w: std_logic;
    signal CHECKSUM_w: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
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
    u_PACKETIZER_CONTROL:
    if (p_USE_TMR_PACKETIZER) generate
        u_backend_subordinate_packetizer_control_tmr: entity work.backend_subordinate_packetizer_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                OPC_SEND_i => H_INTERFACE_RECEIVE_i(1),
                VALID_SEND_DATA_i => VALID_SEND_DATA_i,
                LAST_SEND_DATA_i  => LAST_SEND_DATA_i,
                READY_SEND_DATA_o => READY_SEND_DATA_o,
                FLIT_SELECTOR_o   => FLIT_SELECTOR_w,

                HAS_REQUEST_PACKET_i    => HAS_REQUEST_PACKET_i,
                HAS_FINISHED_RESPONSE_o => HAS_FINISHED_RESPONSE_o,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                ADD_o => ADD_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w,

                correct_error_i => OBS_SUB_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o
            );
    else generate
        attribute DONT_TOUCH of u_backend_subordinate_packetizer_control : label is "TRUE";
        attribute syn_preserve of u_backend_subordinate_packetizer_control : label is true;
        attribute KEEP_HIERARCHY of u_backend_subordinate_packetizer_control : label is "TRUE";
    begin
        u_backend_subordinate_packetizer_control: entity work.backend_subordinate_packetizer_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                OPC_SEND_i => H_INTERFACE_RECEIVE_i(1),
                VALID_SEND_DATA_i => VALID_SEND_DATA_i,
                LAST_SEND_DATA_i  => LAST_SEND_DATA_i,
                READY_SEND_DATA_o => READY_SEND_DATA_o,
                FLIT_SELECTOR_o   => FLIT_SELECTOR_w,

                HAS_REQUEST_PACKET_i    => HAS_REQUEST_PACKET_i,
                HAS_FINISHED_RESPONSE_o => HAS_FINISHED_RESPONSE_o,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                ADD_o => ADD_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w
            );

        OBS_SUB_INJ_TMR_PKTZ_CTRL_ERROR_o <= '0';
    end generate;

    u_backend_subordinate_packetizer_datapath: entity work.backend_subordinate_packetizer_datapath
        generic map(
            p_SRC_X => p_SRC_X,
            p_SRC_Y => p_SRC_Y
        )

        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            DATA_SEND_i           => DATA_SEND_i,
            STATUS_SEND_i         => STATUS_SEND_i,
            H_SRC_RECEIVE_i       => H_SRC_RECEIVE_i,
            H_INTERFACE_RECEIVE_i => H_INTERFACE_RECEIVE_i,
            FLIT_SELECTOR_i       => FLIT_SELECTOR_w,
            CHECKSUM_i            => CHECKSUM_w,

            FLIT_o => FLIT_w
        );

    u_INTEGRITY_CONTROL_SEND:
    if (p_USE_INTEGRITY and p_USE_TMR_INTEGRITY) generate
        u_integrity_control_send_hamming: entity work.integrity_control_send_hamming
            port map(
                ACLK    => ACLK,
                ARESETn => INTEGRITY_RESETn_w,

                ADD_i       => ADD_w,
                VALUE_ADD_i => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                CHECKSUM_o => CHECKSUM_w,
                correct_error_i => OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
                error_o         => open,
                OBS_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_SUB_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
                OBS_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
                OBS_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
                OBS_HAM_INTEGRITY_ENC_DATA_o      => OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o
            );
    elsif (p_USE_INTEGRITY) generate
        u_integrity_control_send: entity work.integrity_control_send
            port map(
                ACLK    => ACLK,
                ARESETn => INTEGRITY_RESETn_w,

                ADD_i       => ADD_w,
                VALUE_ADD_i => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                CHECKSUM_o => CHECKSUM_w
            );

        OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o <= '0';
        OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o <= '0';
        OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o   <= (others => '0');
    else generate
        OBS_SUB_INJ_HAM_INTEGRITY_SINGLE_ERR_o <= '0';
        OBS_SUB_INJ_HAM_INTEGRITY_DOUBLE_ERR_o <= '0';
        OBS_SUB_INJ_HAM_INTEGRITY_ENC_DATA_o   <= (others => '0');
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
                DATA_o     => l_in_data_i,

                WRITE_OK_o => WRITE_OK_BUFFER_w,
                WRITE_i    => WRITE_BUFFER_w,
                DATA_i     => FLIT_w,
                correct_error_i => OBS_SUB_INJ_HAM_BUFFER_CORRECT_ERROR_i,
                single_err_o    => OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o,
                double_err_o    => OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o,
                enc_stage_data_o => OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o,
                OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
                OBS_HAM_FIFO_CTRL_TMR_ERROR_o         => OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o
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
                DATA_o     => l_in_data_i,

                WRITE_OK_o => WRITE_OK_BUFFER_w,
                WRITE_i    => WRITE_BUFFER_w,
                DATA_i     => FLIT_w
            );

        OBS_SUB_INJ_HAM_BUFFER_SINGLE_ERR_o <= '0';
        OBS_SUB_INJ_HAM_BUFFER_DOUBLE_ERR_o <= '0';
        OBS_SUB_INJ_HAM_BUFFER_ENC_DATA_o   <= (others => '0');
        OBS_SUB_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o <= '0';
    end generate;

    u_SEND_CONTROL:
    if (p_USE_TMR_FLOW) generate
        u_send_control_tmr: entity work.send_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READ_OK_BUFFER_i => READ_OK_BUFFER_w,
                READ_BUFFER_o    => READ_BUFFER_w,

                l_in_val_i  => l_in_val_i,
                l_in_ack_o  => l_in_ack_o,

                correct_error_i => OBS_SUB_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o
            );
    else generate
        attribute DONT_TOUCH of u_send_control : label is "TRUE";
        attribute syn_preserve of u_send_control : label is true;
        attribute KEEP_HIERARCHY of u_send_control : label is "TRUE";
    begin
        u_send_control: entity work.send_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READ_OK_BUFFER_i => READ_OK_BUFFER_w,
                READ_BUFFER_o    => READ_BUFFER_w,

                l_in_val_i  => l_in_val_i,
                l_in_ack_o  => l_in_ack_o
            );

        OBS_SUB_INJ_TMR_FLOW_CTRL_ERROR_o <= '0';
    end generate;

    ARESET_w <= not ARESETn;
end rtl;
