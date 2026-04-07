library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

entity backend_manager_depacketizer_control_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;
        VALID_RECEIVE_DATA_o  : out std_logic;
        LAST_RECEIVE_DATA_o   : out std_logic;

        -- Buffer.
        FLIT_i          : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        READ_BUFFER_o   : out std_logic;
        READ_OK_BUFFER_i: in std_logic;

        -- Headers.
        WRITE_H_INTERFACE_REG_o: out std_logic;

        -- Integrity control.
        ADD_o    : out std_logic;
        COMPARE_o: out std_logic;
        INTEGRITY_RESETn_o: out std_logic;

        -- Hardening
        correct_error_i : in  std_logic := '1';
        error_o         : out std_logic := '0'
    );
end backend_manager_depacketizer_control_tmr;

architecture rtl of backend_manager_depacketizer_control_tmr is
    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;

    signal VALID_RECEIVE_DATA_w: t_BIT_VECTOR;
    signal LAST_RECEIVE_DATA_w: t_BIT_VECTOR;
    signal READ_BUFFER_w: t_BIT_VECTOR;
    signal WRITE_H_INTERFACE_REG_w: t_BIT_VECTOR;

    signal ADD_w: t_BIT_VECTOR;
    signal COMPARE_w: t_BIT_VECTOR;
    signal INTEGRITY_RESETn_w: t_BIT_VECTOR;

    signal corr_VALID_RECEIVE_DATA_w  : std_logic;
    signal corr_LAST_RECEIVE_DATA_w   : std_logic;
    signal corr_READ_BUFFER_w         : std_logic;
    signal corr_WRITE_H_INTERFACE_REG_w : std_logic;
    signal corr_ADD_w                 : std_logic;
    signal corr_COMPARE_w             : std_logic;
    signal corr_INTEGRITY_RESETn_w    : std_logic;

    signal error_VALID_RECEIVE_DATA_w  : std_logic;
    signal error_LAST_RECEIVE_DATA_w   : std_logic;
    signal error_READ_BUFFER_w         : std_logic;
    signal error_WRITE_H_INTERFACE_REG_w : std_logic;
    signal error_ADD_w                 : std_logic;
    signal error_COMPARE_w             : std_logic;
    signal error_INTEGRITY_RESETn_w    : std_logic;

