library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- Checks manager-side NoC response flits emitted by the subordinate NI.
entity subordinate_noc_traffic_mon_datapath is
  generic(
    p_USE_HAMMING               : boolean := c_ENABLE_SUB_TM_LFSR_HAMMING;
    p_USE_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT;
    p_USE_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_SUB_TM_LFSR_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    is_read_i       : in std_logic;
    expected_id_i   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    seed_i          : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    load_expected_i : in std_logic;
    step_lfsr_i     : in std_logic;
    lfsr_seeded_i   : in std_logic;
    accept_flit_i   : in std_logic;
    flit_idx_i      : in unsigned(2 downto 0);

    l_in_data_i : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    mismatch_o  : out std_logic;

    OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TM_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + 1 + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH + 1, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0')
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_datapath is
  signal mismatch_w         : std_logic_vector(0 downto 0);
  signal mismatch_next_w    : std_logic_vector(0 downto 0);
  signal mismatch_write_en_w: std_logic;

  signal lfsr_state_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_input_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_next_w   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_single_err_w : std_logic;
  signal lfsr_double_err_w : std_logic;
  signal protected_state_w      : std_logic_vector(c_AXI_DATA_WIDTH downto 0);
  signal protected_state_next_w : std_logic_vector(c_AXI_DATA_WIDTH downto 0);
  signal protected_state_we_w   : std_logic;
  signal protected_state_enc_w  : std_logic_vector(c_AXI_DATA_WIDTH + 1 + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH + 1, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal flit_payload_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal payload_valid_w : std_logic;
begin
  lfsr_state_w <= protected_state_w(c_AXI_DATA_WIDTH - 1 downto 0);
  mismatch_w(0) <= protected_state_w(c_AXI_DATA_WIDTH);

  u_packet_deformatter: entity work.subordinate_noc_packet_deformatter
    port map(
      is_read_i => is_read_i,
      flit_idx_i => flit_idx_i,
      flit_i => l_in_data_i,
      payload_data_o => flit_payload_w,
      payload_valid_o => payload_valid_w
    );

  lfsr_input_w <= seed_i when lfsr_seeded_i = '0' else lfsr_state_w;

  u_lfsr: entity work.subordinate_noc_traffic_mon_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      data_i => lfsr_input_w,
      next_o => lfsr_next_w
    );

  mismatch_o <= mismatch_w(0);

  process(mismatch_w, load_expected_i, accept_flit_i, flit_idx_i, flit_payload_w, is_read_i, lfsr_state_w, lfsr_next_w)
    variable mismatch_v : std_logic;
  begin
    mismatch_v := mismatch_w(0);

    if load_expected_i = '1' then
      mismatch_v := '0';
    end if;

    if accept_flit_i = '1' then
      if payload_valid_w = '1' then
        if (flit_payload_w /= lfsr_state_w) and (flit_payload_w /= lfsr_next_w) then
          mismatch_v := '1';
        end if;
      end if;
    end if;

    mismatch_next_w(0) <= mismatch_v;
  end process;

  mismatch_write_en_w <= load_expected_i or accept_flit_i;

  protected_state_we_w <= step_lfsr_i or mismatch_write_en_w;
  protected_state_next_w <= mismatch_next_w(0) & lfsr_next_w when step_lfsr_i = '1' else
                            mismatch_next_w(0) & lfsr_state_w;

  u_lfsr_state_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_DATA_WIDTH + 1,
      HAMMING_ENABLE => p_USE_HAMMING,
      DETECT_DOUBLE  => p_USE_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_AXI_DATA_WIDTH downto 0 => '0'),
      INJECT_ERROR   => p_USE_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_TM_HAM_LFSR_CORRECT_ERROR_i,
      write_en_i   => protected_state_we_w,
      data_i       => protected_state_next_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => lfsr_single_err_w,
      double_err_o => lfsr_double_err_w,
      enc_data_o   => protected_state_enc_w,
      data_o       => protected_state_w
    );

  OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o <= lfsr_single_err_w;
  OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o <= lfsr_double_err_w;
  OBS_SUB_TM_HAM_LFSR_ENC_DATA_o   <= protected_state_enc_w;
end architecture;
