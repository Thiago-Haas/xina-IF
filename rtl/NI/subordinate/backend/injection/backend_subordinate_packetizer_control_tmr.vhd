library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity backend_subordinate_packetizer_control_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        OPC_SEND_i       : in std_logic;
        VALID_SEND_DATA_i: in std_logic;
        LAST_SEND_DATA_i : in std_logic;
        READY_SEND_DATA_o: out std_logic;
        FLIT_SELECTOR_o  : out std_logic_vector(2 downto 0);

        -- Signals from reception.
        HAS_REQUEST_PACKET_i   : in std_logic;
        HAS_FINISHED_RESPONSE_o: out std_logic;

        -- Buffer.
        WRITE_OK_BUFFER_i: in std_logic;
        WRITE_BUFFER_o   : out std_logic;

        -- Integrity control.
        ADD_o: out std_logic;
        INTEGRITY_RESETn_o: out std_logic;

        -- Hardening.
        correct_error_i : in  std_logic := '1';
        error_o         : out std_logic := '0'
    );
end backend_subordinate_packetizer_control_tmr;

architecture rtl of backend_subordinate_packetizer_control_tmr is
    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;
    type t_BIT_VECTOR_FLIT_SELECTOR is array (2 downto 0) of std_logic_vector(2 downto 0);

    signal READY_SEND_DATA_w: t_BIT_VECTOR;
    signal WRITE_BUFFER_w: t_BIT_VECTOR;
    signal FLIT_SELECTOR_w: t_BIT_VECTOR_FLIT_SELECTOR;
    signal HAS_FINISHED_RESPONSE_w: t_BIT_VECTOR;

    signal ADD_w: t_BIT_VECTOR;
    signal INTEGRITY_RESETn_w: t_BIT_VECTOR;

    constant c_TMR_VOTE_WIDTH : positive := 8;
    signal bundle_a_w         : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal bundle_b_w         : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal bundle_c_w         : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal corr_bundle_w      : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
    signal error_bits_w       : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);

begin
    TMR:
    for i in 2 downto 0 generate
        attribute DONT_TOUCH of u_backend_subordinate_packetizer_control : label is "TRUE";
        attribute syn_preserve of u_backend_subordinate_packetizer_control : label is true;
        attribute KEEP_HIERARCHY of u_backend_subordinate_packetizer_control : label is "TRUE";
    begin
        u_backend_subordinate_packetizer_control: entity work.backend_subordinate_packetizer_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                OPC_SEND_i => OPC_SEND_i,
                VALID_SEND_DATA_i => VALID_SEND_DATA_i,
                LAST_SEND_DATA_i  => LAST_SEND_DATA_i,
                READY_SEND_DATA_o => READY_SEND_DATA_w(i),
                FLIT_SELECTOR_o   => FLIT_SELECTOR_w(i),

                HAS_REQUEST_PACKET_i    => HAS_REQUEST_PACKET_i,
                HAS_FINISHED_RESPONSE_o => HAS_FINISHED_RESPONSE_w(i),

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_i,
                WRITE_BUFFER_o    => WRITE_BUFFER_w(i),

                ADD_o              => ADD_w(i),
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w(i)
            );
    end generate;

    bundle_a_w <= READY_SEND_DATA_w(0) &
                  WRITE_BUFFER_w(0) &
                  ADD_w(0) &
                  INTEGRITY_RESETn_w(0) &
                  FLIT_SELECTOR_w(0) &
                  HAS_FINISHED_RESPONSE_w(0);

    bundle_b_w <= READY_SEND_DATA_w(1) &
                  WRITE_BUFFER_w(1) &
                  ADD_w(1) &
                  INTEGRITY_RESETn_w(1) &
                  FLIT_SELECTOR_w(1) &
                  HAS_FINISHED_RESPONSE_w(1);

    bundle_c_w <= READY_SEND_DATA_w(2) &
                  WRITE_BUFFER_w(2) &
                  ADD_w(2) &
                  INTEGRITY_RESETn_w(2) &
                  FLIT_SELECTOR_w(2) &
                  HAS_FINISHED_RESPONSE_w(2);

    u_packetizer_tmr_voter: entity work.tmr_voter_block
        generic map(
            p_WIDTH => c_TMR_VOTE_WIDTH
        )
        port map(
            A_i => bundle_a_w,
            B_i => bundle_b_w,
            C_i => bundle_c_w,
            correct_enable_i => correct_error_i,
            corrected_o => corr_bundle_w,
            error_bits_o => error_bits_w,
            error_o => error_o
        );

    READY_SEND_DATA_o       <= corr_bundle_w(7);
    WRITE_BUFFER_o          <= corr_bundle_w(6);
    ADD_o                   <= corr_bundle_w(5);
    INTEGRITY_RESETn_o      <= corr_bundle_w(4);
    FLIT_SELECTOR_o         <= corr_bundle_w(3 downto 1);
    HAS_FINISHED_RESPONSE_o <= corr_bundle_w(0);
end rtl;
