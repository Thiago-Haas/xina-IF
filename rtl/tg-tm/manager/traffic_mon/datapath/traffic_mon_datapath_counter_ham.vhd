library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- TM transaction counter with optional Hamming protection.
-- Increment logic is internal to this block.
entity traffic_mon_datapath_counter_ham is
  generic(
    p_TM_TXN_COUNTER_WIDTH         : natural := c_TM_TRANSACTION_COUNTER_WIDTH;
    p_USE_TM_COUNTER_HAMMING       : boolean := c_ENABLE_TM_TXN_COUNTER_HAMMING;
    p_USE_TM_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TM_HAMMING_DOUBLE_DETECT
  );
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    increment_en_i : in std_logic;
    OBS_TM_HAM_COUNTER_CORRECT_ERROR_i : in std_logic := '1';

    TM_TRANSACTION_COUNT_o : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0);
    OBS_TM_HAM_COUNTER_SINGLE_ERR_o : out std_logic;
    OBS_TM_HAM_COUNTER_DOUBLE_ERR_o : out std_logic;
    OBS_TM_HAM_COUNTER_ENC_DATA_o   : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end entity;

architecture rtl of traffic_mon_datapath_counter_ham is
  signal counter_data_r_w  : std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0);
  signal counter_next_w  : std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0);
  signal counter_enc_r_w   : std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal counter_single_err_w : std_logic;
  signal counter_double_err_w : std_logic;
begin
  counter_next_w <= std_logic_vector(unsigned(counter_data_r_w) + 1);

  u_TM_COUNTER_HAM: entity work.hamming_register
    generic map(
      DATA_WIDTH     => p_TM_TXN_COUNTER_WIDTH,
      HAMMING_ENABLE => p_USE_TM_COUNTER_HAMMING,
      DETECT_DOUBLE  => p_USE_TM_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (p_TM_TXN_COUNTER_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => false
    )
    port map(
      correct_en_i => OBS_TM_HAM_COUNTER_CORRECT_ERROR_i,
      write_en_i   => increment_en_i,
      data_i       => counter_next_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => counter_single_err_w,
      double_err_o => counter_double_err_w,
      enc_data_o   => counter_enc_r_w,
      data_o       => counter_data_r_w
    );

  TM_TRANSACTION_COUNT_o <= counter_data_r_w;
  OBS_TM_HAM_COUNTER_SINGLE_ERR_o <= counter_single_err_w;
  OBS_TM_HAM_COUNTER_DOUBLE_ERR_o <= counter_double_err_w;
  OBS_TM_HAM_COUNTER_ENC_DATA_o   <= counter_enc_r_w;
end rtl;
