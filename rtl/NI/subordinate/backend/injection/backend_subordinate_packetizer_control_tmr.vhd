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

    signal corr_READY_SEND_DATA_w       : std_logic;
    signal corr_WRITE_BUFFER_w          : std_logic;
    signal corr_HAS_FINISHED_RESPONSE_w : std_logic;
    signal corr_ADD_w                   : std_logic;
    signal corr_INTEGRITY_RESETn_w      : std_logic;
    signal corr_FLIT_SELECTOR_w         : std_logic_vector(2 downto 0);

    signal error_READY_SEND_DATA_w       : std_logic;
    signal error_WRITE_BUFFER_w          : std_logic;
    signal error_HAS_FINISHED_RESPONSE_w : std_logic;
    signal error_ADD_w                   : std_logic;
    signal error_INTEGRITY_RESETn_w      : std_logic;
    signal error_FLIT_SELECTOR_w         : std_logic_vector(2 downto 0);

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

    corr_READY_SEND_DATA_w <= (READY_SEND_DATA_w(0) and READY_SEND_DATA_w(1)) or
                              (READY_SEND_DATA_w(0) and READY_SEND_DATA_w(2)) or
                              (READY_SEND_DATA_w(1) and READY_SEND_DATA_w(2));

    corr_WRITE_BUFFER_w <= (WRITE_BUFFER_w(0) and WRITE_BUFFER_w(1)) or
                           (WRITE_BUFFER_w(0) and WRITE_BUFFER_w(2)) or
                           (WRITE_BUFFER_w(1) and WRITE_BUFFER_w(2));

    corr_ADD_w <= (ADD_w(0) and ADD_w(1)) or
                  (ADD_w(0) and ADD_w(2)) or
                  (ADD_w(1) and ADD_w(2));

    corr_INTEGRITY_RESETn_w <= (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(1)) or
                               (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(2)) or
                               (INTEGRITY_RESETn_w(1) and INTEGRITY_RESETn_w(2));

    TMR_FLIT_SELECTOR:
    for i in 2 downto 0 generate
        corr_FLIT_SELECTOR_w(i) <= (FLIT_SELECTOR_w(0)(i) and FLIT_SELECTOR_w(1)(i)) or
                                   (FLIT_SELECTOR_w(0)(i) and FLIT_SELECTOR_w(2)(i)) or
                                   (FLIT_SELECTOR_w(1)(i) and FLIT_SELECTOR_w(2)(i));

        error_FLIT_SELECTOR_w(i) <= (FLIT_SELECTOR_w(0)(i) xor FLIT_SELECTOR_w(1)(i)) or
                                    (FLIT_SELECTOR_w(0)(i) xor FLIT_SELECTOR_w(2)(i)) or
                                    (FLIT_SELECTOR_w(1)(i) xor FLIT_SELECTOR_w(2)(i));
    end generate;

    corr_HAS_FINISHED_RESPONSE_w <= (HAS_FINISHED_RESPONSE_w(0) and HAS_FINISHED_RESPONSE_w(1)) or
                                    (HAS_FINISHED_RESPONSE_w(0) and HAS_FINISHED_RESPONSE_w(2)) or
                                    (HAS_FINISHED_RESPONSE_w(1) and HAS_FINISHED_RESPONSE_w(2));

    error_READY_SEND_DATA_w <= (READY_SEND_DATA_w(0) xor READY_SEND_DATA_w(1)) or
                               (READY_SEND_DATA_w(0) xor READY_SEND_DATA_w(2)) or
                               (READY_SEND_DATA_w(1) xor READY_SEND_DATA_w(2));

    error_WRITE_BUFFER_w <= (WRITE_BUFFER_w(0) xor WRITE_BUFFER_w(1)) or
                            (WRITE_BUFFER_w(0) xor WRITE_BUFFER_w(2)) or
                            (WRITE_BUFFER_w(1) xor WRITE_BUFFER_w(2));

    error_ADD_w <= (ADD_w(0) xor ADD_w(1)) or
                   (ADD_w(0) xor ADD_w(2)) or
                   (ADD_w(1) xor ADD_w(2));

    error_INTEGRITY_RESETn_w <= (INTEGRITY_RESETn_w(0) xor INTEGRITY_RESETn_w(1)) or
                                (INTEGRITY_RESETn_w(0) xor INTEGRITY_RESETn_w(2)) or
                                (INTEGRITY_RESETn_w(1) xor INTEGRITY_RESETn_w(2));

    error_HAS_FINISHED_RESPONSE_w <= (HAS_FINISHED_RESPONSE_w(0) xor HAS_FINISHED_RESPONSE_w(1)) or
                                     (HAS_FINISHED_RESPONSE_w(0) xor HAS_FINISHED_RESPONSE_w(2)) or
                                     (HAS_FINISHED_RESPONSE_w(1) xor HAS_FINISHED_RESPONSE_w(2));

    error_o <= error_READY_SEND_DATA_w or
               error_WRITE_BUFFER_w or
               error_ADD_w or
               error_INTEGRITY_RESETn_w or
               error_HAS_FINISHED_RESPONSE_w or
               error_FLIT_SELECTOR_w(0) or
               error_FLIT_SELECTOR_w(1) or
               error_FLIT_SELECTOR_w(2);

    READY_SEND_DATA_o       <= corr_READY_SEND_DATA_w       when correct_error_i = '1' else READY_SEND_DATA_w(0);
    WRITE_BUFFER_o          <= corr_WRITE_BUFFER_w          when correct_error_i = '1' else WRITE_BUFFER_w(0);
    ADD_o                   <= corr_ADD_w                   when correct_error_i = '1' else ADD_w(0);
    INTEGRITY_RESETn_o      <= corr_INTEGRITY_RESETn_w      when correct_error_i = '1' else INTEGRITY_RESETn_w(0);
    FLIT_SELECTOR_o         <= corr_FLIT_SELECTOR_w         when correct_error_i = '1' else FLIT_SELECTOR_w(0);
    HAS_FINISHED_RESPONSE_o <= corr_HAS_FINISHED_RESPONSE_w when correct_error_i = '1' else HAS_FINISHED_RESPONSE_w(0);
end rtl;
