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
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1')
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
    l_out_ack_i  : in  std_logic
  );
end entity;

architecture rtl of subordinate_noc_traffic_gen_top is
  signal load_request_w : std_logic;
  signal step_lfsr_w    : std_logic;
  signal flit_idx_w     : unsigned(2 downto 0);
begin
  u_control: entity work.subordinate_noc_traffic_gen_control
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      done_o => done_o,
      l_out_ack_i => l_out_ack_i,
      l_out_val_o => l_out_val_o,
      load_request_o => load_request_w,
      step_lfsr_o => step_lfsr_w,
      flit_idx_o => flit_idx_w
    );

  u_datapath: entity work.subordinate_noc_traffic_gen_datapath
    generic map(
      p_DEST_X => p_DEST_X,
      p_DEST_Y => p_DEST_Y,
      p_SRC_X  => p_SRC_X,
      p_SRC_Y  => p_SRC_Y
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      is_read_i => is_read_i,
      id_i => id_i,
      address_i => address_i,
      seed_i => seed_i,
      load_request_i => load_request_w,
      step_lfsr_i => step_lfsr_w,
      flit_idx_i => flit_idx_w,
      l_out_data_o => l_out_data_o
    );
end architecture;
