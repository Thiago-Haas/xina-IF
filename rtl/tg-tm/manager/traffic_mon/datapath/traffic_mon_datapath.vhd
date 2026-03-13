library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Read-phase datapath (minimal compare):
--  * Single state register = expected word (optionally protected with Hamming)
--  * LFSR is purely combinational: next = f(curr)
--  * Feedback uses expected value (curr) to compute next expected
--  * Comparator is encapsulated in traffic_mon_datapath_compare and outputs mismatch per checked beat
--
-- Initialization (mirrors TG):
--  expected is precomputed as next_lfsr(init_value) so it is ready when the first R beat arrives.
entity traffic_mon_datapath is
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
    seed_pulse_i  : in std_logic;
    rbeat_pulse_i : in std_logic;

    -- from AXI read data channel
    RDATA : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- AXI constant fields (read address)
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);

    -- comparator output
    lfsr_comparison_mismatch_o : out std_logic;

    -- debug (post-LFSR reg = expected value)
    expected_value_o : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- observation (only meaningful when HAMMING_ENABLE=true)
    OBS_TM_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    ham_single_err_o : out std_logic;
    ham_double_err_o : out std_logic;
    ham_buffer_enc_data_o : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end traffic_mon_datapath;

architecture rtl of traffic_mon_datapath is
  -- expected word register (optionally protected)
  signal expected_r : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal expected_d_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal exp_we_w     : std_logic := '0';
  signal ham_single_w : std_logic := '0';
  signal ham_double_w : std_logic := '0';
  signal expected_enc_w : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');

  signal init_value_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_input_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_next_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal do_init_w : std_logic;
  signal do_step_w : std_logic;

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

  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of expected_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of expected_r : signal is true;
begin
  -- Constant fields
  ARADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  ARID    <= p_ARID;
  ARLEN   <= p_LEN;
  ARBURST <= p_BURST;

  -- debug
  expected_value_o <= expected_r;
  ham_single_err_o <= ham_single_w;
  ham_double_err_o <= ham_double_w;
  ham_buffer_enc_data_o <= expected_enc_w;

  -- Build init value = base/random generic + seed in lower bits
  init_value_w <= apply_seed(p_INIT_VALUE, STARTING_SEED);

  -- Seed-only-once decision is handled by the controller (mirrors TG)
  do_init_w <= seed_pulse_i;
  do_step_w <= rbeat_pulse_i;

  -- LFSR input:
  --  * init: feed init value, compute expected = next(init)
  --  * step: feed current expected, compute next expected = next(expected)
  --  * idle: feed current expected (no state update)
  lfsr_input_w <= init_value_w when (do_init_w = '1') else
                  expected_r;

  u_LFSR: entity work.traffic_mon_datapath_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      value_i => lfsr_input_w,
      next_o  => lfsr_next_w
    );

  -- Encapsulated minimal comparison
  u_CMP: entity work.traffic_mon_datapath_compare
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      check_pulse_i => do_step_w,

      expected_i => expected_r,
      rdata_i    => RDATA,

      lfsr_comparison_mismatch_o => lfsr_comparison_mismatch_o
    );

  -- Expected-word next value + write-enable
  exp_we_w     <= '1' when (do_init_w = '1' or do_step_w = '1') else '0';
  expected_d_w <= lfsr_next_w;

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
        correct_en_i => OBS_TM_HAM_BUFFER_CORRECT_ERROR_i,
        write_en_i   => exp_we_w,
        data_i       => expected_d_w,
        rstn_i       => ARESETn,
        clk_i        => ACLK,
        single_err_o => ham_single_w,
        double_err_o => ham_double_w,
        enc_data_o   => expected_enc_w,
        data_o       => expected_r
      );
  end generate;

  gen_no_ham : if not p_USE_TM_HAMMING generate
    ham_single_w <= '0';
    ham_double_w <= '0';
    expected_enc_w <= (expected_enc_w'left downto c_AXI_DATA_WIDTH => '0') & expected_r;
    process(ACLK)
    begin
      if rising_edge(ACLK) then
        if ARESETn = '0' then
          expected_r <= (others => '0');
        else
          if exp_we_w = '1' then
            expected_r <= expected_d_w;
          end if;
        end if;
      end if;
    end process;
  end generate;
end rtl;
