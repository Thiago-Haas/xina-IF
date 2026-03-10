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
    o_tg_start : out std_logic;
    i_tg_done  : in  std_logic;
    o_tg_addr  : out std_logic_vector(63 downto 0);
    o_tg_seed  : out std_logic_vector(31 downto 0);

    -- TM control
    o_tm_start : out std_logic;
    i_tm_done  : in  std_logic;
    o_tm_addr  : out std_logic_vector(63 downto 0);
    o_tm_seed  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of tg_tm_lb_selftest_ctrl is
begin
  u_legacy_obs_control: entity work.tg_tm_lb_selftest_obs_control
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_experiment_run_enable  => '1',
      i_experiment_reset_pulse => '0',
      i_tg_done => i_tg_done,
      i_tm_done => i_tm_done,
      o_tg_start => o_tg_start,
      o_tm_start => o_tm_start
    );

  u_legacy_obs_datapath: entity work.tg_tm_lb_selftest_obs_datapath
    port map(
      o_tg_addr  => o_tg_addr,
      o_tg_seed  => o_tg_seed,
      o_tm_addr  => o_tm_addr,
      o_tm_seed  => o_tm_seed
    );
end architecture;
