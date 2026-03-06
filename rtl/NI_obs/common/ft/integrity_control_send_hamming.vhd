library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

entity integrity_control_send_hamming is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Inputs.
        i_ADD      : in std_logic;
        i_VALUE_ADD: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Outputs.
        o_CHECKSUM: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic;

        i_OBS_HAM_INTEGRITY_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_HAM_INTEGRITY_SINGLE_ERR    : out std_logic;
        o_OBS_HAM_INTEGRITY_DOUBLE_ERR    : out std_logic
    );
end integrity_control_send_hamming;

architecture rtl of integrity_control_send_hamming is
    signal w_CHECKSUM_ham_q    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal w_CHECKSUM_ham_next : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal w_HAM_SINGLE_ERR    : std_logic;
    signal w_HAM_DOUBLE_ERR    : std_logic;

begin
    w_CHECKSUM_ham_next <= std_logic_vector(unsigned(w_CHECKSUM_ham_q) + unsigned(i_VALUE_ADD));

    u_CHECKSUM_HAM_REG: entity work.hamming_register
        generic map(
            DATA_WIDTH     => c_AXI_DATA_WIDTH,
            HAMMING_ENABLE => true,
            DETECT_DOUBLE  => c_ENABLE_HAMMING_DOUBLE_DETECT,
            RESET_VALUE    => (c_AXI_DATA_WIDTH - 1 downto 0 => '0'),
            INJECT_ERROR   => false
        )
        port map(
            correct_en_i => i_OBS_HAM_INTEGRITY_CORRECT_ERROR,
            write_en_i   => i_ADD,
            data_i       => w_CHECKSUM_ham_next,
            rstn_i       => ARESETn,
            clk_i        => ACLK,
            single_err_o => w_HAM_SINGLE_ERR,
            double_err_o => w_HAM_DOUBLE_ERR,
            enc_data_o   => open,
            data_o       => w_CHECKSUM_ham_q
        );

    o_CHECKSUM <= w_CHECKSUM_ham_q;
    -- TMR mode removed for this block; keep legacy ports stable.
    error_o <= '0';
    o_OBS_HAM_INTEGRITY_SINGLE_ERR <= w_HAM_SINGLE_ERR;
    o_OBS_HAM_INTEGRITY_DOUBLE_ERR <= w_HAM_DOUBLE_ERR;

end rtl;
