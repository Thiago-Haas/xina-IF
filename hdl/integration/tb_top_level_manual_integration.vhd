library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity tb_top_level_manual_integration is
--  Port ( );
end tb_top_level_manual_integration;

architecture Behavioral of tb_top_level_manual_integration is
signal tb_ACLK    : std_logic := '0';
signal tb_RESET   : std_logic := '0';
signal tb_RESETn  : std_logic := '1';
signal tb_ARESETn : std_logic := '1';

begin
u_top_level_manual_integration: entity work.top_level_manual_integration
    port map(
        -- AMBA-AXI 5 signals.
        ACLK    => tb_ACLK,
        RESET   => tb_RESET,
        ARESETn => tb_ARESETn
    );
    
    ---------------------------------------------------------------------------------------------
    -- Clock.
    process
    begin
        wait for 50 ns;
        tb_ACLK <= not tb_ACLK;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Reset.
    process
    begin
        tb_RESET <= '0';
        wait;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Tests.
    process
    begin
        -- Reset slave.
        tb_ARESETn <= '0';
        wait for 100 ns;
        tb_ARESETn <= '1';
        wait;
    end process;

end Behavioral;


