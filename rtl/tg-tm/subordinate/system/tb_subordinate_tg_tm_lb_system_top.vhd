library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.env.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

entity tb_subordinate_tg_tm_lb_system_top is
end entity;

architecture tb of tb_subordinate_tg_tm_lb_system_top is
  constant C_CLK_PERIOD : time := 10 ns;
  constant C_NUM_ITERS  : natural := 64;
  constant C_START_ADDR : unsigned(c_AXI_ADDR_WIDTH - 1 downto 0) := x"00000100_00000000";
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
  signal tg_tmr_error : std_logic;
  signal tm_tmr_error : std_logic;
  signal lb_tmr_error : std_logic;
  signal tg_lfsr_single_err : std_logic;
  signal tg_lfsr_double_err : std_logic;
  signal tm_lfsr_single_err : std_logic;
  signal tm_lfsr_double_err : std_logic;
  signal tm_counter_single_err : std_logic;
  signal tm_counter_double_err : std_logic;
  signal tm_transaction_count : std_logic_vector(c_SUB_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
  signal lb_payload_single_err : std_logic;
  signal lb_payload_double_err : std_logic;
  signal lb_rdata_single_err : std_logic;
  signal lb_rdata_double_err : std_logic;
  signal lb_id_state_single_err : std_logic;
  signal lb_id_state_double_err : std_logic;
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
      OBS_SUB_TG_TMR_CTRL_ERROR_o => tg_tmr_error,
      OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o => tg_lfsr_single_err,
      OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o => tg_lfsr_double_err,
      OBS_SUB_TM_TMR_CTRL_ERROR_o => tm_tmr_error,
      OBS_SUB_TM_HAM_LFSR_SINGLE_ERR_o => tm_lfsr_single_err,
      OBS_SUB_TM_HAM_LFSR_DOUBLE_ERR_o => tm_lfsr_double_err,
      OBS_SUB_TM_HAM_COUNTER_SINGLE_ERR_o => tm_counter_single_err,
      OBS_SUB_TM_HAM_COUNTER_DOUBLE_ERR_o => tm_counter_double_err,
      TM_TRANSACTION_COUNT_o => tm_transaction_count,
      OBS_SUB_LB_TMR_CTRL_ERROR_o => lb_tmr_error,
      OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o => lb_payload_single_err,
      OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o => lb_payload_double_err,
      OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o => lb_rdata_single_err,
      OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o => lb_rdata_double_err,
      OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o => lb_id_state_single_err,
      OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o => lb_id_state_double_err,
      OBS_SUB_FE_INJ_TMR_STATUS_ERROR_o => status_tmr_error,
      OBS_SUB_RX_HAM_H_SRC_SINGLE_ERR_o => h_src_single_err,
      OBS_SUB_RX_HAM_H_SRC_DOUBLE_ERR_o => h_src_double_err,
      OBS_SUB_RX_HAM_H_INTERFACE_SINGLE_ERR_o => h_interface_single_err,
      OBS_SUB_RX_HAM_H_INTERFACE_DOUBLE_ERR_o => h_interface_double_err,
      OBS_SUB_RX_HAM_H_ADDRESS_SINGLE_ERR_o => h_address_single_err,
      OBS_SUB_RX_HAM_H_ADDRESS_DOUBLE_ERR_o => h_address_double_err
    );

  stim: process
    variable id_v   : unsigned(c_AXI_ID_WIDTH - 1 downto 0);
  begin
    ARESETn <= '0';
    start <= '0';
    seed <= C_LFSR_SEED;
    wait for 50 ns;
    ARESETn <= '1';
    wait for 50 ns;

    id_v := (others => '0');

    -- The subordinate loopback is a single-slot target, like the manager-side
    -- loopback. Each payload is written and immediately read back.
    for i in 0 to integer(C_NUM_ITERS - 1) loop
      address <= std_logic_vector(C_START_ADDR);
      id <= std_logic_vector(id_v);
      is_read <= '0';
      start <= '1';
      wait until rising_edge(ACLK);
      start <= '0';
      wait until done = '1';
      assert mismatch = '0' report "subordinate write response mismatch" severity failure;
      wait until rising_edge(ACLK);

      wait for 20 ns;

      address <= std_logic_vector(C_START_ADDR);
      id <= std_logic_vector(id_v);
      is_read <= '1';
      start <= '1';
      wait until rising_edge(ACLK);
      start <= '0';
      wait until done = '1';
      assert mismatch = '0' report "subordinate read response mismatch" severity failure;
      wait until rising_edge(ACLK);

      id_v := id_v + 1;
      wait for 20 ns;
    end loop;

    assert corrupt_packet = '0' report "subordinate corrupt packet flag asserted" severity failure;
    assert tg_tmr_error = '0' report "subordinate TG control TMR error asserted" severity failure;
    assert tg_lfsr_single_err = '0' report "subordinate TG LFSR Hamming single error asserted" severity failure;
    assert tg_lfsr_double_err = '0' report "subordinate TG LFSR Hamming double error asserted" severity failure;
    assert tm_tmr_error = '0' report "subordinate TM control TMR error asserted" severity failure;
    assert tm_lfsr_single_err = '0' report "subordinate TM protected state Hamming single error asserted" severity failure;
    assert tm_lfsr_double_err = '0' report "subordinate TM protected state Hamming double error asserted" severity failure;
    assert tm_counter_single_err = '0' report "subordinate TM transaction counter Hamming single error asserted" severity failure;
    assert tm_counter_double_err = '0' report "subordinate TM transaction counter Hamming double error asserted" severity failure;
    assert unsigned(tm_transaction_count) = to_unsigned(2 * C_NUM_ITERS, tm_transaction_count'length)
      report "subordinate TM transaction count mismatch" severity failure;
    assert lb_tmr_error = '0' report "subordinate loopback control TMR error asserted" severity failure;
    assert lb_payload_single_err = '0' report "subordinate loopback payload Hamming single error asserted" severity failure;
    assert lb_payload_double_err = '0' report "subordinate loopback payload Hamming double error asserted" severity failure;
    assert lb_rdata_single_err = '0' report "subordinate loopback RDATA Hamming single error asserted" severity failure;
    assert lb_rdata_double_err = '0' report "subordinate loopback RDATA Hamming double error asserted" severity failure;
    assert lb_id_state_single_err = '0' report "subordinate loopback ID state Hamming single error asserted" severity failure;
    assert lb_id_state_double_err = '0' report "subordinate loopback ID state Hamming double error asserted" severity failure;
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
