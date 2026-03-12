library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_buffer_fifo_ham is
end entity;

architecture tb of tb_buffer_fifo_ham is

  constant c_CLK_PERIOD : time := 10 ns;

  constant c_DATA_WIDTH   : positive := 32;
  constant c_BUFFER_DEPTH : positive := 8;
  constant c_NUM_ITERS    : natural  := 100;

  signal ACLK   : std_logic := '0';
  signal ARESET : std_logic := '1';

  -- DUT signals
  signal READ_i    : std_logic := '0';
  signal READ_OK_o : std_logic;
  signal DATA_o    : std_logic_vector(c_DATA_WIDTH-1 downto 0);

  signal WRITE_i    : std_logic := '0';
  signal DATA_i     : std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
  signal WRITE_OK_o : std_logic;

  signal correct_error_i : std_logic := '1';
  signal single_err_o    : std_logic;
  signal double_err_o    : std_logic;

begin

  --------------------------------------------------------------------------
  -- Clock
  --------------------------------------------------------------------------
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  --------------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------------
  dut: entity work.buffer_fifo_ham
    generic map(
      p_DATA_WIDTH   => c_DATA_WIDTH,
      p_BUFFER_DEPTH => c_BUFFER_DEPTH,
      DETECT_DOUBLE  => true
    )
    port map(
      ACLK   => ACLK,
      ARESET => ARESET,

      READ_i    => READ_i,
      READ_OK_o => READ_OK_o,
      DATA_o    => DATA_o,

      WRITE_i    => WRITE_i,
      DATA_i     => DATA_i,
      WRITE_OK_o => WRITE_OK_o,

      correct_error_i => correct_error_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      enc_stage_data_o => open,
      OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i => '1',
      OBS_HAM_FIFO_CTRL_TMR_ERROR_o         => open
    );

  --------------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------------
  stim: process
    variable expected : std_logic_vector(c_DATA_WIDTH-1 downto 0);
  begin

    -- Reset
    ARESET <= '1';
    wait for 50 ns;
    ARESET <= '0';
    wait for 20 ns;

    ----------------------------------------------------------------------
    -- LOOP
    ----------------------------------------------------------------------
    for i in 0 to c_NUM_ITERS-1 loop

      expected := std_logic_vector(to_unsigned(i, c_DATA_WIDTH));

      --------------------------------------------------------------------
      -- WRITE
      --------------------------------------------------------------------
      DATA_i  <= expected;
      WRITE_i <= '1';
      wait until rising_edge(ACLK);
      WRITE_i <= '0';

      wait for c_CLK_PERIOD;

      --------------------------------------------------------------------
      -- READ
      --------------------------------------------------------------------
      READ_i <= '1';
      wait until rising_edge(ACLK);
      READ_i <= '0';

      wait for c_CLK_PERIOD;

      --------------------------------------------------------------------
      -- CHECK
      --------------------------------------------------------------------
      assert DATA_o = expected
        report "Mismatch at iteration " & integer'image(i)
        severity error;

      wait for c_CLK_PERIOD;

    end loop;

    ----------------------------------------------------------------------
    -- Done
    ----------------------------------------------------------------------
    wait for 50 ns;
    std.env.stop;
    wait;

  end process;

end architecture;
