library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;
use work.xina_ni_ft_pkg.all;

entity integrity_control_send_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Inputs.
        i_ADD      : in std_logic;
        i_VALUE_ADD: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Outputs.
        o_CHECKSUM: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end integrity_control_send_tmr;

architecture rtl of integrity_control_send_tmr is
    type t_TMR_CHECKSUM is array (2 downto 0) of std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    signal w_CHECKSUM : t_TMR_CHECKSUM;

    signal corr_CHECKSUM_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal error_bits_w    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

begin

    gen_TMR : for i in 2 downto 0 generate
        -- Xilinx attributes to prevent optimization of TMR
        attribute DONT_TOUCH : string;
        attribute DONT_TOUCH of u_INTEGRITY_CONTROL_SEND : label is "TRUE";
        -- Synplify attributes to prevent optimization of TMR
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_INTEGRITY_CONTROL_SEND : label is "tmr";
        attribute syn_keep         of u_INTEGRITY_CONTROL_SEND : label is TRUE;
        attribute syn_safe_case    of u_INTEGRITY_CONTROL_SEND : label is TRUE;
        attribute syn_noprune      of u_INTEGRITY_CONTROL_SEND : label is TRUE;
    begin
        u_INTEGRITY_CONTROL_SEND: entity work.integrity_control_send
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_ADD       => i_ADD,
                i_VALUE_ADD => i_VALUE_ADD,

                o_CHECKSUM => w_CHECKSUM(i)
            );
    end generate;

    -- Majority vote (corrected output) and error detection bit-by-bit
    gen_VOTE : for b in c_AXI_DATA_WIDTH - 1 downto 0 generate
        corr_CHECKSUM_w(b) <= (w_CHECKSUM(2)(b) and w_CHECKSUM(1)(b)) or
                              (w_CHECKSUM(2)(b) and w_CHECKSUM(0)(b)) or
                              (w_CHECKSUM(1)(b) and w_CHECKSUM(0)(b));

        error_bits_w(b) <= (w_CHECKSUM(2)(b) xor w_CHECKSUM(1)(b)) or
                           (w_CHECKSUM(2)(b) xor w_CHECKSUM(0)(b)) or
                           (w_CHECKSUM(1)(b) xor w_CHECKSUM(0)(b));
    end generate;

    -- any mismatch among replicas on any bit
    error_o <= or_reduce(error_bits_w);

    -- Output selection matches control_tmr pattern:
    -- if correction enabled -> majority, else -> replica 0.
    o_CHECKSUM <= corr_CHECKSUM_w when correct_error_i = '1' else w_CHECKSUM(0);

end rtl;
