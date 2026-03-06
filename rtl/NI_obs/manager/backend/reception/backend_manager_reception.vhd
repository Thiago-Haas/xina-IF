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
        p_USE_RX_INTEGRITY_TMR  : boolean;
        p_USE_RX_INTERFACE_HDR_HAMMING: boolean;
        p_USE_RX_BUFFER_HAMMING : boolean;

        DETECT_DOUBLE : boolean
    );

    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        i_READY_RECEIVE_PACKET: in std_logic;
        i_READY_RECEIVE_DATA  : in std_logic;

        o_VALID_RECEIVE_DATA: out std_logic;
        o_LAST_RECEIVE_DATA : out std_logic;

        o_ID_RECEIVE    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
        o_STATUS_RECEIVE: out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        o_OPC_RECEIVE   : out std_logic;
        o_DATA_RECEIVE  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        o_CORRUPT_RECEIVE: out std_logic := '0';

        -- XINA signals.
        l_out_data_o: in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        l_out_val_o : in  std_logic;
        l_out_ack_i : out std_logic;

        -- Hamming (buffer) - EXTERNAL
        i_OBS_RX_HAM_BUFFER_CORRECT_ERROR : in  std_logic;
        o_OBS_RX_HAM_BUFFER_SINGLE_ERR    : out std_logic;
        o_OBS_RX_HAM_BUFFER_DOUBLE_ERR    : out std_logic;
        -- Hamming (interface header register) - EXTERNAL
        i_OBS_RX_HAM_INTERFACE_HDR_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_RX_HAM_INTERFACE_HDR_SINGLE_ERR    : out std_logic := '0';
        o_OBS_RX_HAM_INTERFACE_HDR_DOUBLE_ERR    : out std_logic := '0';

        -- Integrity receive checker (integrity_control_receive[_tmr]) - EXTERNAL
        -- Meaningful when p_USE_RX_INTEGRITY_CHECK = TRUE.
        o_OBS_RX_INTEGRITY_CORRUPT        : out std_logic := '0';
        -- TMR path removed for this checker (kept for interface compatibility).
        i_OBS_RX_TMR_INTEGRITY_CORRECT_ERROR  : in  std_logic := '0';
        o_OBS_RX_TMR_INTEGRITY_ERROR        : out std_logic := '0';
        -- Meaningful when p_USE_RX_INTEGRITY_CHECK = TRUE.
        i_OBS_RX_HAM_INTEGRITY_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_RX_HAM_INTEGRITY_SINGLE_ERR    : out std_logic := '0';
        o_OBS_RX_HAM_INTEGRITY_DOUBLE_ERR    : out std_logic := '0';

        -- Receive flow control TMR (receive_control_tmr) - EXTERNAL
        -- Meaningful when p_USE_RX_FLOW_CTRL_TMR = TRUE.
        i_OBS_RX_TMR_FLOW_CTRL_CORRECT_ERROR : in  std_logic := '0';
        o_OBS_RX_TMR_FLOW_CTRL_ERROR       : out std_logic := '0'
    );
end backend_manager_reception;

architecture rtl of backend_manager_reception is
    signal w_ARESET: std_logic;

    -- Depacketizer.
    signal w_FLIT: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- Registers.
    signal w_WRITE_H_INTERFACE_REG: std_logic;
    signal w_H_INTERFACE: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- Integrity (receive) outputs.
    signal w_OBS_RX_INTEGRITY_CORRUPT : std_logic;

    -- Checksum.
    signal w_ADD: std_logic;
    signal w_COMPARE: std_logic;
    signal w_INTEGRITY_RESETn: std_logic;

    -- FIFO.
    signal w_WRITE_BUFFER   : std_logic;
    signal w_WRITE_OK_BUFFER: std_logic;
    signal w_READ_BUFFER    : std_logic;
    signal w_READ_OK_BUFFER : std_logic;

