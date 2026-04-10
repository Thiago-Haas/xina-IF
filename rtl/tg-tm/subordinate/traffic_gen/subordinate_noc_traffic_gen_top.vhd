library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- NoC-side traffic generator for ni_subordinate_top.
-- Thin wrapper around a request-packet FSM, datapath, and LFSR, following the
-- same structural split as the manager TG.
entity subordinate_noc_traffic_gen_top is
  generic(
    p_DEST_X : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_DEST_Y : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_X  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1');
    p_USE_TMR_CTRL : boolean := c_ENABLE_SUB_TG_CTRL_TMR;
    p_USE_HAMMING               : boolean := c_ENABLE_SUB_TG_LFSR_HAMMING;
    p_USE_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_SUB_TG_LFSR_HAMMING_DOUBLE_DETECT;
    p_USE_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_SUB_TG_LFSR_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i    : in  std_logic;
    is_read_i  : in  std_logic;
    id_i       : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    address_i  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    seed_i     : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    done_o     : out std_logic;

    l_out_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_out_val_o  : out std_logic;
    l_out_ack_i  : in  std_logic;

    OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0')
  );
end entity;

architecture rtl of subordinate_noc_traffic_gen_top is
  signal step_lfsr_w    : std_logic;
  signal lfsr_seeded_w  : std_logic;
  signal flit_idx_w     : unsigned(2 downto 0);
begin
  gen_control_plain : if not p_USE_TMR_CTRL generate
    u_control: entity work.subordinate_noc_traffic_gen_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        start_i => start_i,
        is_read_i => is_read_i,
        done_o => done_o,
        l_out_ack_i => l_out_ack_i,
        l_out_val_o => l_out_val_o,
        step_lfsr_o => step_lfsr_w,
        lfsr_seeded_o => lfsr_seeded_w,
        flit_idx_o => flit_idx_w
      );

    OBS_SUB_TG_TMR_CTRL_ERROR_o <= '0';
  end generate;

  gen_control_tmr : if p_USE_TMR_CTRL generate
    u_control_tmr: entity work.subordinate_noc_traffic_gen_control_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        start_i => start_i,
        is_read_i => is_read_i,
        done_o => done_o,
        l_out_ack_i => l_out_ack_i,
        l_out_val_o => l_out_val_o,
        step_lfsr_o => step_lfsr_w,
        lfsr_seeded_o => lfsr_seeded_w,
        flit_idx_o => flit_idx_w,
        correct_enable_i => OBS_SUB_TG_TMR_CTRL_CORRECT_ERROR_i,
        error_o => OBS_SUB_TG_TMR_CTRL_ERROR_o
      );
  end generate;

  u_datapath: entity work.subordinate_noc_traffic_gen_datapath
    generic map(
      p_DEST_X => p_DEST_X,
      p_DEST_Y => p_DEST_Y,
      p_SRC_X  => p_SRC_X,
      p_SRC_Y  => p_SRC_Y,
      p_USE_HAMMING => p_USE_HAMMING,
      p_USE_HAMMING_DOUBLE_DETECT => p_USE_HAMMING_DOUBLE_DETECT,
      p_USE_HAMMING_INJECT_ERROR => p_USE_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      is_read_i => is_read_i,
      id_i => id_i,
      address_i => address_i,
      seed_i => seed_i,
      step_lfsr_i => step_lfsr_w,
      lfsr_seeded_i => lfsr_seeded_w,
      flit_idx_i => flit_idx_w,
      l_out_data_o => l_out_data_o,
      OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i => OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i,
      OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o => OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o,
      OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o => OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o,
      OBS_SUB_TG_HAM_LFSR_ENC_DATA_o => OBS_SUB_TG_HAM_LFSR_ENC_DATA_o
    );
end architecture;