begin
    TMR:
    for i in 2 downto 0 generate
        attribute DONT_TOUCH of u_backend_manager_depacketizer_control : label is "TRUE";
        attribute syn_preserve of u_backend_manager_depacketizer_control : label is true;
        attribute KEEP_HIERARCHY of u_backend_manager_depacketizer_control : label is "TRUE";
    begin
        u_backend_manager_depacketizer_control: entity work.backend_manager_depacketizer_control
            port map(
                ACLK => ACLK,
                ARESETn => ARESETn,

                READY_RECEIVE_PACKET_i => READY_RECEIVE_PACKET_i,
                READY_RECEIVE_DATA_i   => READY_RECEIVE_DATA_i,
                VALID_RECEIVE_DATA_o   => VALID_RECEIVE_DATA_w(i),
                LAST_RECEIVE_DATA_o    => LAST_RECEIVE_DATA_w(i),

                FLIT_i => FLIT_i,
                READ_BUFFER_o => READ_BUFFER_w(i),
                READ_OK_BUFFER_i => READ_OK_BUFFER_i,

                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w(i),

                ADD_o              => ADD_w(i),
                COMPARE_o          => COMPARE_w(i),
                INTEGRITY_RESETn_o => INTEGRITY_RESETn_w(i)
            );
    end generate;

    corr_VALID_RECEIVE_DATA_w <= (VALID_RECEIVE_DATA_w(0) and VALID_RECEIVE_DATA_w(1)) or
                                 (VALID_RECEIVE_DATA_w(0) and VALID_RECEIVE_DATA_w(2)) or
                                 (VALID_RECEIVE_DATA_w(1) and VALID_RECEIVE_DATA_w(2));

    corr_LAST_RECEIVE_DATA_w <= (LAST_RECEIVE_DATA_w(0) and LAST_RECEIVE_DATA_w(1)) or
                                (LAST_RECEIVE_DATA_w(0) and LAST_RECEIVE_DATA_w(2)) or
                                (LAST_RECEIVE_DATA_w(1) and LAST_RECEIVE_DATA_w(2));

    corr_READ_BUFFER_w <= (READ_BUFFER_w(0) and READ_BUFFER_w(1)) or
                          (READ_BUFFER_w(0) and READ_BUFFER_w(2)) or
                          (READ_BUFFER_w(1) and READ_BUFFER_w(2));

    corr_WRITE_H_INTERFACE_REG_w <= (WRITE_H_INTERFACE_REG_w(0) and WRITE_H_INTERFACE_REG_w(1)) or
                                    (WRITE_H_INTERFACE_REG_w(0) and WRITE_H_INTERFACE_REG_w(2)) or
                                    (WRITE_H_INTERFACE_REG_w(1) and WRITE_H_INTERFACE_REG_w(2));

    corr_ADD_w <= (ADD_w(0) and ADD_w(1)) or
                  (ADD_w(0) and ADD_w(2)) or
                  (ADD_w(1) and ADD_w(2));

    corr_COMPARE_w <= (COMPARE_w(0) and COMPARE_w(1)) or
                      (COMPARE_w(0) and COMPARE_w(2)) or
                      (COMPARE_w(1) and COMPARE_w(2));

    corr_INTEGRITY_RESETn_w <= (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(1)) or
                               (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(2)) or
                               (INTEGRITY_RESETn_w(1) and INTEGRITY_RESETn_w(2));

    error_VALID_RECEIVE_DATA_w <= (VALID_RECEIVE_DATA_w(0) xor VALID_RECEIVE_DATA_w(1)) or
                                  (VALID_RECEIVE_DATA_w(0) xor VALID_RECEIVE_DATA_w(2)) or
                                  (VALID_RECEIVE_DATA_w(1) xor VALID_RECEIVE_DATA_w(2));

    error_LAST_RECEIVE_DATA_w <= (LAST_RECEIVE_DATA_w(0) xor LAST_RECEIVE_DATA_w(1)) or
                                 (LAST_RECEIVE_DATA_w(0) xor LAST_RECEIVE_DATA_w(2)) or
                                 (LAST_RECEIVE_DATA_w(1) xor LAST_RECEIVE_DATA_w(2));

    error_READ_BUFFER_w <= (READ_BUFFER_w(0) xor READ_BUFFER_w(1)) or
                           (READ_BUFFER_w(0) xor READ_BUFFER_w(2)) or
                           (READ_BUFFER_w(1) xor READ_BUFFER_w(2));

    error_WRITE_H_INTERFACE_REG_w <= (WRITE_H_INTERFACE_REG_w(0) xor WRITE_H_INTERFACE_REG_w(1)) or
                                     (WRITE_H_INTERFACE_REG_w(0) xor WRITE_H_INTERFACE_REG_w(2)) or
                                     (WRITE_H_INTERFACE_REG_w(1) xor WRITE_H_INTERFACE_REG_w(2));

    error_ADD_w <= (ADD_w(0) xor ADD_w(1)) or
                   (ADD_w(0) xor ADD_w(2)) or
                   (ADD_w(1) xor ADD_w(2));

    error_COMPARE_w <= (COMPARE_w(0) xor COMPARE_w(1)) or
                       (COMPARE_w(0) xor COMPARE_w(2)) or
                       (COMPARE_w(1) xor COMPARE_w(2));

    error_INTEGRITY_RESETn_w <= (INTEGRITY_RESETn_w(0) xor INTEGRITY_RESETn_w(1)) or
                                (INTEGRITY_RESETn_w(0) xor INTEGRITY_RESETn_w(2)) or
                                (INTEGRITY_RESETn_w(1) xor INTEGRITY_RESETn_w(2));

    error_o <= error_VALID_RECEIVE_DATA_w or
               error_LAST_RECEIVE_DATA_w or
               error_READ_BUFFER_w or
               error_WRITE_H_INTERFACE_REG_w or
               error_ADD_w or
               error_COMPARE_w or
               error_INTEGRITY_RESETn_w;

    VALID_RECEIVE_DATA_o <= corr_VALID_RECEIVE_DATA_w when correct_error_i = '1' else VALID_RECEIVE_DATA_w(0);
    LAST_RECEIVE_DATA_o <= corr_LAST_RECEIVE_DATA_w when correct_error_i = '1' else LAST_RECEIVE_DATA_w(0);
    READ_BUFFER_o <= corr_READ_BUFFER_w when correct_error_i = '1' else READ_BUFFER_w(0);
    WRITE_H_INTERFACE_REG_o <= corr_WRITE_H_INTERFACE_REG_w when correct_error_i = '1' else WRITE_H_INTERFACE_REG_w(0);
    ADD_o <= corr_ADD_w when correct_error_i = '1' else ADD_w(0);
    COMPARE_o <= corr_COMPARE_w when correct_error_i = '1' else COMPARE_w(0);
    INTEGRITY_RESETn_o <= corr_INTEGRITY_RESETn_w when correct_error_i = '1' else INTEGRITY_RESETn_w(0);
end rtl;
