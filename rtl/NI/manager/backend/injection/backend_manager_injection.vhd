library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_injection is
    generic(
        p_SRC_X: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        p_SRC_Y: std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);

        p_BUFFER_DEPTH            : positive;
        p_USE_INJ_PKTZ_CTRL_TMR  : boolean;
        p_USE_INJ_FLOW_CTRL_TMR  : boolean;
        p_USE_INJ_INTEGRITY_CHECK: boolean;
        p_USE_INJ_BUFFER_HAMMING : boolean;

        DETECT_DOUBLE : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
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

        -- XINA signals.
        l_in_data_i: out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_in_val_i : out std_logic;
        l_in_ack_o : in std_logic;

        -- Hamming (new buffer ports) - EXTERNAL
        OBS_INJ_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic;
        OBS_INJ_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
        OBS_INJ_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
        OBS_INJ_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, DETECT_DOUBLE) - 1 downto 0);
        OBS_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o         : out std_logic := '0';

        -- Injection integrity (checksum) Hamming.
        OBS_INJ_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_INJ_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic := '0';
        OBS_INJ_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic := '0';
        OBS_INJ_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

        -- Injection flow control TMR (send_control_tmr)
        -- Meaningful when p_USE_INJ_FLOW_CTRL_TMR = TRUE.
        OBS_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_INJ_TMR_FLOW_CTRL_ERROR_o       : out std_logic := '0';

        -- Injection packetizer control TMR (backend_manager_packetizer_control_tmr)
        -- Meaningful when p_USE_INJ_PKTZ_CTRL_TMR = TRUE.
        OBS_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i : in  std_logic := '0';
        OBS_INJ_TMR_PKTZ_CTRL_ERROR_o       : out std_logic := '0'
    );
end backend_manager_injection;

architecture rtl of backend_manager_injection is

    signal ARESET_w: std_logic;

    -- Routing table.
    signal OPC_ADDR_w: std_logic_vector((c_AXI_ADDR_WIDTH / 2) - 1 downto 0);
    signal DEST_X_w  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
    signal DEST_Y_w  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);

    -- Packetizer.
    signal FLIT_w: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    signal FLIT_SELECTOR_w: std_logic_vector(2 downto 0);

    -- Checksum.
    signal ADD_w: std_logic;
    signal CHECKSUM_w: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal INTEGRITY_RESETn_w: std_logic;
    signal OBS_INJ_TMR_PKTZ_CTRL_ERROR_w: std_logic;

    -- FIFO.
    signal WRITE_BUFFER_w   : std_logic;
    signal WRITE_OK_BUFFER_w: std_logic;
    signal READ_BUFFER_w    : std_logic;
    signal READ_OK_BUFFER_w : std_logic;

