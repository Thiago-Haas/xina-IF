library IEEE;
use IEEE.std_logic_1164.all;

library std;
use std.env.all;

-- Minimal testbench: drives only clock + reset into a closed-box DUT.
-- The DUT runs self-test internally; inspect waves for internal signals.

entity tb_tg_tm_lb_selftest_top is
end entity;

architecture tb of tb_tg_tm_lb_selftest_top is

  constant c_CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';
  signal uart_rx_i  : std_logic := '1';
  signal uart_tx_o  : std_logic;
  signal uart_cts_i : std_logic := '0';
  signal uart_rts_o : std_logic;

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  dut: entity work.tg_tm_lb_selftest_top
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,
      uart_rx_i  => uart_rx_i,
      uart_tx_o  => uart_tx_o,
      uart_cts_i => uart_cts_i,
      uart_rts_o => uart_rts_o
    );

  -- reset + run
  process
  begin
    ARESETn <= '0';
    wait for 50 ns;
    ARESETn <= '1';

    -- run for a while (adjust as needed)
    wait for 5 ms;
    std.env.stop;
    wait;
  end process;

end architecture;
