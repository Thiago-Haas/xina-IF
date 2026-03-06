library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Aggressive resource-minimized write datapath:
--  * NO external override ports
--  * NO init-value generic / no helper functions
--  * AW fields are constants (single-beat INCR burst)
--  * ONE data register (r_wdata) acts as both WDATA output and LFSR state
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
    i_seed_pulse      : in std_logic;
    i_wbeat_pulse     : in std_logic;

    -- AXI constant fields (write address)
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);

    -- write data
    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic;

    -- observation
    i_correct_enable : in  std_logic;
    o_single_err     : out std_logic;
    o_double_err     : out std_logic;
    o_ham_buffer_enc_data : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end tg_write_datapath;

architecture rtl of tg_write_datapath is
  -- Stored payload/LFSR state (optionally protected by Hamming register)
  signal r_wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal w_single_err : std_logic;
  signal w_double_err : std_logic;
  -- Not used externally; handy for debug visibility if you ever need it.
  signal w_enc_state  : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal w_init_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_input : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_next  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal w_do_step : std_logic;
begin
  -- Constant fields
  AWADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  AWID    <= (others => '0');
  AWLEN   <= x"00";      -- 1 beat
  AWBURST <= "01";      -- INCR

  -- Single beat
  WLAST <= '1';

  -- Payload comes from the state register
  WDATA <= r_wdata;

  -- Controller provides a single-cycle seed pulse (only once after reset)
  w_do_step <= i_wbeat_pulse;

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
    w_init_value <= v;
  end process;

  -- Feed init value only when seeding; otherwise feed the current (decoded) state.
  w_lfsr_input <= w_init_value when (i_seed_pulse = '1') else r_wdata;

  u_LFSR: entity work.tg_write_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      i_data => w_lfsr_input,
      o_next => w_lfsr_next
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
      correct_en_i => i_correct_enable,
      write_en_i   => (i_seed_pulse or w_do_step),
      data_i       => w_lfsr_next,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => w_single_err,
      double_err_o => w_double_err,
      enc_data_o   => w_enc_state,
      data_o       => r_wdata
    );

  -- observation outputs
  o_single_err <= w_single_err;
  o_double_err <= w_double_err;
  o_ham_buffer_enc_data <= w_enc_state;

end rtl;
