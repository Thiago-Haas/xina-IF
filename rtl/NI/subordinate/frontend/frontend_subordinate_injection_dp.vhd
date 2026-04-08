library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity frontend_subordinate_injection_dp is
    generic(
        p_USE_STATUS_TMR : boolean := c_ENABLE_SUB_FE_INJ_STATUS_TMR
    );
    port(
        ACLK    : in std_logic;
        ARESETn : in std_logic;

        VALID_SEND_DATA_i : in std_logic;
        BVALID_i          : in std_logic;
        BRESP_i           : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        RVALID_i          : in std_logic;
        RRESP_i           : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
        RDATA_i           : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        STATUS_TMR_CORRECT_ERROR_i : in  std_logic := '1';
        STATUS_TMR_ERROR_o         : out std_logic := '0';

        DATA_SEND_o   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
        STATUS_SEND_o : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0)
    );
end frontend_subordinate_injection_dp;

architecture rtl of frontend_subordinate_injection_dp is
    signal status_write_w : std_logic;
    signal status_in_w    : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
begin
    status_write_w <= '1' when (VALID_SEND_DATA_i = '1' and (BVALID_i = '1' or RVALID_i = '1')) else '0';
    status_in_w <= BRESP_i when BVALID_i = '1' else
                   RRESP_i;

    u_response_status_register: entity work.small_tmr_register
        generic map(
            p_WIDTH => c_AXI_RESP_WIDTH,
            p_USE_TMR => p_USE_STATUS_TMR
        )
        port map(
            ACLK => ACLK,
            ARESETn => ARESETn,
            write_en_i => status_write_w,
            data_i => status_in_w,
            correct_enable_i => STATUS_TMR_CORRECT_ERROR_i,
            data_o => STATUS_SEND_o,
            error_o => STATUS_TMR_ERROR_o
        );

    DATA_SEND_o <= RDATA_i when (RVALID_i = '1') else (others => '0');
end rtl;
