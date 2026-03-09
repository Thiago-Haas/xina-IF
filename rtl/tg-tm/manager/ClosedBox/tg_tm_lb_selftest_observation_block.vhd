library IEEE;
use IEEE.std_logic_1164.all;

-- Observation block used by closed-box self-test:
-- separated in control/datapath sub-blocks to keep hierarchy explicit.
entity tg_tm_lb_selftest_observation_block is
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
    o_tm_seed  : out std_logic_vector(31 downto 0);

    -- TM result
    i_tm_mismatch : in  std_logic;
    o_error       : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_observation_block is
  signal w_sample_mismatch : std_logic;
begin
  u_obs_control: entity work.tg_tm_lb_selftest_obs_control
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_tg_done => i_tg_done,
      i_tm_done => i_tm_done,
      o_tg_start => o_tg_start,
      o_tm_start => o_tm_start,
      o_sample_mismatch => w_sample_mismatch
    );

  u_obs_datapath: entity work.tg_tm_lb_selftest_obs_datapath
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_sample_mismatch => w_sample_mismatch,
      i_tm_mismatch     => i_tm_mismatch,
      o_tg_addr => o_tg_addr,
      o_tg_seed => o_tg_seed,
      o_tm_addr => o_tm_addr,
      o_tm_seed => o_tm_seed,
      o_error   => o_error
    );
end architecture;

