library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_noc_pkg.all;

entity integrity_control_receive is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Inputs.
        ADD_i      : in std_logic;
        VALUE_ADD_i: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        COMPARE_i      : in std_logic;
        VALUE_COMPARE_i: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Outputs.
        CORRUPT_o : out std_logic
    );
end integrity_control_receive;

architecture rtl of integrity_control_receive is

    signal CHECKSUM_r_w : unsigned(c_AXI_DATA_WIDTH - 1 downto 0) := to_unsigned(0, c_AXI_DATA_WIDTH);

begin
    ---------------------------------------------------------------------------------------------
    -- Sum process.
    process (all)
    begin
        if (ARESETn = '0') then
            CHECKSUM_r_w <= to_unsigned(0, c_AXI_DATA_WIDTH);
        elsif (rising_edge(ACLK)) then
            if (ADD_i = '1') then
                CHECKSUM_r_w <= CHECKSUM_r_w + unsigned(VALUE_ADD_i);
            end if;
        end if;
    end process;

    CORRUPT_o  <= '1' when (CHECKSUM_r_w /= unsigned(VALUE_COMPARE_i) and COMPARE_i = '1') else '0';
end rtl;