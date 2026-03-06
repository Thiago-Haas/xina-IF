library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_reception_h_interface_reg is
    generic(
        p_USE_HAMMING          : boolean := true;
        p_HAMMING_DETECT_DOUBLE: boolean := c_ENABLE_HAMMING_DOUBLE_DETECT
    );
    port(
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        i_WRITE_EN : in std_logic;
        i_DATA     : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        o_DATA     : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

        i_OBS_HAM_CORRECT_ERROR : in  std_logic := '1';
        o_OBS_HAM_SINGLE_ERR    : out std_logic;
        o_OBS_HAM_DOUBLE_ERR    : out std_logic;
        o_OBS_HAM_ENC_DATA      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0)
    );
end backend_manager_reception_h_interface_reg;

architecture rtl of backend_manager_reception_h_interface_reg is
    signal w_H_INTERFACE_r : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
    signal w_H_INTERFACE_enc : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0) := (others => '0');
    signal w_HAM_SINGLE    : std_logic := '0';
    signal w_HAM_DOUBLE    : std_logic := '0';
begin
    gen_ham : if p_USE_HAMMING generate
        u_H_INTERFACE_HAM: entity work.hamming_register
            generic map(
                DATA_WIDTH     => c_FLIT_WIDTH,
                HAMMING_ENABLE => true,
                DETECT_DOUBLE  => p_HAMMING_DETECT_DOUBLE,
                RESET_VALUE    => (c_FLIT_WIDTH - 1 downto 0 => '0'),
                INJECT_ERROR   => false
            )
            port map(
                correct_en_i => i_OBS_HAM_CORRECT_ERROR,
                write_en_i   => i_WRITE_EN,
                data_i       => i_DATA,
                rstn_i       => ARESETn,
                clk_i        => ACLK,
                single_err_o => w_HAM_SINGLE,
                double_err_o => w_HAM_DOUBLE,
                enc_data_o   => w_H_INTERFACE_enc,
                data_o       => w_H_INTERFACE_r
            );
    end generate;

    gen_no_ham : if not p_USE_HAMMING generate
        process (ACLK)
        begin
            if rising_edge(ACLK) then
                if ARESETn = '0' then
                    w_H_INTERFACE_r <= (others => '0');
                elsif i_WRITE_EN = '1' then
                    w_H_INTERFACE_r <= i_DATA;
                end if;
            end if;
        end process;

        w_HAM_SINGLE <= '0';
        w_HAM_DOUBLE <= '0';
        w_H_INTERFACE_enc <= (w_H_INTERFACE_enc'left downto c_FLIT_WIDTH => '0') & w_H_INTERFACE_r;
    end generate;

    o_DATA <= w_H_INTERFACE_r;
    o_OBS_HAM_SINGLE_ERR <= w_HAM_SINGLE;
    o_OBS_HAM_DOUBLE_ERR <= w_HAM_DOUBLE;
    o_OBS_HAM_ENC_DATA   <= w_H_INTERFACE_enc;
end rtl;
