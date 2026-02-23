library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Read-phase datapath (minimal compare):
--  * One register BEFORE the LFSR (r_lfsr_in)
--  * One register AFTER  the LFSR (r_expected)  => expected RDATA
--  * Feedback uses expected value (r_expected) to update r_lfsr_in
--  * Comparator is encapsulated in tm_read_compare and outputs ONLY a sticky mismatch flag
--
-- Initialization (mirrors TG):
--  r_lfsr_in starts from p_INIT_VALUE, with its lower 32 bits overwritten by STARTING_SEED.
--  r_expected is precomputed as next_lfsr(r_lfsr_in) so it is ready when the first R beat arrives.
entity tm_read_datapath is
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

    -- debug (post-LFSR reg = expected value)
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tm_read_datapath;

architecture rtl of tm_read_datapath is
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
  o_expected_value <= r_expected;

  -- Build init value = base/random generic + seed in lower bits
  w_init_value <= apply_seed(p_INIT_VALUE, STARTING_SEED);

  -- Same behavior as TG: seed only once after reset, on first transaction start
  w_do_init <= i_txn_start_pulse and (not r_seeded);
  w_do_step <= i_rbeat_pulse;

  -- LFSR input:
  --  * init: feed init value, compute expected = next(init)
  --  * step: feed current expected, compute next expected = next(expected)
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

  -- Encapsulated minimal comparison (single sticky mismatch register)
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
          r_lfsr_in  <= w_init_value; -- LFSR(in) reg
          r_expected <= w_lfsr_next;  -- LFSR(out) reg = expected word
        elsif w_do_step = '1' then
          -- feedback uses expected value (keeps TM sequence independent of RDATA)
          r_lfsr_in  <= r_expected;
          r_expected <= w_lfsr_next;
        end if;
      end if;
    end if;
  end process;
end rtl;
