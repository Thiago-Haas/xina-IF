library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity frontend_subordinate_injection_dp is
    port(
        ACLK    : in std_logic;
        ARESETn : in std_logic;

        VALID_SEND_DATA_i : in std_logic;
        BVALID_i          : in std_logic;
        BRESP_i           : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        RVALID_i          : in std_logic;
        RRESP_i           : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        RDATA_i           : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        DATA_SEND_o   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        STATUS_SEND_o : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0)
    );
end frontend_subordinate_injection_dp;

architecture rtl of frontend_subordinate_injection_dp is
    signal status_send_r : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of status_send_r : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of status_send_r : signal is true;
begin
    process(ACLK)
    begin
        if rising_edge(ACLK) then
            if VALID_SEND_DATA_i = '1' then
                if BVALID_i = '1' then
                    status_send_r <= BRESP_i;
                elsif RVALID_i = '1' then
                    status_send_r <= RRESP_i;
                end if;
            end if;
        end if;
    end process;

    STATUS_SEND_o <= status_send_r;
    DATA_SEND_o   <= RDATA_i when (RVALID_i = '1') else (others => '0');
end rtl;
