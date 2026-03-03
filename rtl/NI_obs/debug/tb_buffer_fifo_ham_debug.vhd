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

  signal i_READ    : std_logic := '0';
  signal o_READ_OK : std_logic;
  signal o_DATA    : std_logic_vector(c_DATA_WIDTH-1 downto 0);

  signal i_WRITE    : std_logic := '0';
  signal i_DATA     : std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
  signal o_WRITE_OK : std_logic;

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

      i_READ    => i_READ,
      o_READ_OK => o_READ_OK,
      o_DATA    => o_DATA,

      i_WRITE    => i_WRITE,
      i_DATA     => i_DATA,
      o_WRITE_OK => o_WRITE_OK,

      correct_error_i => correct_error_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,

      i_INJECT_EN   => inj_en,
      i_INJECT_IDX  => inj_idx,
      i_INJECT_MASK => inj_mask
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
    i_WRITE <= '0';
    i_READ  <= '0';
    inj_en  <= '0';
    inj_mask <= (others => '0');
    inj_idx <= 0;

    wait for 5*c_CLK_PERIOD;
    wait until rising_edge(ACLK);
    ARESET <= '0';

    for it in 0 to integer(c_NUM_ITERS-1) loop

      expected := std_logic_vector(to_unsigned(it, c_DATA_WIDTH));

      -- WRITE one word
      while o_WRITE_OK = '0' loop
        wait until rising_edge(ACLK);
      end loop;

      i_DATA  <= expected;
      i_WRITE <= '1';
      wait until rising_edge(ACLK);
      i_WRITE <= '0';

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
      while o_READ_OK = '0' loop
        wait until rising_edge(ACLK);
      end loop;

      i_READ <= '1';
      wait until rising_edge(ACLK);
      i_READ <= '0';

      -- wait 1 cycle for data/flags to settle
      wait until rising_edge(ACLK);

      -- ASSERTS
      if (not do_inj) then
        assert o_DATA = expected
          report "DATA mismatch (no inj) at it=" & integer'image(it)
          severity error;

        assert (single_err_o = '0' and double_err_o = '0')
          report "Unexpected err flags (no inj) at it=" & integer'image(it) &
                 " single=" & std_logic'image(single_err_o) &
                 " double=" & std_logic'image(double_err_o)
          severity error;

      elsif (do_inj and (not do_dbl)) then
        -- single-bit: should correct
        assert o_DATA = expected
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