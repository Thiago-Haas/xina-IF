library IEEE;
library std;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.env.all;

use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity tb_manager_integration_top is
end entity;

architecture tb of tb_manager_integration_top is
  constant c_CLK_PERIOD : time := 10 ns;
  constant c_TIMEOUT_CYCLES_WRITE : natural := 200000; -- adjust if you increase payload/transactions
  constant c_TIMEOUT_CYCLES_READ  : natural := 200000;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal i_start_write : std_logic := '0';
  signal i_start_read  : std_logic := '0';

  signal i_address : std_logic_vector(63 downto 0) := (others => '0');
  signal i_seed    : std_logic_vector(31 downto 0) := (others => '0');

  signal o_done_write : std_logic;
  signal o_done_read  : std_logic;
  signal o_mismatch   : std_logic;
  signal o_expected_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal o_lfsr_value     : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal o_corrupt_packet : std_logic;

begin

  -- clock
  p_clk : process
  begin
    while true loop
      ACLK <= '0';
      wait for c_CLK_PERIOD/2;
      ACLK <= '1';
      wait for c_CLK_PERIOD/2;
    end loop;
  end process;

  -- DUT
  dut : entity work.manager_integration_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start_write => i_start_write,
      i_start_read  => i_start_read,

      i_address => i_address,
      i_seed    => i_seed,

      o_done_write => o_done_write,
      o_done_read  => o_done_read,
      o_mismatch   => o_mismatch,
      o_expected_value => o_expected_value,
      o_lfsr_value     => o_lfsr_value,
      o_corrupt_packet => o_corrupt_packet
    );

  -- stimulus
  p_stim : process
    variable v_cnt : natural;
  begin
    -- defaults
    i_start_write <= '0';
    i_start_read  <= '0';

    -- pick a non-zero address + seed (same for write + read)
    i_address <= x"0000000000001000";
    i_seed    <= x"00000001";

    -- reset
    ARESETn <= '0';
    wait for 20*c_CLK_PERIOD;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    -- start write (one-cycle pulse)
    i_start_write <= '1';
    wait until rising_edge(ACLK);
    i_start_write <= '0';

    -- wait write to complete (with timeout)
    v_cnt := 0;
    while o_done_write /= '1' loop
      wait until rising_edge(ACLK);
      v_cnt := v_cnt + 1;

      if o_corrupt_packet = '1' then
        report "WARNING: CORRUPT_PACKET asserted during write phase" severity warning;
      end if;

      if v_cnt = c_TIMEOUT_CYCLES_WRITE then
        assert false report "TIMEOUT waiting for o_done_write" severity failure;
      end if;
    end loop;

    -- deassert start write
    i_start_write <= '0';

    -- small gap
    for k in 0 to 9 loop
      wait until rising_edge(ACLK);
    end loop;

    -- start read (hold high until done)
    i_start_read <= '1';

    -- wait read to complete (with timeout)
    v_cnt := 0;
    while o_done_read /= '1' loop
      wait until rising_edge(ACLK);
      v_cnt := v_cnt + 1;

      if o_mismatch = '1' then
        report "TM mismatch asserted early. Expected=" & to_hstring(o_expected_value) severity warning;
      end if;

      if o_corrupt_packet = '1' then
        report "WARNING: CORRUPT_PACKET asserted during read phase" severity warning;
      end if;

      if v_cnt = c_TIMEOUT_CYCLES_READ then
        assert false report "TIMEOUT waiting for o_done_read" severity failure;
      end if;
    end loop;

    -- deassert start read
    i_start_read <= '0';

    -- final check
    assert o_mismatch = '0'
      report "TM mismatch detected at end. Expected=" &
             to_hstring(o_expected_value) &
             " ; LFSR(last)=" &
             to_hstring(o_lfsr_value)
      severity error;

    report "Simulation completed (write then read)." severity note;
    stop;
  end process;

end architecture;
