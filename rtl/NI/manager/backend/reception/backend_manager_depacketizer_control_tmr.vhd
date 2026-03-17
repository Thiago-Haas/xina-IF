library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

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
        INTEGRITY_RESETn_o: out std_logic
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

                WRITE_H_INTERFACE_REG_o => WRITE_H_INTERFACE_REG_w(i)
            );
    end generate;

    VALID_RECEIVE_DATA_o <= (VALID_RECEIVE_DATA_w(0) and VALID_RECEIVE_DATA_w(1)) or
                            (VALID_RECEIVE_DATA_w(0) and VALID_RECEIVE_DATA_w(2)) or
                            (VALID_RECEIVE_DATA_w(1) and VALID_RECEIVE_DATA_w(2));

    LAST_RECEIVE_DATA_o <= (LAST_RECEIVE_DATA_w(0) and LAST_RECEIVE_DATA_w(1)) or
                           (LAST_RECEIVE_DATA_w(0) and LAST_RECEIVE_DATA_w(2)) or
                           (LAST_RECEIVE_DATA_w(1) and LAST_RECEIVE_DATA_w(2));

    READ_BUFFER_o <= (READ_BUFFER_w(0) and READ_BUFFER_w(1)) or
                     (READ_BUFFER_w(0) and READ_BUFFER_w(2)) or
                     (READ_BUFFER_w(1) and READ_BUFFER_w(2));

    WRITE_H_INTERFACE_REG_o <= (WRITE_H_INTERFACE_REG_w(0) and WRITE_H_INTERFACE_REG_w(1)) or
                               (WRITE_H_INTERFACE_REG_w(0) and WRITE_H_INTERFACE_REG_w(2)) or
                               (WRITE_H_INTERFACE_REG_w(1) and WRITE_H_INTERFACE_REG_w(2));

    ADD_o              <= (ADD_w(0) and ADD_w(1)) or
                          (ADD_w(0) and ADD_w(2)) or
                          (ADD_w(1) and ADD_w(2));

    COMPARE_o          <= (COMPARE_w(0) and COMPARE_w(1)) or
                          (COMPARE_w(0) and COMPARE_w(2)) or
                          (COMPARE_w(1) and COMPARE_w(2));

    INTEGRITY_RESETn_o <= (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(1)) or
                          (INTEGRITY_RESETn_w(0) and INTEGRITY_RESETn_w(2)) or
                          (INTEGRITY_RESETn_w(1) and INTEGRITY_RESETn_w(2));
end rtl;
