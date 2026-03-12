library IEEE;
use IEEE.std_logic_1164.all;

-- Compatibility wrapper:
-- keeps legacy entity name while delegating implementation to the
-- hierarchy-separated observation block (control + datapath).

entity tg_tm_lb_selftest_ctrl is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    tg_start_o : out std_logic;
    tg_done_i  : in  std_logic;
    tg_addr_o  : out std_logic_vector(63 downto 0);
    tg_seed_o  : out std_logic_vector(31 downto 0);

    -- TM control
    tm_start_o : out std_logic;
    tm_done_i  : in  std_logic;
    tm_addr_o  : out std_logic_vector(63 downto 0);
    tm_seed_o  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of tg_tm_lb_selftest_ctrl is
begin
  u_legacy_obs_control: entity work.tg_tm_lb_selftest_obs_control
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      experiment_run_enable_i  => '1',
      experiment_reset_pulse_i => '0',
      tg_done_i => tg_done_i,
      tm_done_i => tm_done_i,
      tg_start_o => tg_start_o,
      tm_start_o => tm_start_o
    );

  u_legacy_obs_datapath: entity work.tg_tm_lb_selftest_obs_datapath
    port map(
      tg_addr_o  => tg_addr_o,
      tg_seed_o  => tg_seed_o,
      tm_addr_o  => tm_addr_o,
      tm_seed_o  => tm_seed_o
    );
end architecture;
