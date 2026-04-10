library IEEE;
use IEEE.std_logic_1164.all;

entity tmr_voter_bit is
    port(
        A_i : in  std_logic;
        B_i : in  std_logic;
        C_i : in  std_logic;
        Y_o : out std_logic;
        E_o : out std_logic
    );
end tmr_voter_bit;

architecture rtl of tmr_voter_bit is
    signal ab_and_w : std_logic;
    signal ac_and_w : std_logic;
    signal bc_and_w : std_logic;
    signal ab_xor_w : std_logic;
    signal ac_xor_w : std_logic;
    signal bc_xor_w : std_logic;
begin
    ab_and_w <= A_i and B_i;
    ac_and_w <= A_i and C_i;
    bc_and_w <= B_i and C_i;

    ab_xor_w <= A_i xor B_i;
    ac_xor_w <= A_i xor C_i;
    bc_xor_w <= B_i xor C_i;

    Y_o <= ab_and_w or
           ac_and_w or
           bc_and_w;

    E_o <= ab_xor_w or
           ac_xor_w or
           bc_xor_w;
end rtl;