begin
    u_backend_manager_routing_table: entity work.backend_manager_routing_table
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            ADDR_i     => ADDR_i,

            OPC_ADDR_o => OPC_ADDR_w,
            DEST_X_o   => DEST_X_w,
            DEST_Y_o   => DEST_Y_w
        );

    u_PACKETIZER_CONTROL:
    if (p_USE_INJ_PKTZ_CTRL_TMR) generate
        u_backend_manager_packetizer_control_tmr: entity work.backend_manager_packetizer_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                OPC_SEND_i          => OPC_SEND_i,
                START_SEND_PACKET_i => START_SEND_PACKET_i,
                VALID_SEND_DATA_i   => VALID_SEND_DATA_i,
                LAST_SEND_DATA_i    => LAST_SEND_DATA_i,

                READY_SEND_PACKET_o => READY_SEND_PACKET_o,
                READY_SEND_DATA_o   => READY_SEND_DATA_o,
                FLIT_SELECTOR_o     => FLIT_SELECTOR_w,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                ADD_o              => ADD_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w,

                correct_error_i => OBS_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_INJ_TMR_PKTZ_CTRL_ERROR_w
            );
    else generate
    begin
        u_backend_manager_packetizer_control: entity work.backend_manager_packetizer_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                OPC_SEND_i           => OPC_SEND_i,
                START_SEND_PACKET_i  => START_SEND_PACKET_i,
                VALID_SEND_DATA_i    => VALID_SEND_DATA_i,
                LAST_SEND_DATA_i     => LAST_SEND_DATA_i,

                READY_SEND_PACKET_o  => READY_SEND_PACKET_o,
                READY_SEND_DATA_o    => READY_SEND_DATA_o,
                FLIT_SELECTOR_o      => FLIT_SELECTOR_w,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_w,
                WRITE_BUFFER_o    => WRITE_BUFFER_w,

                ADD_o              => ADD_w,
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w
            );

        OBS_INJ_TMR_PKTZ_CTRL_ERROR_w   <= '0';
    end generate;

    u_backend_manager_packetizer_datapath: entity work.backend_manager_packetizer_datapath
        generic map(
            p_SRC_X => p_SRC_X,
            p_SRC_Y => p_SRC_Y
        )
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            OPC_ADDR_i  => OPC_ADDR_w,
            ID_i        => ID_i,
            LENGTH_i    => LENGTH_i,
            BURST_i     => BURST_i,
            OPC_SEND_i  => OPC_SEND_i,
            DATA_SEND_i => DATA_SEND_i,

            DEST_X_i        => DEST_X_w,
            DEST_Y_i        => DEST_Y_w,
            FLIT_SELECTOR_i => FLIT_SELECTOR_w,
            CHECKSUM_i      => CHECKSUM_w,

            FLIT_o => FLIT_w
        );

    u_INTEGRITY_CONTROL_SEND:
    if (p_USE_INJ_INTEGRITY_CHECK) generate
        u_integrity_control_send_hamming: entity work.integrity_control_send_hamming
            port map(
                ACLK    => ACLK,
                ARESETn => INTEGRITY_RESETn_w,

                ADD_i       => ADD_w,
                VALUE_ADD_i => FLIT_w(c_AXI_DATA_WIDTH - 1 downto 0),

                CHECKSUM_o      => CHECKSUM_w,

                correct_error_i => OBS_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
                error_o         => open,

                OBS_HAM_INTEGRITY_CORRECT_ERROR_i => OBS_INJ_HAM_INTEGRITY_CORRECT_ERROR_i,
                OBS_HAM_INTEGRITY_SINGLE_ERR_o    => OBS_INJ_HAM_INTEGRITY_SINGLE_ERR_o,
                OBS_HAM_INTEGRITY_DOUBLE_ERR_o    => OBS_INJ_HAM_INTEGRITY_DOUBLE_ERR_o,
                OBS_HAM_INTEGRITY_ENC_DATA_o      => OBS_INJ_HAM_INTEGRITY_ENC_DATA_o
            );
    end generate;

    u_INTEGRITY_CONTROL_SEND_DISABLE:
    if (not p_USE_INJ_INTEGRITY_CHECK) generate
        OBS_INJ_HAM_INTEGRITY_SINGLE_ERR_o <= '0';
        OBS_INJ_HAM_INTEGRITY_DOUBLE_ERR_o <= '0';
        OBS_INJ_HAM_INTEGRITY_ENC_DATA_o   <= (others => '0');
        OBS_INJ_TMR_PKTZ_CTRL_ERROR_w   <= '0';
    end generate;

    u_BUFFER_FIFO:
    if (p_USE_INJ_BUFFER_HAMMING) generate
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
                DATA_o    => l_in_data_i,

                -- Write
                WRITE_OK_o => WRITE_OK_BUFFER_w,
                WRITE_i    => WRITE_BUFFER_w,
                DATA_i     => FLIT_w,

                -- Hamming status/control (EXTERNAL WIRES)
                correct_error_i => OBS_INJ_HAM_BUFFER_CORRECT_ERROR_i,
                single_err_o    => OBS_INJ_HAM_BUFFER_SINGLE_ERR_o,
                double_err_o    => OBS_INJ_HAM_BUFFER_DOUBLE_ERR_o,
                enc_stage_data_o => OBS_INJ_HAM_BUFFER_ENC_DATA_o,
                OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i => OBS_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i,
                OBS_HAM_FIFO_CTRL_TMR_ERROR_o         => OBS_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o
            );
    else generate
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

        OBS_INJ_HAM_BUFFER_ENC_DATA_o <= (others => '0');
        OBS_INJ_TMR_HAM_BUFFER_CTRL_ERROR_o <= '0';
    end generate;

    u_SEND_CONTROL:
    if (p_USE_INJ_FLOW_CTRL_TMR) generate
        u_send_control_tmr: entity work.send_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READ_OK_BUFFER_i => READ_OK_BUFFER_w,
                READ_BUFFER_o    => READ_BUFFER_w,

                l_in_val_i => l_in_val_i,
                l_in_ack_o => l_in_ack_o,

                correct_error_i => OBS_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i,
                error_o         => OBS_INJ_TMR_FLOW_CTRL_ERROR_o
            );
    else generate
    begin
        u_send_control: entity work.send_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READ_OK_BUFFER_i => READ_OK_BUFFER_w,
                READ_BUFFER_o    => READ_BUFFER_w,

                l_in_val_i => l_in_val_i,
                l_in_ack_o => l_in_ack_o
            );

        OBS_INJ_TMR_FLOW_CTRL_ERROR_o <= '0';
    end generate;

    ARESET_w <= not ARESETn;

    OBS_INJ_TMR_PKTZ_CTRL_ERROR_o   <= OBS_INJ_TMR_PKTZ_CTRL_ERROR_w;

end rtl;
