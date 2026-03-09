library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Read-phase datapath (minimal compare):
--  * Single state register = expected word (optionally protected with Hamming)
--  * LFSR is purely combinational: next = f(curr)
--  * Feedback uses expected value (curr) to compute next expected
--  * Comparator is encapsulated in tm_read_compare and outputs mismatch per checked beat
--
-- Initialization (mirrors TG):
--  expected is precomputed as next_lfsr(init_value) so it is ready when the first R beat arrives.
entity tm_read_datapath is
  generic(
    p_ARID      : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    p_LEN       : std_logic_vector(7 downto 0) := x"00";
    p_BURST     : std_logic_vector(1 downto 0) := "01";
    p_INIT_VALUE: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- optional Hamming-protected register for the expected word
    p_USE_TM_HAMMING               : boolean := c_ENABLE_TM_HAMMING_PROTECTION;
    p_USE_TM_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TM_HAMMING_DOUBLE_DETECT;
    p_USE_TM_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TM_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- from controller
    i_seed_pulse  : in std_logic;
    i_rbeat_pulse : in std_logic;

    -- from AXI read data channel
    RDATA : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- AXI constant fields (read address)
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);

    -- comparator output
    o_lfsr_comparison_mismatch : out std_logic;

    -- debug (post-LFSR reg = expected value)
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- observation (only meaningful when HAMMING_ENABLE=true)
    i_OBS_TM_HAM_BUFFER_CORRECT_ERROR : in  std_logic := '1';
    o_ham_single_err : out std_logic;
    o_ham_double_err : out std_logic;
    o_ham_buffer_enc_data : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end tm_read_datapath;

architecture rtl of tm_read_datapath is
  -- expected word register (optionally protected)
  signal w_expected_r : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal w_expected_d : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal w_exp_we     : std_logic := '0';
  signal w_ham_single : std_logic := '0';
  signal w_ham_double : std_logic := '0';
  signal w_expected_enc : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');

  signal w_init_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_input : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_next  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal w_do_init : std_logic;
  signal w_do_step : std_logic;

  function apply_seed(base : std_logic_vector; seed : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v : std_logic_vector(base'range) := base;
    constant W : integer := base'length;
    variable N : integer;
  begin
    if W >= 32 then
      N := 32;
    else
      N := W;
    end if;

    -- overwrite the least-significant bits with the seed
    for i in 0 to N-1 loop
      v(i) := seed(i);
    end loop;
    return v;
  end function;
begin
  -- Constant fields
  ARADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  ARID    <= p_ARID;
  ARLEN   <= p_LEN;
  ARBURST <= p_BURST;

  -- debug
  o_expected_value <= w_expected_r;
  o_ham_single_err <= w_ham_single;
  o_ham_double_err <= w_ham_double;
  o_ham_buffer_enc_data <= w_expected_enc;

  -- Build init value = base/random generic + seed in lower bits
  w_init_value <= apply_seed(p_INIT_VALUE, STARTING_SEED);

  -- Seed-only-once decision is handled by the controller (mirrors TG)
  w_do_init <= i_seed_pulse;
  w_do_step <= i_rbeat_pulse;

  -- LFSR input:
  --  * init: feed init value, compute expected = next(init)
  --  * step: feed current expected, compute next expected = next(expected)
  --  * idle: feed current expected (no state update)
  w_lfsr_input <= w_init_value when (w_do_init = '1') else
                  w_expected_r;

  u_LFSR: entity work.tm_read_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      i_value => w_lfsr_input,
      o_next  => w_lfsr_next
    );

  -- Encapsulated minimal comparison
  u_CMP: entity work.tm_read_compare
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      i_check_pulse => w_do_step,

      i_expected => w_expected_r,
      i_rdata    => RDATA,

      o_lfsr_comparison_mismatch => o_lfsr_comparison_mismatch
    );

  -- Expected-word next value + write-enable
  w_exp_we     <= '1' when (w_do_init = '1' or w_do_step = '1') else '0';
  w_expected_d <= w_lfsr_next;

  -- Optional Hamming register for the expected word
  gen_ham : if p_USE_TM_HAMMING generate
    u_EXP_HAM : entity work.hamming_register
      generic map(
        DATA_WIDTH     => c_AXI_DATA_WIDTH,
        HAMMING_ENABLE => true,
        DETECT_DOUBLE  => p_USE_TM_HAMMING_DOUBLE_DETECT,
        RESET_VALUE    => (c_AXI_DATA_WIDTH-1 downto 0 => '0'),
        INJECT_ERROR   => p_USE_TM_HAMMING_INJECT_ERROR
      )
      port map(
        correct_en_i => i_OBS_TM_HAM_BUFFER_CORRECT_ERROR,
        write_en_i   => w_exp_we,
        data_i       => w_expected_d,
        rstn_i       => ARESETn,
        clk_i        => ACLK,
        single_err_o => w_ham_single,
        double_err_o => w_ham_double,
        enc_data_o   => w_expected_enc,
        data_o       => w_expected_r
      );
  end generate;

  gen_no_ham : if not p_USE_TM_HAMMING generate
    w_ham_single <= '0';
    w_ham_double <= '0';
    w_expected_enc <= (w_expected_enc'left downto c_AXI_DATA_WIDTH => '0') & w_expected_r;
    process(ACLK)
    begin
      if rising_edge(ACLK) then
        if ARESETn = '0' then
          w_expected_r <= (others => '0');
        else
          if w_exp_we = '1' then
            w_expected_r <= w_expected_d;
          end if;
        end if;
      end if;
    end process;
  end generate;
end rtl;
