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
  signal i_READ    : std_logic := '0';
  signal o_READ_OK : std_logic;
  signal o_DATA    : std_logic_vector(c_DATA_WIDTH-1 downto 0);

  signal i_WRITE    : std_logic := '0';
  signal i_DATA     : std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
  signal o_WRITE_OK : std_logic;

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

      i_READ    => i_READ,
      o_READ_OK => o_READ_OK,
      o_DATA    => o_DATA,

      i_WRITE    => i_WRITE,
      i_DATA     => i_DATA,
      o_WRITE_OK => o_WRITE_OK,

      correct_error_i => correct_error_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      o_enc_stage_data => open
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
      i_DATA  <= expected;
      i_WRITE <= '1';
      wait until rising_edge(ACLK);
      i_WRITE <= '0';

      wait for c_CLK_PERIOD;

      --------------------------------------------------------------------
      -- READ
      --------------------------------------------------------------------
      i_READ <= '1';
      wait until rising_edge(ACLK);
      i_READ <= '0';

      wait for c_CLK_PERIOD;

      --------------------------------------------------------------------
      -- CHECK
      --------------------------------------------------------------------
      assert o_DATA = expected
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
