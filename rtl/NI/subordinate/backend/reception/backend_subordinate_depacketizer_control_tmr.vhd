library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity backend_subordinate_depacketizer_control_tmr is
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

        -- Signals from injection.
        HAS_FINISHED_RESPONSE_i: in std_logic;
        HAS_REQUEST_PACKET_o   : out std_logic;

        -- Buffer.
        FLIT_i          : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        READ_BUFFER_o   : out std_logic;
        READ_OK_BUFFER_i: in std_logic;

        -- Headers.
        H_INTERFACE_i: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

        WRITE_H_SRC_REG_o: out std_logic;
        WRITE_H_INTERFACE_REG_o: out std_logic;
        WRITE_H_ADDRESS_REG_o  : out std_logic;

        -- Integrity control.
        ADD_o    : out std_logic;
        COMPARE_o: out std_logic;
        INTEGRITY_RESETn_o: out std_logic;

        -- Hardening.
        correct_error_i : in  std_logic := '1';
        error_o         : out std_logic := '0'
    );
end backend_subordinate_depacketizer_control_tmr;

architecture rtl of backend_subordinate_depacketizer_control_tmr is
    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;

    signal VALID_RECEIVE_PACKET_w: t_BIT_VECTOR;
    signal VALID_RECEIVE_DATA_w: t_BIT_VECTOR;
    signal LAST_RECEIVE_DATA_w: t_BIT_VECTOR;
    signal HAS_REQUEST_PACKET_w: t_BIT_VECTOR;
    signal READ_BUFFER_w: t_BIT_VECTOR;
    signal WRITE_H_SRC_REG_w: t_BIT_VECTOR;
    signal WRITE_H_INTERFACE_REG_w: t_BIT_VECTOR;
    signal WRITE_H_ADDRESS_REG_w: t_BIT_VECTOR;

    signal ADD_w: t_BIT_VECTOR;
    signal COMPARE_w: t_BIT_VECTOR;
    signal INTEGRITY_RESETn_w: t_BIT_VECTOR;

    constant c_TMR_VOTE_WIDTH : positive := 11;
    signal bundle_a_w         : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal bundle_b_w         : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal bundle_c_w         : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal corr_bundle_w      : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);

begin
    TMR:
    for i in 2 downto 0 generate
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
                VALID_RECEIVE_PACKET_o => VALID_RECEIVE_PACKET_w(i),
                VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_w(i),
                LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_w(i),

                HAS_FINISHED_RESPONSE_i => HAS_FINISHED_RESPONSE_i,
                HAS_REQUEST_PACKET_o    => HAS_REQUEST_PACKET_w(i),

                FLIT_i => FLIT_i,
                READ_BUFFER_o => READ_BUFFER_w(i),
                READ_OK_BUFFER_i => READ_OK_BUFFER_i,

                H_INTERFACE_i => H_INTERFACE_i,

                WRITE_H_SRC_REG_o => WRITE_H_SRC_REG_w(i),
                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w(i),
                WRITE_H_ADDRESS_REG_o   => WRITE_H_ADDRESS_REG_w(i),

                ADD_o              => ADD_w(i),
                COMPARE_o          => COMPARE_w(i),
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w(i)
            );
    end generate;

    bundle_a_w <= VALID_RECEIVE_PACKET_w(0) &
                  VALID_RECEIVE_DATA_w(0) &
                  LAST_RECEIVE_DATA_w(0) &
                  HAS_REQUEST_PACKET_w(0) &
                  READ_BUFFER_w(0) &
                  WRITE_H_SRC_REG_w(0) &
                  WRITE_H_INTERFACE_REG_w(0) &
                  WRITE_H_ADDRESS_REG_w(0) &
                  ADD_w(0) &
                  COMPARE_w(0) &
                  INTEGRITY_RESETn_w(0);

    bundle_b_w <= VALID_RECEIVE_PACKET_w(1) &
                  VALID_RECEIVE_DATA_w(1) &
                  LAST_RECEIVE_DATA_w(1) &
                  HAS_REQUEST_PACKET_w(1) &
                  READ_BUFFER_w(1) &
                  WRITE_H_SRC_REG_w(1) &
                  WRITE_H_INTERFACE_REG_w(1) &
                  WRITE_H_ADDRESS_REG_w(1) &
                  ADD_w(1) &
                  COMPARE_w(1) &
                  INTEGRITY_RESETn_w(1);

    bundle_c_w <= VALID_RECEIVE_PACKET_w(2) &
                  VALID_RECEIVE_DATA_w(2) &
                  LAST_RECEIVE_DATA_w(2) &
                  HAS_REQUEST_PACKET_w(2) &
                  READ_BUFFER_w(2) &
                  WRITE_H_SRC_REG_w(2) &
                  WRITE_H_INTERFACE_REG_w(2) &
                  WRITE_H_ADDRESS_REG_w(2) &
                  ADD_w(2) &
                  COMPARE_w(2) &
                  INTEGRITY_RESETn_w(2);

    u_depacketizer_tmr_voter: entity work.tmr_voter_block
        generic map(
            p_WIDTH => c_TMR_VOTE_WIDTH
        )
        port map(
            A_i => bundle_a_w,
            B_i => bundle_b_w,
            C_i => bundle_c_w,
            correct_enable_i => correct_error_i,
            corrected_o => corr_bundle_w,
            error_bits_o => open,
            error_o => error_o
        );

    VALID_RECEIVE_PACKET_o  <= corr_bundle_w(10);
    VALID_RECEIVE_DATA_o    <= corr_bundle_w(9);
    LAST_RECEIVE_DATA_o     <= corr_bundle_w(8);
    HAS_REQUEST_PACKET_o    <= corr_bundle_w(7);
    READ_BUFFER_o           <= corr_bundle_w(6);
    WRITE_H_SRC_REG_o       <= corr_bundle_w(5);
    WRITE_H_INTERFACE_REG_o <= corr_bundle_w(4);
    WRITE_H_ADDRESS_REG_o   <= corr_bundle_w(3);
    ADD_o                   <= corr_bundle_w(2);
    COMPARE_o               <= corr_bundle_w(1);
    INTEGRITY_RESETn_o      <= corr_bundle_w(0);
end rtl;
