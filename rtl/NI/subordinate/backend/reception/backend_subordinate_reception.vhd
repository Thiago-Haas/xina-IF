library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_subordinate_reception is
    generic(
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
        l_out_ack_i : out std_logic
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

begin
    -- Registering headers.
    registering: process(ACLK)
    begin
        if (rising_edge(ACLK)) then
            if (WRITE_H_SRC_REG_w)       then H_SRC_r_w       <= FLIT_w; end if;
            if (WRITE_H_INTERFACE_REG_w) then H_INTERFACE_r_w <= FLIT_w; end if;
            if (WRITE_H_ADDRESS_REG_w)   then H_ADDRESS_r_w   <= FLIT_w; end if;
        end if;
    end process registering;

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
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w
            );
    else generate
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
                correct_error_i => '0',
                error_o         => open,
                OBS_HAM_INTEGRITY_CORRECT_ERROR_i => '0',
                OBS_HAM_INTEGRITY_SINGLE_ERR_o    => open,
                OBS_HAM_INTEGRITY_DOUBLE_ERR_o    => open,
                OBS_HAM_INTEGRITY_ENC_DATA_o      => open
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
                enc_stage_data_o => open,
                OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i => '1',
                OBS_HAM_FIFO_CTRL_TMR_ERROR_o         => open
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
                l_out_ack_i => l_out_ack_i
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
    end generate;

    ARESET_w <= not ARESETn;
end rtl;
