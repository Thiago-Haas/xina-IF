library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.tcc_package.all;
use work.xina_pkg.all;

entity integrity_control_send is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Inputs.
        i_ADD      : in std_logic;
        i_VALUE_ADD: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Outputs.
        o_CHECKSUM: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
    );
end integrity_control_send;

architecture rtl of integrity_control_send is
    
    signal w_CHECKSUM_r : unsigned(c_AXI_DATA_WIDTH - 1 downto 0) := to_unsigned(0, c_AXI_DATA_WIDTH);

begin
    ---------------------------------------------------------------------------------------------
    -- Sum process.
    process (all)
    begin
        if (ARESETn = '0') then
            w_CHECKSUM_r <= to_unsigned(0, c_AXI_DATA_WIDTH);
        elsif (rising_edge(ACLK)) then
            if (i_ADD = '1') then
                w_CHECKSUM_r <= w_CHECKSUM_r + unsigned(i_VALUE_ADD);
            end if;
        end if;
    end process;

    o_CHECKSUM <= std_logic_vector(w_CHECKSUM_r);
end rtl;