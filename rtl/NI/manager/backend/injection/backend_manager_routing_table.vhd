library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

entity backend_manager_routing_table is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        ADDR_i : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);

        OPC_ADDR_o: out std_logic_vector((c_AXI_ADDR_WIDTH / 2) - 1 downto 0);
        DEST_X_o  : out std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
        DEST_Y_o  : out std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0)
    );
end backend_manager_routing_table;

architecture rtl of backend_manager_routing_table is
begin
    OPC_ADDR_o <= ADDR_i((c_AXI_ADDR_WIDTH - 1) downto c_AXI_ADDR_WIDTH / 2);
    DEST_X_o   <= ADDR_i((c_AXI_ADDR_WIDTH / 2) - 1 downto c_AXI_ADDR_WIDTH / 4);
    DEST_Y_o   <= ADDR_i((c_AXI_ADDR_WIDTH / 4) - 1 downto 0);
end rtl;