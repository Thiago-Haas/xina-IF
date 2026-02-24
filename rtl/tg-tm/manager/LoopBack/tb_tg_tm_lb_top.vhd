library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

entity tb_tg_tm_lb_top is
end entity;

architecture tb of tb_tg_tm_lb_top is

  constant c_CLK_PERIOD : time := 10 ns;

  -- number of iterations
  constant c_NUM_ITERS : natural := 200;

  -- step between base addresses (bytes) each iter
  constant c_ADDR_STEP : unsigned(63 downto 0) := to_unsigned(16, 64); -- 0x10

  constant c_BASE_ADDR_INIT : std_logic_vector(63 downto 0) := x"00000000_00000100";
  constant c_SEED_INIT      : std_logic_vector(31 downto 0) := x"1ACEB00C";

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;

  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;

  signal tg_addr  : std_logic_vector(63 downto 0) := c_BASE_ADDR_INIT;
  signal tm_addr  : std_logic_vector(63 downto 0) := c_BASE_ADDR_INIT;

  signal tg_seed  : std_logic_vector(31 downto 0) := c_SEED_INIT;
  signal tm_seed  : std_logic_vector(31 downto 0) := c_SEED_INIT;

  signal tm_mismatch : std_logic;
  signal tm_expected : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  function hex_nibble(n : std_logic_vector(3 downto 0)) return character is
  begin
    case n is
      when "0000" => return '0';
      when "0001" => return '1';
      when "0010" => return '2';
      when "0011" => return '3';
      when "0100" => return '4';
      when "0101" => return '5';
      when "0110" => return '6';
      when "0111" => return '7';
      when "1000" => return '8';
      when "1001" => return '9';
      when "1010" => return 'A';
      when "1011" => return 'B';
      when "1100" => return 'C';
      when "1101" => return 'D';
      when "1110" => return 'E';
      when others => return 'F';
    end case;
  end function;

  function hex32(x : std_logic_vector(31 downto 0)) return string is
    variable s : string(1 to 8);
    variable nib : std_logic_vector(3 downto 0);
  begin
    for i in 0 to 7 loop
      nib := x(31 - i*4 downto 28 - i*4);
      s(i+1) := hex_nibble(nib);
    end loop;
    return s;
  end function;

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  dut: entity work.tg_tm_lb_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start => tg_start,
      o_tg_done  => tg_done,
      TG_INPUT_ADDRESS => tg_addr,
      TG_STARTING_SEED => tg_seed,

      i_tm_start => tm_start,
      o_tm_done  => tm_done,
      TM_INPUT_ADDRESS => tm_addr,
      TM_STARTING_SEED => tm_seed,

      o_tm_mismatch       => tm_mismatch,
      o_tm_expected_value => tm_expected
    );

  -- reset + stimulus
  stim: process
    variable base_addr : unsigned(63 downto 0);
    variable seed      : unsigned(31 downto 0);
  begin
    ARESETn <= '0';
    tg_start <= '0';
    tm_start <= '0';
    wait for 50 ns;
    ARESETn <= '1';
    wait for 50 ns;

    -- Vivado-safe init (cast from SLV constants)
    base_addr := unsigned(c_BASE_ADDR_INIT);
    seed      := unsigned(c_SEED_INIT);

    for it in 0 to integer(c_NUM_ITERS-1) loop
      tg_addr <= std_logic_vector(base_addr);
      tm_addr <= std_logic_vector(base_addr);

      tg_seed <= std_logic_vector(seed);
      tm_seed <= std_logic_vector(seed);

      report "=== ITER " & integer'image(it) &
             " START: addr=0x" & hex32(std_logic_vector(base_addr(31 downto 0))) &
             " seed=0x" & hex32(std_logic_vector(seed)) & " ==="
             severity note;

      -- TG
      tg_start <= '1';
      wait until rising_edge(ACLK);
      tg_start <= '0';
      wait until tg_done = '1';

      -- TM
      tm_start <= '1';
      wait until rising_edge(ACLK);
      tm_start <= '0';
      wait until tm_done = '1';

      report "=== ITER " & integer'image(it) &
             " DONE. mismatch=" & std_logic'image(tm_mismatch) severity note;

      if tm_mismatch = '1' then
        report "ITER " & integer'image(it) &
               " FAILED: expected=" & hex32(tm_expected(31 downto 0)) severity error;
        std.env.stop;
        wait;
      end if;

      -- next iteration
      base_addr := base_addr + c_ADDR_STEP;
      seed      := seed + 1;
      wait for 20 ns;
    end loop;

    report "=== ALL ITERS PASSED (" & integer'image(integer(c_NUM_ITERS)) & ") ===" severity note;
    std.env.stop;
    wait;
  end process;

end architecture;