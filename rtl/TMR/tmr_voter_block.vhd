library IEEE;
use IEEE.std_logic_1164.all;

entity tmr_voter_block is
    generic(
        p_WIDTH : positive := 1
    );
    port(
        A_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
        B_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
        C_i : in  std_logic_vector(p_WIDTH - 1 downto 0);
        correct_enable_i : in  std_logic := '1';

        corrected_o  : out std_logic_vector(p_WIDTH - 1 downto 0);
        error_bits_o : out std_logic_vector(p_WIDTH - 1 downto 0);
        error_o      : out std_logic := '0'
    );
end tmr_voter_block;

architecture rtl of tmr_voter_block is
    signal voted_w      : std_logic_vector(p_WIDTH - 1 downto 0);
    signal error_bits_w : std_logic_vector(p_WIDTH - 1 downto 0);
begin
    u_tmr_voter: entity work.tmr_voter
        generic map(
            p_WIDTH => p_WIDTH
        )
        port map(
            A_i => A_i,
            B_i => B_i,
            C_i => C_i,
            Y_o => voted_w,
            E_o => error_bits_w
        );

    corrected_o <= voted_w when correct_enable_i = '1' else A_i;
    error_bits_o <= error_bits_w;
    error_o <= '1' when error_bits_w /= (error_bits_w'range => '0') else '0';
end rtl;
