library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;

-- Closed-box self-test top:
--   Inputs: ACLK, ARESETn
--   Internally instantiates TG+TM+NI+loopback (tg_tm_lb_top)
--   and a small controller (tg_tm_lb_selftest_ctrl) that drives
--   start pulses and the address/seed sequence.

entity tg_tm_lb_selftest_top is
  port (
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    -- Simple outward-facing probe bus to prevent aggressive trimming during synthesis.
    -- (Use it only for utilization checks / debug.)
    o_probe : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of tg_tm_lb_selftest_top is

  -- TG control
  signal tg_start : std_logic;
  signal tg_done  : std_logic;
  signal tg_addr  : std_logic_vector(63 downto 0);
  signal tg_seed  : std_logic_vector(31 downto 0);

  -- TM control
  signal tm_start : std_logic;
  signal tm_done  : std_logic;
  signal tm_addr  : std_logic_vector(63 downto 0);
  signal tm_seed  : std_logic_vector(31 downto 0);

  -- TM observability (kept internal; view in waves if needed)
  signal tm_mismatch : std_logic;

  -- self-test status (kept internal)
  signal selftest_error : std_logic;

  -- tiny activity counter for the probe bus
  signal r_probe_cnt : unsigned(3 downto 0) := (others => '0');

begin

  -- Small free-running counter (and exported status bits) so synthesis can't trivially
  -- prune internal logic when used as a closed box.
  process (ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_probe_cnt <= (others => '0');
      else
        r_probe_cnt <= r_probe_cnt + 1;
      end if;
    end if;
  end process;

  -- [7] error latch from controller
  -- [6] TM mismatch from TM
  -- [5] TG done pulse
  -- [4] TM done pulse
  -- [3:0] activity counter
  o_probe <= selftest_error & tm_mismatch & tg_done & tm_done & std_logic_vector(r_probe_cnt);

  u_ctrl: entity work.tg_tm_lb_selftest_ctrl
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      o_tg_start => tg_start,
      i_tg_done  => tg_done,
      o_tg_addr  => tg_addr,
      o_tg_seed  => tg_seed,

      o_tm_start => tm_start,
      i_tm_done  => tm_done,
      o_tm_addr  => tm_addr,
      o_tm_seed  => tm_seed,

      i_tm_mismatch => tm_mismatch,
      o_error       => selftest_error
    );

  u_dut: entity work.tg_tm_lb_top
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start       => tg_start,
      o_tg_done        => tg_done,
      TG_INPUT_ADDRESS => tg_addr,
      TG_STARTING_SEED => tg_seed,

      i_tm_start       => tm_start,
      o_tm_done        => tm_done,
      TM_INPUT_ADDRESS => tm_addr,
      TM_STARTING_SEED => tm_seed,

      o_tm_mismatch       => tm_mismatch,
      o_tm_expected_value => open
    );

end architecture;
