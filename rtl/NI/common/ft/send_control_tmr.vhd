library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity send_control_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Buffer signals.
        READ_OK_BUFFER_i: in std_logic;
        READ_BUFFER_o   : out std_logic;

        -- XINA signals.
        l_in_val_i: out std_logic;
        l_in_ack_o: in std_logic;

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end send_control_tmr;

architecture rtl of send_control_tmr is

    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;

    signal READ_BUFFER_w: t_BIT_VECTOR;
    signal l_in_val_i_w : t_BIT_VECTOR;

    signal corr_READ_BUFFER_w : std_logic;
    signal corr_l_in_val_i_w  : std_logic;

    signal error_READ_BUFFER_w : std_logic;
    signal error_l_in_val_i_w  : std_logic;

begin

    gen_TMR : for i in 2 downto 0 generate
        attribute DONT_TOUCH of u_SEND_CONTROL : label is "TRUE";
        attribute syn_preserve of u_SEND_CONTROL : label is true;
        attribute KEEP_HIERARCHY of u_SEND_CONTROL : label is "TRUE";
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_SEND_CONTROL : label is "tmr";
        attribute syn_keep         of u_SEND_CONTROL : label is TRUE;
        attribute syn_safe_case    of u_SEND_CONTROL : label is TRUE;
        attribute syn_noprune      of u_SEND_CONTROL : label is TRUE;
    begin
        u_send_control: entity work.send_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                READ_OK_BUFFER_i => READ_OK_BUFFER_i,
                READ_BUFFER_o    => READ_BUFFER_w(i),

                l_in_val_i  => l_in_val_i_w(i),
                l_in_ack_o  => l_in_ack_o
            );
    end generate;

    -- Majority vote (corrected outputs)
    corr_READ_BUFFER_w <= (READ_BUFFER_w(2) and READ_BUFFER_w(1)) or
                          (READ_BUFFER_w(2) and READ_BUFFER_w(0)) or
                          (READ_BUFFER_w(1) and READ_BUFFER_w(0));

    corr_l_in_val_i_w  <= (l_in_val_i_w(2) and l_in_val_i_w(1)) or
                          (l_in_val_i_w(2) and l_in_val_i_w(0)) or
                          (l_in_val_i_w(1) and l_in_val_i_w(0));

    -- Error detection: any mismatch among replicas
    error_READ_BUFFER_w <= (READ_BUFFER_w(2) xor READ_BUFFER_w(1)) or
                           (READ_BUFFER_w(2) xor READ_BUFFER_w(0)) or
                           (READ_BUFFER_w(1) xor READ_BUFFER_w(0));

    error_l_in_val_i_w  <= (l_in_val_i_w(2) xor l_in_val_i_w(1)) or
                           (l_in_val_i_w(2) xor l_in_val_i_w(0)) or
                           (l_in_val_i_w(1) xor l_in_val_i_w(0));

    error_o <= error_READ_BUFFER_w or error_l_in_val_i_w;

    -- Output selection matches control_tmr pattern:
    -- if correction enabled -> majority, else -> replica 0.
    READ_BUFFER_o <= corr_READ_BUFFER_w when correct_error_i = '1' else READ_BUFFER_w(0);
    l_in_val_i    <= corr_l_in_val_i_w  when correct_error_i = '1' else l_in_val_i_w(0);
end rtl;
