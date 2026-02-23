library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

entity tb_tg_tm_ni_hwloopback_flat is
end entity;

architecture tb of tb_tg_tm_ni_hwloopback_flat is

  constant c_CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;
  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;

  signal tg_addr  : std_logic_vector(63 downto 0) := x"0000000000000100";
  signal tm_addr  : std_logic_vector(63 downto 0) := x"0000000000000100";

  signal tg_seed  : std_logic_vector(31 downto 0) := x"1ACEB00C";
  signal tm_seed  : std_logic_vector(31 downto 0) := x"1ACEB00C";

  signal tm_mismatch : std_logic;
  signal tm_expected : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  dut: entity work.tg_tm_ni_hwloopback_flat_top
    generic map(
      p_MEM_ADDR_BITS => 10
    )
    port map(
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
      o_tm_expected_value => tm_expected
    );

  -- stimulus: TB controls sequencing ONLY
  stim: process
  begin
    -- reset
    ARESETn <= '0';
    tg_start <= '0';
    tm_start <= '0';
    wait for 100 ns;
    ARESETn <= '1';
    wait for 50 ns;

    for it in 0 to 2 loop
      report "ITER " & integer'image(it) & " START";

      -- TG phase
      tg_start <= '1';
      wait until rising_edge(ACLK);
      tg_start <= '0';
      wait until tg_done = '1';
      wait until rising_edge(ACLK);

      -- TM phase
      tm_start <= '1';
      wait until rising_edge(ACLK);
      tm_start <= '0';
      wait until tm_done = '1';
      wait until rising_edge(ACLK);

      assert tm_mismatch = '0'
        report "TM mismatch in iter " & integer'image(it)
        severity failure;

      -- perturb for next iter
      tg_seed <= std_logic_vector(unsigned(tg_seed) + 1);
      tm_seed <= tg_seed;
      tg_addr <= std_logic_vector(unsigned(tg_addr) + 64);
      tm_addr <= tg_addr;

      wait for 50 ns;
    end loop;

    report "TB finished";
    std.env.stop;
    wait;
  end process;

end architecture;
