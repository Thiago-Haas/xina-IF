library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.env.all;

use work.xina_noc_pkg.all;

entity tb_subordinate_tg_tm_lb_system_top is
end entity;

architecture tb of tb_subordinate_tg_tm_lb_system_top is
  constant C_CLK_PERIOD : time := 10 ns;
  constant C_NUM_ITERS  : natural := 64;
  constant C_START_ADDR : unsigned(c_AXI_ADDR_WIDTH - 1 downto 0) := x"00000100_00000000";
  constant C_ADDR_STEP  : unsigned(c_AXI_ADDR_WIDTH - 1 downto 0) :=
    to_unsigned(1, c_AXI_ADDR_WIDTH - c_AXI_DATA_WIDTH) & to_unsigned(0, c_AXI_DATA_WIDTH);
  constant C_LFSR_SEED  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := x"1ACEB00C";

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal start   : std_logic := '0';
  signal is_read : std_logic := '0';
  signal id      : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal address : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal seed    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := C_LFSR_SEED;

  signal done    : std_logic;
  signal mismatch : std_logic;
  signal corrupt_packet : std_logic;
  signal status_tmr_error : std_logic;
  signal h_src_single_err : std_logic;
  signal h_src_double_err : std_logic;
  signal h_interface_single_err : std_logic;
  signal h_interface_double_err : std_logic;
  signal h_address_single_err : std_logic;
  signal h_address_double_err : std_logic;
begin
  ACLK <= not ACLK after C_CLK_PERIOD / 2;

  u_subordinate_tg_tm_lb_system_top: entity work.subordinate_tg_tm_lb_system_top
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      start_i => start,
      is_read_i => is_read,
      id_i => id,
      address_i => address,
      seed_i => seed,
      done_o => done,
      mismatch_o => mismatch,
      corrupt_packet_o => corrupt_packet,
      OBS_SUB_FE_INJ_TMR_STATUS_ERROR_o => status_tmr_error,
      OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o => h_src_single_err,
      OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o => h_src_double_err,
      OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o => h_interface_single_err,
      OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o => h_interface_double_err,
      OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o => h_address_single_err,
      OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o => h_address_double_err
    );

  stim: process
    variable addr_v : unsigned(c_AXI_ADDR_WIDTH - 1 downto 0);
    variable id_v   : unsigned(c_AXI_ID_WIDTH - 1 downto 0);
  begin
    ARESETn <= '0';
    start <= '0';
    seed <= C_LFSR_SEED;
    wait for 50 ns;
    ARESETn <= '1';
    wait for 50 ns;

    addr_v := C_START_ADDR;
    id_v := (others => '0');

    -- Write the manager-style LFSR stream into the subordinate-side target.
    for i in 0 to integer(C_NUM_ITERS - 1) loop
      address <= std_logic_vector(addr_v);
      id <= std_logic_vector(id_v);
      is_read <= '0';
      start <= '1';
      wait until rising_edge(ACLK);
      start <= '0';
      wait until done = '1';
      assert mismatch = '0' report "subordinate write response mismatch" severity failure;
      wait until rising_edge(ACLK);

      addr_v := addr_v + C_ADDR_STEP;
      id_v := id_v + 1;
      wait for 20 ns;
    end loop;

    addr_v := C_START_ADDR;
    id_v := (others => '0');

    -- Read the same locations back. The NoC TM validates the returned payloads
    -- against its own copy of the same LFSR sequence.
    for i in 0 to integer(C_NUM_ITERS - 1) loop
      address <= std_logic_vector(addr_v);
      id <= std_logic_vector(id_v);
      is_read <= '1';
      start <= '1';
      wait until rising_edge(ACLK);
      start <= '0';
      wait until done = '1';
      assert mismatch = '0' report "subordinate read response mismatch" severity failure;
      wait until rising_edge(ACLK);

      addr_v := addr_v + C_ADDR_STEP;
      id_v := id_v + 1;
      wait for 20 ns;
    end loop;

    assert corrupt_packet = '0' report "subordinate corrupt packet flag asserted" severity failure;
    assert status_tmr_error = '0' report "subordinate status TMR error asserted" severity failure;
    assert h_src_single_err = '0' report "subordinate H_SRC Hamming single error asserted" severity failure;
    assert h_src_double_err = '0' report "subordinate H_SRC Hamming double error asserted" severity failure;
    assert h_interface_single_err = '0' report "subordinate H_INTERFACE Hamming single error asserted" severity failure;
    assert h_interface_double_err = '0' report "subordinate H_INTERFACE Hamming double error asserted" severity failure;
    assert h_address_single_err = '0' report "subordinate H_ADDRESS Hamming single error asserted" severity failure;
    assert h_address_double_err = '0' report "subordinate H_ADDRESS Hamming double error asserted" severity failure;
    std.env.stop;
    wait;
  end process;
end architecture;