begin
    u_H_INTERFACE_REG: entity work.backend_manager_reception_h_interface_reg
        generic map(
            p_USE_HAMMING           => p_USE_RX_INTERFACE_HDR_HAMMING,
            p_HAMMING_DETECT_DOUBLE => DETECT_DOUBLE
        )
        port map(
            ACLK    => ACLK,
            ARESETn => ARESETn,

            i_WRITE_EN => w_WRITE_H_INTERFACE_REG,
            i_DATA     => w_FLIT,
            o_DATA     => w_H_INTERFACE,

            i_OBS_HAM_CORRECT_ERROR => i_OBS_RX_HAM_INTERFACE_HDR_CORRECT_ERROR,
            o_OBS_HAM_SINGLE_ERR    => o_OBS_RX_HAM_INTERFACE_HDR_SINGLE_ERR,
            o_OBS_HAM_DOUBLE_ERR    => o_OBS_RX_HAM_INTERFACE_HDR_DOUBLE_ERR
        );

    o_ID_RECEIVE     <= w_H_INTERFACE(19 downto 15);
    o_STATUS_RECEIVE <= w_H_INTERFACE(4 downto 2);
    o_OPC_RECEIVE    <= w_H_INTERFACE(1);
    o_DATA_RECEIVE   <= w_FLIT(31 downto 0);

    u_DEPACKETIZER_CONTROL:
    if (p_USE_RX_DEPKTZ_CTRL_TMR) generate
        u_DEPACKETIZER_CONTROL_TMR: entity work.backend_manager_depacketizer_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_READY_RECEIVE_PACKET => i_READY_RECEIVE_PACKET,
                i_READY_RECEIVE_DATA   => i_READY_RECEIVE_DATA,
                o_VALID_RECEIVE_DATA   => o_VALID_RECEIVE_DATA,
                o_LAST_RECEIVE_DATA    => o_LAST_RECEIVE_DATA,

                i_FLIT           => w_FLIT,
                i_READ_OK_BUFFER => w_READ_OK_BUFFER,
                o_READ_BUFFER    => w_READ_BUFFER,

                o_WRITE_H_INTERFACE_REG => w_WRITE_H_INTERFACE_REG,

                o_ADD              => w_ADD,
                o_COMPARE          => w_COMPARE,
                o_INTEGRITY_RESETn => w_INTEGRITY_RESETn
            );
    else generate
        u_DEPACKETIZER_CONTROL_NORMAL: entity work.backend_manager_depacketizer_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_READY_RECEIVE_PACKET => i_READY_RECEIVE_PACKET,
                i_READY_RECEIVE_DATA   => i_READY_RECEIVE_DATA,
                o_VALID_RECEIVE_DATA   => o_VALID_RECEIVE_DATA,
                o_LAST_RECEIVE_DATA    => o_LAST_RECEIVE_DATA,

                i_FLIT           => w_FLIT,
                i_READ_OK_BUFFER => w_READ_OK_BUFFER,
                o_READ_BUFFER    => w_READ_BUFFER,

                o_WRITE_H_INTERFACE_REG => w_WRITE_H_INTERFACE_REG,

                o_ADD              => w_ADD,
                o_COMPARE          => w_COMPARE,
                o_INTEGRITY_RESETn => w_INTEGRITY_RESETn
            );
    end generate;

    u_INTEGRITY_CONTROL_RECEIVE:
    if (p_USE_RX_INTEGRITY_CHECK) generate
        u_INTEGRITY_CONTROL_RECEIVE_HAM: entity work.integrity_control_receive_hamming
            port map(
                ACLK    => ACLK,
                ARESETn => w_INTEGRITY_RESETn,

                i_ADD           => w_ADD,
                i_VALUE_ADD     => w_FLIT(c_AXI_DATA_WIDTH - 1 downto 0),

                i_COMPARE       => w_COMPARE,
                i_VALUE_COMPARE => w_FLIT(c_AXI_DATA_WIDTH - 1 downto 0),

                o_CORRUPT       => w_OBS_RX_INTEGRITY_CORRUPT,

                correct_error_i => '0',
                error_o         => o_OBS_RX_TMR_INTEGRITY_ERROR,

                i_OBS_HAM_INTEGRITY_CORRECT_ERROR => i_OBS_RX_HAM_INTEGRITY_CORRECT_ERROR,
                o_OBS_HAM_INTEGRITY_SINGLE_ERR    => o_OBS_RX_HAM_INTEGRITY_SINGLE_ERR,
                o_OBS_HAM_INTEGRITY_DOUBLE_ERR    => o_OBS_RX_HAM_INTEGRITY_DOUBLE_ERR
            );
    else generate
        -- Integrity disabled.
        w_OBS_RX_INTEGRITY_CORRUPT  <= '0';
        o_OBS_RX_TMR_INTEGRITY_ERROR  <= '0';
        o_OBS_RX_HAM_INTEGRITY_SINGLE_ERR <= '0';
        o_OBS_RX_HAM_INTEGRITY_DOUBLE_ERR <= '0';
    end generate;

    -- Export integrity checker outputs with descriptive names.
    o_CORRUPT_RECEIVE   <= w_OBS_RX_INTEGRITY_CORRUPT;
    o_OBS_RX_INTEGRITY_CORRUPT <= w_OBS_RX_INTEGRITY_CORRUPT;

    u_BUFFER_FIFO:
    if (p_USE_RX_BUFFER_HAMMING) generate
        u_BUFFER_FIFO_HAM: entity work.buffer_fifo_ham
            generic map(
                p_DATA_WIDTH   => c_FLIT_WIDTH,
                p_BUFFER_DEPTH => p_BUFFER_DEPTH,
                DETECT_DOUBLE  => DETECT_DOUBLE
            )
            port map(
                ACLK   => ACLK,
                ARESET => w_ARESET,

                -- Read
                o_READ_OK => w_READ_OK_BUFFER,
                i_READ    => w_READ_BUFFER,
                o_DATA    => w_FLIT,

                -- Write
                o_WRITE_OK => w_WRITE_OK_BUFFER,
                i_WRITE    => w_WRITE_BUFFER,
                i_DATA     => l_out_data_o,

                -- Hamming status/control (EXTERNAL WIRES)
                correct_error_i => i_OBS_RX_HAM_BUFFER_CORRECT_ERROR,
                single_err_o    => o_OBS_RX_HAM_BUFFER_SINGLE_ERR,
                double_err_o    => o_OBS_RX_HAM_BUFFER_DOUBLE_ERR
            );
    else generate
        u_BUFFER_FIFO_NORMAL: entity work.buffer_fifo
            generic map(
                p_DATA_WIDTH   => c_FLIT_WIDTH,
                p_BUFFER_DEPTH => p_BUFFER_DEPTH
            )
            port map(
                ACLK   => ACLK,
                ARESET => w_ARESET,

                o_READ_OK  => w_READ_OK_BUFFER,
                i_READ     => w_READ_BUFFER,
                o_DATA     => w_FLIT,

                o_WRITE_OK => w_WRITE_OK_BUFFER,
                i_WRITE    => w_WRITE_BUFFER,
                i_DATA     => l_out_data_o
            );
    end generate;

    u_RECEIVE_CONTROL:
    if (p_USE_RX_FLOW_CTRL_TMR) generate
        u_RECEIVE_CONTROL_TMR: entity work.receive_control_tmr
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_WRITE_OK_BUFFER => w_WRITE_OK_BUFFER,
                o_WRITE_BUFFER    => w_WRITE_BUFFER,

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i,

                correct_error_i => i_OBS_RX_TMR_FLOW_CTRL_CORRECT_ERROR,
                error_o         => o_OBS_RX_TMR_FLOW_CTRL_ERROR
            );
    else generate
        u_RECEIVE_CONTROL_NORMAL: entity work.receive_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_WRITE_OK_BUFFER => w_WRITE_OK_BUFFER,
                o_WRITE_BUFFER    => w_WRITE_BUFFER,

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i
            );

        o_OBS_RX_TMR_FLOW_CTRL_ERROR <= '0';
    end generate;

    w_ARESET <= not ARESETn;

end rtl;
