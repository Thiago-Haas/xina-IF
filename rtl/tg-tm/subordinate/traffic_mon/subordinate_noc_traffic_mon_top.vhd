library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- NoC-side response monitor for ni_subordinate_top.
-- Thin wrapper around a response-packet FSM, datapath, and LFSR, following the
-- same structural split as the manager TM.
entity subordinate_noc_traffic_mon_top is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i    : in  std_logic;
    is_read_i  : in  std_logic;
    expected_id_i : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    seed_i        : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    done_o     : out std_logic;
    mismatch_o : out std_logic;

    l_in_data_i : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    l_in_val_i  : in  std_logic;
    l_in_ack_o  : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_top is
  signal load_expected_w : std_logic;
  signal step_lfsr_w     : std_logic;
  signal accept_flit_w   : std_logic;
  signal flit_idx_w      : unsigned(2 downto 0);
  signal is_read_w       : std_logic;
begin
  u_control: entity work.subordinate_noc_traffic_mon_control
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      done_o => done_o,
      l_in_val_i => l_in_val_i,
      l_in_ack_o => l_in_ack_o,
      load_expected_o => load_expected_w,
      step_lfsr_o => step_lfsr_w,
      accept_flit_o => accept_flit_w,
      flit_idx_o => flit_idx_w,
      is_read_o => is_read_w
    );

  u_datapath: entity work.subordinate_noc_traffic_mon_datapath
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      is_read_i => is_read_w,
      expected_id_i => expected_id_i,
      seed_i => seed_i,
      load_expected_i => load_expected_w,
      step_lfsr_i => step_lfsr_w,
      accept_flit_i => accept_flit_w,
      flit_idx_i => flit_idx_w,
      l_in_data_i => l_in_data_i,
      mismatch_o => mismatch_o
    );
end architecture;
