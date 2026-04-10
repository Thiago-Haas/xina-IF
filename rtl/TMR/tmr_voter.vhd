library IEEE;
use IEEE.std_logic_1164.all;

entity tmr_voter is
    generic(
        p_WIDTH : positive := 1
    );
    port(
        A_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
        B_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
        C_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
        Y_o : out std_logic_vector(p_WIDTH - 1 downto 0);
        E_o : out std_logic_vector(p_WIDTH - 1 downto 0)
    );
end tmr_voter;

architecture rtl of tmr_voter is
begin
    GEN_VOTER:
    for i in 0 to p_WIDTH - 1 generate
    begin
        u_tmr_voter_bit: entity work.tmr_voter_bit
            port map(
                A_i => A_i(i),
                B_i => B_i(i),
                C_i => C_i(i),
                Y_o => Y_o(i),
                E_o => E_o(i)
            );
    end generate;
end rtl;
