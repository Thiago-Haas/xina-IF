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
        i_WRITE_OK_BUFFER: in std_logic;
        o_WRITE_BUFFER   : out std_logic;

        -- XINA signals.
        l_out_val_o: in std_logic;
        l_out_ack_i: out std_logic;

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end receive_control_tmr;

architecture rtl of receive_control_tmr is
    type t_BIT_VECTOR is array (2 downto 0) of std_logic;

    signal w_WRITE_BUFFER : t_BIT_VECTOR;
    signal w_l_out_ack_i  : t_BIT_VECTOR;

    signal corr_WRITE_BUFFER_w : std_logic;
    signal corr_l_out_ack_i_w  : std_logic;

    signal error_WRITE_BUFFER_w : std_logic;
    signal error_l_out_ack_i_w  : std_logic;

begin

    gen_TMR : for i in 2 downto 0 generate
        -- Xilinx attributes to prevent optimization of TMR
        attribute DONT_TOUCH : string;
        attribute DONT_TOUCH of u_RECEIVE_CONTROL : label is "TRUE";
        -- Synplify attributes to prevent optimization of TMR
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_RECEIVE_CONTROL : label is "tmr";
        attribute syn_keep         of u_RECEIVE_CONTROL : label is TRUE;
        attribute syn_safe_case    of u_RECEIVE_CONTROL : label is TRUE;
        attribute syn_noprune      of u_RECEIVE_CONTROL : label is TRUE;
    begin
        u_RECEIVE_CONTROL: entity work.receive_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_WRITE_OK_BUFFER => i_WRITE_OK_BUFFER,
                o_WRITE_BUFFER    => w_WRITE_BUFFER(i),

                l_out_val_o => l_out_val_o,
                l_out_ack_i => w_l_out_ack_i(i)
            );
    end generate;

    -- Majority vote (corrected outputs)
    corr_WRITE_BUFFER_w <= (w_WRITE_BUFFER(2) and w_WRITE_BUFFER(1)) or
                           (w_WRITE_BUFFER(2) and w_WRITE_BUFFER(0)) or
                           (w_WRITE_BUFFER(1) and w_WRITE_BUFFER(0));

    corr_l_out_ack_i_w  <= (w_l_out_ack_i(2) and w_l_out_ack_i(1)) or
                           (w_l_out_ack_i(2) and w_l_out_ack_i(0)) or
                           (w_l_out_ack_i(1) and w_l_out_ack_i(0));

    -- Error detection: any mismatch among replicas
    error_WRITE_BUFFER_w <= (w_WRITE_BUFFER(2) xor w_WRITE_BUFFER(1)) or
                            (w_WRITE_BUFFER(2) xor w_WRITE_BUFFER(0)) or
                            (w_WRITE_BUFFER(1) xor w_WRITE_BUFFER(0));

    error_l_out_ack_i_w  <= (w_l_out_ack_i(2) xor w_l_out_ack_i(1)) or
                            (w_l_out_ack_i(2) xor w_l_out_ack_i(0)) or
                            (w_l_out_ack_i(1) xor w_l_out_ack_i(0));

    -- Aggregate error flag
    error_o <= error_WRITE_BUFFER_w or error_l_out_ack_i_w;

    -- Output selection matches control_tmr pattern:
    -- if correction enabled -> majority, else -> replica 0.
    o_WRITE_BUFFER <= corr_WRITE_BUFFER_w when correct_error_i = '1' else w_WRITE_BUFFER(0);
    l_out_ack_i    <= corr_l_out_ack_i_w  when correct_error_i = '1' else w_l_out_ack_i(0);

end rtl;
