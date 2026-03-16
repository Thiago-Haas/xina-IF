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

        WRITE_EN_i : in std_logic;
        DATA_i     : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        DATA_o     : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

        OBS_HAM_CORRECT_ERROR_i : in  std_logic := '1';
        OBS_HAM_SINGLE_ERR_o    : out std_logic;
        OBS_HAM_DOUBLE_ERR_o    : out std_logic;
        OBS_HAM_ENC_DATA_o      : out std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0)
    );
end backend_manager_reception_h_interface_reg;

architecture rtl of backend_manager_reception_h_interface_reg is
    signal H_INTERFACE_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
    signal H_INTERFACE_enc_w : std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0) := (others => '0');
    signal HAM_SINGLE_w    : std_logic := '0';
    signal HAM_DOUBLE_w    : std_logic := '0';

  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of H_INTERFACE_w : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of H_INTERFACE_w : signal is true;
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
                correct_en_i => OBS_HAM_CORRECT_ERROR_i,
                write_en_i   => WRITE_EN_i,
                data_i       => DATA_i,
                rstn_i       => ARESETn,
                clk_i        => ACLK,
                single_err_o => HAM_SINGLE_w,
                double_err_o => HAM_DOUBLE_w,
                enc_data_o   => H_INTERFACE_enc_w,
                data_o       => H_INTERFACE_w
            );
    end generate;

    gen_no_ham : if not p_USE_HAMMING generate
        process (ACLK)
        begin
            if rising_edge(ACLK) then
                if ARESETn = '0' then
                    H_INTERFACE_w <= (others => '0');
                elsif WRITE_EN_i = '1' then
                    H_INTERFACE_w <= DATA_i;
                end if;
            end if;
        end process;

        HAM_SINGLE_w <= '0';
        HAM_DOUBLE_w <= '0';
        H_INTERFACE_enc_w <= (H_INTERFACE_enc_w'left downto c_FLIT_WIDTH => '0') & H_INTERFACE_w;
    end generate;

    DATA_o <= H_INTERFACE_w;
    OBS_HAM_SINGLE_ERR_o <= HAM_SINGLE_w;
    OBS_HAM_DOUBLE_ERR_o <= HAM_DOUBLE_w;
    OBS_HAM_ENC_DATA_o   <= H_INTERFACE_enc_w;
end rtl;
