library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Aggressive resource-minimized write datapath:
--  * NO external override ports
--  * NO init-value generic / no helper functions
--  * AW fields are constants (single-beat INCR burst)
--  * ONE data register (wdata_r) acts as both WDATA output and LFSR state
--  * Seed is inserted into LSBs of an all-zero init word
entity tg_write_datapath is
  generic (
    p_USE_HAMMING               : boolean := c_ENABLE_TG_HAMMING_PROTECTION;
    p_USE_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TG_HAMMING_DOUBLE_DETECT;
    p_USE_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TG_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- from controller
    seed_pulse_i      : in std_logic;
    wbeat_pulse_i     : in std_logic;

    -- AXI constant fields (write address)
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);

    -- write data
    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic;

    -- observation
    correct_enable_i : in  std_logic;
    single_err_o     : out std_logic;
    double_err_o     : out std_logic;
    ham_buffer_enc_data_o : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end tg_write_datapath;

architecture rtl of tg_write_datapath is
  -- Stored payload/LFSR state (optionally protected by Hamming register)
  signal wdata_r  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal single_err_w : std_logic;
  signal double_err_w : std_logic;
  -- Not used externally; handy for debug visibility if you ever need it.
  signal enc_state_w  : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal init_value_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_input_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_next_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal do_step_w : std_logic;
begin
  -- Constant fields
  AWADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  AWID    <= (others => '0');
  AWLEN   <= x"00";      -- 1 beat
  AWBURST <= "01";      -- INCR

  -- Single beat
  WLAST <= '1';

  -- Payload comes from the state register
  WDATA <= wdata_r;

  -- Controller provides a single-cycle seed pulse (only once after reset)
  do_step_w <= wbeat_pulse_i;

  -- Init value = all zeros, with seed in low bits
  process(all)
    variable v : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  begin
    v := (others => '0');
    if c_AXI_DATA_WIDTH >= 32 then
      v(31 downto 0) := STARTING_SEED;
    else
      v(c_AXI_DATA_WIDTH-1 downto 0) := STARTING_SEED(c_AXI_DATA_WIDTH-1 downto 0);
    end if;
    init_value_w <= v;
  end process;

  -- Feed init value only when seeding; otherwise feed the current (decoded) state.
  lfsr_input_w <= init_value_w when (seed_pulse_i = '1') else wdata_r;

  u_LFSR: entity work.tg_write_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      data_i => lfsr_input_w,
      next_o => lfsr_next_w
    );

  -- Optional Hamming-protected state register.
  -- The decoded output is used as both WDATA and feedback into the LFSR.
  u_STATE_REG : entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_DATA_WIDTH,
      HAMMING_ENABLE => p_USE_HAMMING,
      DETECT_DOUBLE  => p_USE_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_AXI_DATA_WIDTH-1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => correct_enable_i,
      write_en_i   => (seed_pulse_i or do_step_w),
      data_i       => lfsr_next_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => single_err_w,
      double_err_o => double_err_w,
      enc_data_o   => enc_state_w,
      data_o       => wdata_r
    );

  -- observation outputs
  single_err_o <= single_err_w;
  double_err_o <= double_err_w;
  ham_buffer_enc_data_o <= enc_state_w;

end rtl;
