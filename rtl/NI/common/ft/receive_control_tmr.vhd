library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity receive_control_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Buffer signals.
        WRITE_OK_BUFFER_i: in std_logic;
        WRITE_BUFFER_o   : out std_logic;

        -- XINA signals.
        l_out_val_o: in std_logic;
        l_out_ack_i: out std_logic;

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end receive_control_tmr;

architecture rtl of receive_control_tmr is

    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;

    signal WRITE_BUFFER_w : t_BIT_VECTOR;
    signal l_out_ack_i_w  : t_BIT_VECTOR;

    signal corr_WRITE_BUFFER_w : std_logic;
    signal corr_l_out_ack_i_w  : std_logic;

    signal error_WRITE_BUFFER_w : std_logic;
    signal error_l_out_ack_i_w  : std_logic;

begin

    gen_TMR : for i in 2 downto 0 generate
        attribute DONT_TOUCH of u_receive_control : label is "TRUE";
        attribute syn_preserve of u_receive_control : label is true;
        attribute KEEP_HIERARCHY of u_receive_control : label is "TRUE";
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_receive_control : label is "tmr";
        attribute syn_keep         of u_receive_control : label is TRUE;
        attribute syn_safe_case    of u_receive_control : label is TRUE;
        attribute syn_noprune      of u_receive_control : label is TRUE;
    begin
        u_receive_control: entity work.receive_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                WRITE_OK_BUFFER_i => WRITE_OK_BUFFER_i,
                WRITE_BUFFER_o    => WRITE_BUFFER_w(i),

                l_out_val_o => l_out_val_o,
                l_out_ack_i => l_out_ack_i_w(i)
            );
    end generate;

    -- Majority vote (corrected outputs)
    corr_WRITE_BUFFER_w <= (WRITE_BUFFER_w(2) and WRITE_BUFFER_w(1)) or
                           (WRITE_BUFFER_w(2) and WRITE_BUFFER_w(0)) or
                           (WRITE_BUFFER_w(1) and WRITE_BUFFER_w(0));

    corr_l_out_ack_i_w  <= (l_out_ack_i_w(2) and l_out_ack_i_w(1)) or
                           (l_out_ack_i_w(2) and l_out_ack_i_w(0)) or
                           (l_out_ack_i_w(1) and l_out_ack_i_w(0));

    -- Error detection: any mismatch among replicas
    error_WRITE_BUFFER_w <= (WRITE_BUFFER_w(2) xor WRITE_BUFFER_w(1)) or
                            (WRITE_BUFFER_w(2) xor WRITE_BUFFER_w(0)) or
                            (WRITE_BUFFER_w(1) xor WRITE_BUFFER_w(0));

    error_l_out_ack_i_w  <= (l_out_ack_i_w(2) xor l_out_ack_i_w(1)) or
                            (l_out_ack_i_w(2) xor l_out_ack_i_w(0)) or
                            (l_out_ack_i_w(1) xor l_out_ack_i_w(0));

    -- Aggregate error flag
    error_o <= error_WRITE_BUFFER_w or error_l_out_ack_i_w;

    -- Output selection matches control_tmr pattern:
    -- if correction enabled -> majority, else -> replica 0.
    WRITE_BUFFER_o <= corr_WRITE_BUFFER_w when correct_error_i = '1' else WRITE_BUFFER_w(0);
    l_out_ack_i    <= corr_l_out_ack_i_w  when correct_error_i = '1' else l_out_ack_i_w(0);

end rtl;
