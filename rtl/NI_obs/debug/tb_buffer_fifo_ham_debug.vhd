library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

use work.hamming_pkg.all;

entity tb_buffer_fifo_ham_debug is
end entity;

architecture tb of tb_buffer_fifo_ham_debug is

  constant c_CLK_PERIOD : time := 10 ns;

  constant c_DATA_WIDTH    : positive := 32;
  constant c_BUFFER_DEPTH  : positive := 4;
  constant c_DETECT_DOUBLE : boolean  := true;

  constant c_PARITY_WIDTH : integer := get_ecc_size(c_DATA_WIDTH, c_DETECT_DOUBLE);
  constant c_ENC_WIDTH    : integer := c_DATA_WIDTH + c_PARITY_WIDTH;

  constant c_NUM_ITERS : natural := 200;

  -- inject every N iterations (0 disables)
  constant c_INJECT_EVERY        : natural := 8;  -- periodic
  constant c_INJECT_DOUBLE_EVERY : natural := 2;  -- every 2nd injection is double

  signal ACLK   : std_logic := '0';
  signal ARESET : std_logic := '1';

  signal READ_i    : std_logic := '0';
  signal READ_OK_o : std_logic;
  signal DATA_o    : std_logic_vector(c_DATA_WIDTH-1 downto 0);

  signal WRITE_i    : std_logic := '0';
  signal DATA_i     : std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
  signal WRITE_OK_o : std_logic;

  signal correct_error_i : std_logic := '1';
  signal single_err_o    : std_logic;
  signal double_err_o    : std_logic;

  -- injection ports (debug)
  signal inj_en   : std_logic := '0';
  signal inj_idx  : integer   := 0;
  signal inj_mask : std_logic_vector(c_ENC_WIDTH-1 downto 0) := (others => '0');

begin

  ACLK <= not ACLK after c_CLK_PERIOD/2;

  dut: entity work.buffer_fifo_ham_debug
    generic map(
      p_DATA_WIDTH   => c_DATA_WIDTH,
      p_BUFFER_DEPTH => c_BUFFER_DEPTH,
      DETECT_DOUBLE  => c_DETECT_DOUBLE
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

      INJECT_EN_i   => inj_en,
      INJECT_IDX_i  => inj_idx,
      INJECT_MASK_i => inj_mask
    );

  stim: process
    variable inj_cnt : natural := 0;

    variable do_inj  : boolean;
    variable do_dbl  : boolean;

    variable v_mask_single : std_logic_vector(c_ENC_WIDTH-1 downto 0);
    variable v_mask_double : std_logic_vector(c_ENC_WIDTH-1 downto 0);

    variable expected : std_logic_vector(c_DATA_WIDTH-1 downto 0);

  begin
    -- precompute masks
    v_mask_single := (others => '0');
    v_mask_single(0) := '1';

    v_mask_double := (others => '0');
    v_mask_double(0) := '1';
    if c_ENC_WIDTH > 5 then
      v_mask_double(5) := '1';
    end if;

    -- reset
    ARESET <= '1';
    WRITE_i <= '0';
    READ_i  <= '0';
    inj_en  <= '0';
    inj_mask <= (others => '0');
    inj_idx <= 0;

    wait for 5*c_CLK_PERIOD;
    wait until rising_edge(ACLK);
    ARESET <= '0';

    for it in 0 to integer(c_NUM_ITERS-1) loop

      expected := std_logic_vector(to_unsigned(it, c_DATA_WIDTH));

      -- WRITE one word
      while WRITE_OK_o = '0' loop
        wait until rising_edge(ACLK);
      end loop;

      DATA_i  <= expected;
      WRITE_i <= '1';
      wait until rising_edge(ACLK);
      WRITE_i <= '0';

      -- OPTIONAL INJECT
      do_inj := (c_INJECT_EVERY /= 0) and ((it mod integer(c_INJECT_EVERY)) = 0);

      if do_inj then
        do_dbl := ((inj_cnt mod c_INJECT_DOUBLE_EVERY) = (c_INJECT_DOUBLE_EVERY-1));

        inj_idx <= 0; -- newest word
        if do_dbl then
          inj_mask <= v_mask_double;
        else
          inj_mask <= v_mask_single;
        end if;

        inj_en <= '1';
        wait until rising_edge(ACLK);
        inj_en <= '0';
        inj_mask <= (others => '0');

        inj_cnt := inj_cnt + 1;
      else
        do_dbl := false;
      end if;

      -- READ one word
      while READ_OK_o = '0' loop
        wait until rising_edge(ACLK);
      end loop;

      READ_i <= '1';
      wait until rising_edge(ACLK);
      READ_i <= '0';

      -- wait 1 cycle for data/flags to settle
      wait until rising_edge(ACLK);

      -- ASSERTS
      if (not do_inj) then
        assert DATA_o = expected
          report "DATA mismatch (no inj) at it=" & integer'image(it)
          severity error;

        assert (single_err_o = '0' and double_err_o = '0')
          report "Unexpected err flags (no inj) at it=" & integer'image(it) &
                 " single=" & std_logic'image(single_err_o) &
                 " double=" & std_logic'image(double_err_o)
          severity error;

      elsif (do_inj and (not do_dbl)) then
        -- single-bit: should correct
        assert DATA_o = expected
          report "DATA mismatch (single inj) at it=" & integer'image(it)
          severity error;

        assert single_err_o = '1'
          report "Expected single_err_o=1 (single inj) at it=" & integer'image(it)
          severity error;

        assert double_err_o = '0'
          report "Expected double_err_o=0 (single inj) at it=" & integer'image(it)
          severity error;

      else
        -- double-bit: should detect (data may or may not match)
        assert double_err_o = '1'
          report "Expected double_err_o=1 (double inj) at it=" & integer'image(it)
          severity error;
      end if;

      -- spacing
      wait until rising_edge(ACLK);

    end loop;

    wait for 10*c_CLK_PERIOD;
    std.env.stop;
    wait;
  end process;

end architecture;