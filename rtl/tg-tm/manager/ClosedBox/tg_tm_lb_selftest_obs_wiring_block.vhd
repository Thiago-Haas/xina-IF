library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_ni_ft_pkg.all;

-- OBS wiring concentrator for closed-box self-test observation block.
-- It groups all OBS inputs and drives OBS correction enables.
entity tg_tm_lb_selftest_obs_wiring_block is
  port (
    -- Additional TM observability signals
    i_TM_TRANSACTION_COUNT : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    i_TM_EXPECTED_VALUE    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    i_NI_CORRUPT_PACKET    : in std_logic;

    -- OBS enables (to DUT)
    o_OBS_TM_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_TM_TMR_CTRL_CORRECT_ERROR   : out std_logic;
    o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR : out std_logic;

    o_OBS_LB_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_LB_TMR_CTRL_CORRECT_ERROR   : out std_logic;

    o_OBS_TG_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_TG_TMR_CTRL_CORRECT_ERROR   : out std_logic;

    o_OBS_FE_INJ_META_HDR_CORRECT_ERROR : out std_logic;
    o_OBS_FE_INJ_ADDR_CORRECT_ERROR     : out std_logic;

    o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR : out std_logic;

    o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR : out std_logic;
    o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR : out std_logic;

    -- OBS outputs (from DUT)
    i_OBS_TM_TMR_CTRL_ERROR : in std_logic;
    i_OBS_TM_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_TM_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_TM_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR : in std_logic;
    i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR : in std_logic;
    i_OBS_TM_HAM_TXN_COUNTER_ENC_DATA : in std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_LB_TMR_CTRL_ERROR : in std_logic;
    i_OBS_LB_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_LB_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_LB_HAM_BUFFER_ENC_DATA : in std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, c_ENABLE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_TG_TMR_CTRL_ERROR : in std_logic;
    i_OBS_TG_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_TG_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_TG_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_FE_INJ_META_HDR_SINGLE_ERR : in std_logic;
    i_OBS_FE_INJ_META_HDR_DOUBLE_ERR : in std_logic;
    i_OBS_FE_INJ_ADDR_SINGLE_ERR : in std_logic;
    i_OBS_FE_INJ_ADDR_DOUBLE_ERR : in std_logic;
    i_OBS_FE_INJ_HAM_META_HDR_ENC_DATA : in std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_FE_INJ_HAM_ADDR_ENC_DATA : in std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR : in std_logic;
    i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR : in std_logic;
    i_OBS_BE_INJ_HAM_INTEGRITY_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR : in std_logic;
    i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR : in std_logic;

    i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_BUFFER_ENC_DATA : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR : in std_logic;
    i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTERFACE_HDR_ENC_DATA : in std_logic_vector(c_FLIT_WIDTH + work.hamming_pkg.get_ecc_size(c_FLIT_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_RX_INTEGRITY_CORRUPT : in std_logic;
    i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR : in std_logic;
    i_OBS_BE_RX_HAM_INTEGRITY_ENC_DATA : in std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR : in std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_wiring_block is
begin
  -- All observation enables default ON in self-test mode.
  o_OBS_TM_HAM_BUFFER_CORRECT_ERROR <= '1';
  o_OBS_TM_TMR_CTRL_CORRECT_ERROR <= '1';
  o_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR <= '1';

  o_OBS_LB_HAM_BUFFER_CORRECT_ERROR <= '1';
  o_OBS_LB_TMR_CTRL_CORRECT_ERROR <= '1';

  o_OBS_TG_HAM_BUFFER_CORRECT_ERROR <= '1';
  o_OBS_TG_TMR_CTRL_CORRECT_ERROR <= '1';

  o_OBS_FE_INJ_META_HDR_CORRECT_ERROR <= '1';
  o_OBS_FE_INJ_ADDR_CORRECT_ERROR <= '1';

  o_OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR <= '1';
  o_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR <= '1';
  o_OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR <= '1';
  o_OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR <= '1';
  o_OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR <= '1';

  o_OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR <= '1';
  o_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR <= '1';
  o_OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR <= '1';
  o_OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR <= '1';
  o_OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR <= '1';
end architecture;
