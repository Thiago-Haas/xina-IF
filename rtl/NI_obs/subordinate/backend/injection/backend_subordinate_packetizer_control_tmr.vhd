library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

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
        INTEGRITY_RESETn_o: out std_logic
    );
end backend_subordinate_packetizer_control_tmr;

architecture rtl of backend_subordinate_packetizer_control_tmr is
    type t_BIT_VECTOR is array (2 downto 0) of std_logic;
    type t_BIT_VECTOR_FLIT_SELECTOR is array (2 downto 0) of std_logic_vector(2 downto 0);

    signal READY_SEND_DATA_w: t_BIT_VECTOR;
    signal WRITE_BUFFER_w: t_BIT_VECTOR;
    signal FLIT_SELECTOR_w: t_BIT_VECTOR_FLIT_SELECTOR;
    signal HAS_FINISHED_RESPONSE_w: t_BIT_VECTOR;

    signal ADD_w: t_BIT_VECTOR;
    signal INTEGRITY_RESETn_w: t_BIT_VECTOR;

begin
    TMR:
    for i in 2 downto 0 generate
        u_PACKETIZER_CONTROL: entity work.backend_subordinate_packetizer_control
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
                WRITE_BUFFER_o    => WRITE_BUFFER_w(i)
            );
    end generate;

    READY_SEND_DATA_o <= (READY_SEND_DATA_w(0) and READY_SEND_DATA_w(1)) or
                         (READY_SEND_DATA_w(0) and READY_SEND_DATA_w(2)) or
                         (READY_SEND_DATA_w(1) and READY_SEND_DATA_w(2));

    WRITE_BUFFER_o <= (WRITE_BUFFER_w(0) and WRITE_BUFFER_w(1)) or
                      (WRITE_BUFFER_w(0) and WRITE_BUFFER_w(2)) or
                      (WRITE_BUFFER_w(1) and WRITE_BUFFER_w(2));

    ADD_o <= (ADD_w(0) and ADD_w(1)) or
             (ADD_w(0) and ADD_w(2)) or
             (ADD_w(1) and ADD_w(2));

    INTEGRITY_RESETn_o <= (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(1)) or
                          (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(2)) or
                          (INTEGRITY_RESETn_w(1) and INTEGRITY_RESETn_w(2));

    TMR_FLIT_SELECTOR:
    for i in 2 downto 0 generate
        FLIT_SELECTOR_o(i) <= (FLIT_SELECTOR_w(0)(i) and FLIT_SELECTOR_w(1)(i)) or
                              (FLIT_SELECTOR_w(0)(i) and FLIT_SELECTOR_w(2)(i)) or
                              (FLIT_SELECTOR_w(1)(i) and FLIT_SELECTOR_w(2)(i));
    end generate;

    HAS_FINISHED_RESPONSE_o <= (HAS_FINISHED_RESPONSE_w(0) and HAS_FINISHED_RESPONSE_w(1)) or
                               (HAS_FINISHED_RESPONSE_w(0) and HAS_FINISHED_RESPONSE_w(2)) or
                               (HAS_FINISHED_RESPONSE_w(1) and HAS_FINISHED_RESPONSE_w(2));
end rtl;