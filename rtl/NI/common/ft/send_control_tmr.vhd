library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;

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
    signal corr_bundle_w : std_logic_vector(1 downto 0);

begin

    gen_TMR : for i in 2 downto 0 generate
        attribute DONT_TOUCH of u_send_control : label is "TRUE";
        attribute syn_preserve of u_send_control : label is true;
        attribute KEEP_HIERARCHY of u_send_control : label is "TRUE";
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_send_control : label is "tmr";
        attribute syn_keep         of u_send_control : label is TRUE;
        attribute syn_safe_case    of u_send_control : label is TRUE;
        attribute syn_noprune      of u_send_control : label is TRUE;
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

    u_send_control_tmr_voter: entity work.tmr_voter_block
        generic map(
            p_WIDTH => 2
        )
        port map(
            A_i => READ_BUFFER_w(0) & l_in_val_i_w(0),
            B_i => READ_BUFFER_w(1) & l_in_val_i_w(1),
            C_i => READ_BUFFER_w(2) & l_in_val_i_w(2),
            correct_enable_i => correct_error_i,
            corrected_o => corr_bundle_w,
            error_bits_o => open,
            error_o => error_o
        );

    READ_BUFFER_o <= corr_bundle_w(1);
    l_in_val_i    <= corr_bundle_w(0);
end rtl;
