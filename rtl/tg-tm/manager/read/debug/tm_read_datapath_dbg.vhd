library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Read-phase datapath with debug taps.
entity tm_read_datapath_dbg is
  generic(
    p_ARID      : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    p_LEN       : std_logic_vector(7 downto 0) := x"00";
    p_BURST     : std_logic_vector(1 downto 0) := "01";
    p_INIT_VALUE: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0')
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- from controller
    i_txn_start_pulse : in std_logic;
    i_rbeat_pulse     : in std_logic;

    -- from AXI read data channel
    RDATA : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- AXI constant fields (read address)
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);

    -- minimal comparator output
    o_mismatch : out std_logic;

    -- legacy debug (expected value)
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- ------------------------------------------------------------
    -- Debug taps
    -- ------------------------------------------------------------
    o_dbg_seeded       : out std_logic;
    o_dbg_do_init      : out std_logic;
    o_dbg_do_step      : out std_logic;
    o_dbg_init_value   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_lfsr_input   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_lfsr_next    : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_lfsr_in_reg  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_dbg_expected_reg : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tm_read_datapath_dbg;

architecture rtl of tm_read_datapath_dbg is
  signal r_lfsr_in   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal r_expected  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal r_seeded    : std_logic := '0';

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

  -- legacy debug
  o_expected_value <= r_expected;

  -- init value
  w_init_value <= apply_seed(p_INIT_VALUE, STARTING_SEED);

  w_do_init <= i_txn_start_pulse and (not r_seeded);
  w_do_step <= i_rbeat_pulse;

  w_lfsr_input <= w_init_value when (w_do_init = '1') else
                  r_expected  when (w_do_step = '1') else
                  r_lfsr_in;

  u_LFSR: entity work.tm_read_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      i_value => w_lfsr_input,
      o_next  => w_lfsr_next
    );

  u_CMP: entity work.tm_read_compare
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Clear mismatch every transaction start (even when not reseeding)
      i_init_pulse  => i_txn_start_pulse,
      i_check_pulse => w_do_step,

      i_expected => r_expected,
      i_rdata    => RDATA,

      o_mismatch => o_mismatch
    );

  -- debug taps
  o_dbg_seeded       <= r_seeded;
  o_dbg_do_init      <= w_do_init;
  o_dbg_do_step      <= w_do_step;
  o_dbg_init_value   <= w_init_value;
  o_dbg_lfsr_input   <= w_lfsr_input;
  o_dbg_lfsr_next    <= w_lfsr_next;
  o_dbg_lfsr_in_reg  <= r_lfsr_in;
  o_dbg_expected_reg <= r_expected;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_seeded   <= '0';
        r_lfsr_in  <= (others => '0');
        r_expected <= (others => '0');
      else
        if w_do_init = '1' then
          r_seeded   <= '1';
          r_lfsr_in  <= w_init_value;
          r_expected <= w_lfsr_next;
        elsif w_do_step = '1' then
          r_lfsr_in  <= r_expected;
          r_expected <= w_lfsr_next;
        end if;
      end if;
    end if;
  end process;
end rtl;
