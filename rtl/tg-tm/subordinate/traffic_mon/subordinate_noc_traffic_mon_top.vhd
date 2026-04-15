library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- NoC-side response monitor for ni_subordinate_top.
-- Thin wrapper around a response-packet FSM, datapath, and LFSR, following the
-- same structural split as the manager TM.
entity subordinate_noc_traffic_mon_top is
  generic(
    p_USE_TMR_CTRL : boolean := c_ENABLE_SUB_TM_CTRL_TMR;
    p_USE_HAMMING               : boolean := c_ENABLE_SUB_TM_LFSR_HAMMING;
    p_USE_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT;
    p_USE_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_SUB_TM_LFSR_HAMMING_INJECT_ERROR;
    p_USE_TXN_COUNTER_HAMMING   : boolean := c_ENABLE_SUB_TM_TXN_COUNTER_HAMMING;
    p_TM_TXN_COUNTER_WIDTH      : natural := c_SUB_TM_TRANSACTION_COUNTER_WIDTH
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i    : in  std_logic;
    is_read_i  : in  std_logic;
    expected_id_i : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    seed_i        : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    done_pulse_o : out std_logic;
    done_o     : out std_logic;
    mismatch_o : out std_logic;

    l_in_data_i : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_in_val_i  : in  std_logic;
    l_in_ack_o  : out std_logic;

    OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + 1 + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH + 1, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o      : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    TM_TRANSACTION_COUNT_o                 : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_top is
  signal load_expected_w : std_logic;
  signal step_lfsr_w     : std_logic;
  signal lfsr_seeded_w   : std_logic;
  signal accept_flit_w   : std_logic;
  signal flit_idx_w      : unsigned(2 downto 0);
  signal is_read_w       : std_logic;
begin
  gen_control_plain : if not p_USE_TMR_CTRL generate
    u_control: entity work.subordinate_noc_traffic_mon_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        start_i => start_i,
        is_read_i => is_read_i,
        done_pulse_o => done_pulse_o,
        done_o => done_o,
        l_in_val_i => l_in_val_i,
        l_in_ack_o => l_in_ack_o,
        load_expected_o => load_expected_w,
        step_lfsr_o => step_lfsr_w,
        lfsr_seeded_o => lfsr_seeded_w,
        accept_flit_o => accept_flit_w,
        flit_idx_o => flit_idx_w,
        is_read_o => is_read_w
      );

    OBS_SUB_TM_TMR_CTRL_ERROR_o <= '0';
  end generate;

  gen_control_tmr : if p_USE_TMR_CTRL generate
    u_control_tmr: entity work.subordinate_noc_traffic_mon_control_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        start_i => start_i,
        is_read_i => is_read_i,
        done_pulse_o => done_pulse_o,
        done_o => done_o,
        l_in_val_i => l_in_val_i,
        l_in_ack_o => l_in_ack_o,
        load_expected_o => load_expected_w,
        step_lfsr_o => step_lfsr_w,
        lfsr_seeded_o => lfsr_seeded_w,
        accept_flit_o => accept_flit_w,
        flit_idx_o => flit_idx_w,
        is_read_o => is_read_w,
        correct_enable_i => OBS_SUB_TM_TMR_CTRL_CORRECT_ERROR_i,
        error_o => OBS_SUB_TM_TMR_CTRL_ERROR_o
      );
  end generate;

  u_datapath: entity work.subordinate_noc_traffic_mon_datapath
    generic map(
      p_USE_HAMMING => p_USE_HAMMING,
      p_USE_HAMMING_DOUBLE_DETECT => p_USE_HAMMING_DOUBLE_DETECT,
      p_USE_HAMMING_INJECT_ERROR => p_USE_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      is_read_i => is_read_w,
      expected_id_i => expected_id_i,
      seed_i => seed_i,
      load_expected_i => load_expected_w,
      step_lfsr_i => step_lfsr_w,
      lfsr_seeded_i => lfsr_seeded_w,
      accept_flit_i => accept_flit_w,
      flit_idx_i => flit_idx_w,
      l_in_data_i => l_in_data_i,
      mismatch_o => mismatch_o,
      OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i => OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i,
      OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    => OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o,
      OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    => OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o,
      OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      => OBS_SUB_TM_HAM_LFSR_ENC_DATA_o
    );

  u_counter: entity work.subordinate_noc_traffic_mon_counter_ham
    generic map(
      p_TM_TXN_COUNTER_WIDTH => p_TM_TXN_COUNTER_WIDTH,
      p_USE_TM_COUNTER_HAMMING => p_USE_TXN_COUNTER_HAMMING,
      p_USE_TM_HAMMING_DOUBLE_DETECT => p_USE_HAMMING_DOUBLE_DETECT
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      increment_en_i => done_pulse_o,
      OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i => OBS_SUB_TM_HAM_COUNTER_CORRECT_ERROR_i,
      TM_TRANSACTION_COUNT_o => TM_TRANSACTION_COUNT_o,
      OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o => OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o,
      OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o => OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o,
      OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o   => OBS_SUB_TM_HAM_COUNTER_ENC_DATA_o
    );
end architecture;
