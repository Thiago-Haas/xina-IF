library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- NoC-side loopback/emulator for the subordinate NI.
--
-- This is the subordinate counterpart to the manager NoC loopback: requests
-- enter ni_subordinate_top through its NoC receive side, and responses leave
-- through its NoC injection side. The loopback therefore emulates the manager
-- side of the NoC transaction while the local AXI slave model supplies the
-- subordinate-side core response.
entity subordinate_noc_loopback is
  generic(
    p_DEST_X : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_DEST_Y : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_X  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1')
  );
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    start_i   : in std_logic;
    is_read_i : in std_logic;
    id_i      : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    address_i : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    seed_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    done_o     : out std_logic;
    mismatch_o : out std_logic;

    OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_SUB_TG_LFSR_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + 1 + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH + 1, c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o      : out std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(c_SUB_TM_TRANSACTION_COUNTER_WIDTH, c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    TM_TRANSACTION_COUNT_o                 : out std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    OBS_SUB_NOC_LB_TMR_DONE_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_NOC_LB_TMR_DONE_CTRL_ERROR_o         : out std_logic := '0';

    -- Request stream from the emulated manager/NoC into the subordinate NI.
    noc_req_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    noc_req_val_o  : out std_logic;
    noc_req_ack_i  : in  std_logic;

    -- Response stream from the subordinate NI back to the emulated manager/NoC.
    noc_resp_data_i : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    noc_resp_val_i  : in  std_logic;
    noc_resp_ack_o  : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_loopback is
  signal gen_done_w : std_logic;
  signal mon_done_w : std_logic;
begin
  u_request_gen: entity work.subordinate_noc_traffic_gen_top
    generic map(
      p_DEST_X => p_DEST_X,
      p_DEST_Y => p_DEST_Y,
      p_SRC_X  => p_SRC_X,
      p_SRC_Y  => p_SRC_Y
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      id_i => id_i,
      address_i => address_i,
      seed_i => seed_i,
      done_o => gen_done_w,
      l_out_data_o => noc_req_data_o,
      l_out_val_o  => noc_req_val_o,
      l_out_ack_i  => noc_req_ack_i,
      OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i => OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i,
      OBS_SUB_TG_TMR_CTRL_ERROR_o         => OBS_SUB_TG_TMR_CTRL_ERROR_o,
      OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i => OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i,
      OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o    => OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o,
      OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o    => OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o,
      OBS_SUB_TG_HAM_LFSR_ENC_DATA_o      => OBS_SUB_TG_HAM_LFSR_ENC_DATA_o
    );

  u_response_mon: entity work.subordinate_noc_traffic_mon_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      expected_id_i => id_i,
      seed_i => seed_i,
      done_o => mon_done_w,
      mismatch_o => mismatch_o,
      l_in_data_i => noc_resp_data_i,
      l_in_val_i  => noc_resp_val_i,
      l_in_ack_o  => noc_resp_ack_o,
      OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i => OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i,
      OBS_SUB_TM_TMR_CTRL_ERROR_o         => OBS_SUB_TM_TMR_CTRL_ERROR_o,
      OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i => OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i,
      OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    => OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o,
      OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    => OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o,
      OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      => OBS_SUB_TM_HAM_LFSR_ENC_DATA_o,
      OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i => OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i,
      OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o    => OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o,
      OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o    => OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o,
      OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o      => OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o,
      TM_TRANSACTION_COUNT_o                 => TM_TRANSACTION_COUNT_o
    );

  done_o <= gen_done_w and mon_done_w;
  OBS_SUB_NOC_LB_TMR_DONE_CTRL_ERROR_o <= '0';
end architecture;
