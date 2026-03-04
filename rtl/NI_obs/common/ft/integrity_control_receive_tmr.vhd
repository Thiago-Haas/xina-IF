library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

entity integrity_control_receive_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Inputs.
        i_ADD      : in std_logic;
        i_VALUE_ADD: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        i_COMPARE      : in std_logic;
        i_VALUE_COMPARE: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Outputs.
        o_CORRUPT: out std_logic;

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end integrity_control_receive_tmr;

architecture rtl of integrity_control_receive_tmr is
    type t_BIT_VECTOR is array (2 downto 0) of std_logic;

    signal w_CORRUPT: t_BIT_VECTOR;
    signal corr_CORRUPT_w  : std_logic;
    signal error_CORRUPT_w : std_logic;

begin

    gen_TMR : for i in 2 downto 0 generate
        -- Xilinx attributes to prevent optimization of TMR
        attribute DONT_TOUCH : string;
        attribute DONT_TOUCH of u_INTEGRITY_CONTROL_RECEIVE : label is "TRUE";
        -- Synplify attributes to prevent optimization of TMR
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_INTEGRITY_CONTROL_RECEIVE : label is "tmr";
        attribute syn_keep         of u_INTEGRITY_CONTROL_RECEIVE : label is TRUE;
        attribute syn_safe_case    of u_INTEGRITY_CONTROL_RECEIVE : label is TRUE;
        attribute syn_noprune      of u_INTEGRITY_CONTROL_RECEIVE : label is TRUE;
    begin
        u_INTEGRITY_CONTROL_RECEIVE: entity work.integrity_control_receive
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                i_ADD           => i_ADD,
                i_VALUE_ADD     => i_VALUE_ADD,
                i_COMPARE       => i_COMPARE,
                i_VALUE_COMPARE => i_VALUE_COMPARE,

                o_CORRUPT       => w_CORRUPT(i)
            );
    end generate;

    -- Majority vote (corrected output)
    corr_CORRUPT_w <= (w_CORRUPT(2) and w_CORRUPT(1)) or
                      (w_CORRUPT(2) and w_CORRUPT(0)) or
                      (w_CORRUPT(1) and w_CORRUPT(0));

    -- Error detection: any mismatch among replicas
    error_CORRUPT_w <= (w_CORRUPT(2) xor w_CORRUPT(1)) or
                       (w_CORRUPT(2) xor w_CORRUPT(0)) or
                       (w_CORRUPT(1) xor w_CORRUPT(0));

    error_o   <= error_CORRUPT_w;
    o_CORRUPT <= corr_CORRUPT_w when correct_error_i = '1' else w_CORRUPT(0);
end rtl;
