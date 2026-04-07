library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_noc_pkg.all;

entity integrity_control_send_hamming is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Inputs.
        ADD_i      : in std_logic;
        VALUE_ADD_i: in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Outputs.
        CHECKSUM_o: out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic;

        OBS_HAM_INTEGRITY_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_HAM_INTEGRITY_SINGLE_ERR_o    : out std_logic;
        OBS_HAM_INTEGRITY_DOUBLE_ERR_o    : out std_logic;
        OBS_HAM_INTEGRITY_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0)
    );
end integrity_control_send_hamming;

architecture rtl of integrity_control_send_hamming is
    signal CHECKSUM_ham_r_w    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal CHECKSUM_ham_next_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    signal HAM_SINGLE_ERR_w    : std_logic;
    signal HAM_DOUBLE_ERR_w    : std_logic;
    signal CHECKSUM_ham_enc_w  : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

begin
    CHECKSUM_ham_next_w <= std_logic_vector(unsigned(CHECKSUM_ham_r_w) + unsigned(VALUE_ADD_i));

    u_checksum_hamming_register: entity work.hamming_register
        generic map(
            DATA_WIDTH     => c_AXI_DATA_WIDTH,
            HAMMING_ENABLE => true,
            DETECT_DOUBLE  => c_ENABLE_HAMMING_DOUBLE_DETECT,
            RESET_VALUE    => (c_AXI_DATA_WIDTH - 1 downto 0 => '0'),
            INJECT_ERROR   => false
        )
        port map(
            correct_en_i => OBS_HAM_INTEGRITY_CORRECT_ERROR_i,
            write_en_i   => ADD_i,
            data_i       => CHECKSUM_ham_next_w,
            rstn_i       => ARESETn,
            clk_i        => ACLK,
            single_err_o => HAM_SINGLE_ERR_w,
            double_err_o => HAM_DOUBLE_ERR_w,
            enc_data_o   => CHECKSUM_ham_enc_w,
            data_o       => CHECKSUM_ham_r_w
        );

    CHECKSUM_o <= CHECKSUM_ham_r_w;
    -- TMR mode removed for this block; keep legacy ports stable.
    error_o <= '0';
    OBS_HAM_INTEGRITY_SINGLE_ERR_o <= HAM_SINGLE_ERR_w;
    OBS_HAM_INTEGRITY_DOUBLE_ERR_o <= HAM_DOUBLE_ERR_w;
    OBS_HAM_INTEGRITY_ENC_DATA_o   <= CHECKSUM_ham_enc_w;

end rtl;
