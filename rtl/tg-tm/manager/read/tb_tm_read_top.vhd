library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- TB for tm_read_top (minimal comparator output).
--
-- Runs 5 *separate* read transactions.
-- Each transaction:
--   * AR handshake
--   * 1 R beat with RLAST=1
-- Compares against TB-generated LFSR expected sequence (same tm_read_lfsr core).
-- Injects a mismatch on transaction #3 to show o_mismatch assertion (sticky).
entity tb_tm_read_top is
end entity;

architecture tb of tb_tm_read_top is
  constant CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- DUT control
  signal i_start       : std_logic := '0';
  signal o_done        : std_logic;
  signal INPUT_ADDRESS : std_logic_vector(63 downto 0) := (others => '0');
  signal STARTING_SEED : std_logic_vector(31 downto 0) := x"1234ABCD";

  -- AXI read address
  signal ARID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal ARADDR  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal ARLEN   : std_logic_vector(7 downto 0);
  signal ARBURST : std_logic_vector(1 downto 0);
  signal ARVALID : std_logic;
  signal ARREADY : std_logic := '0';

  -- AXI read data
  signal RVALID : std_logic := '0';
  signal RREADY : std_logic;
  signal RDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal RLAST  : std_logic := '0';

  -- Unused inputs
  signal RID   : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal RRESP : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

  -- DUT outputs
  signal o_mismatch       : std_logic;
  signal o_expected_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  -- TB-side expected sequence generation
  constant P_INIT_VALUE : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  signal tb_expected   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal tb_next       : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

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
  -- clock
  ACLK <= not ACLK after CLK_PERIOD/2;

  -- DUT
  dut: entity work.tm_read_top
    generic map(
      p_INIT_VALUE => P_INIT_VALUE
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => o_done,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      ARID    => ARID,
      ARADDR  => ARADDR,
      ARLEN   => ARLEN,
      ARBURST => ARBURST,
      ARVALID => ARVALID,
      ARREADY => ARREADY,

      RVALID => RVALID,
      RREADY => RREADY,
      RDATA  => RDATA,
      RLAST  => RLAST,

      RID   => RID,
      RRESP => RRESP,

      o_mismatch       => o_mismatch,
      o_expected_value => o_expected_value
    );

  -- TB LFSR core (same as DUT uses) to generate next(expected)
  tb_lfsr: entity work.tm_read_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      i_value => tb_expected,
      o_next  => tb_next
    );

  stimulus: process
    procedure wait_cycles(n : natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(ACLK);
      end loop;
    end procedure;

    procedure pulse_start is
    begin
      i_start <= '1';
      wait until rising_edge(ACLK);
      i_start <= '0';
    end procedure;

    procedure handshake_ar is
    begin
      while ARVALID = '0' loop
        wait until rising_edge(ACLK);
      end loop;

      ARREADY <= '1';
      wait until rising_edge(ACLK);
      ARREADY <= '0';

      report "AR accepted. ARADDR=" & to_hstring(ARADDR) &
             " ARLEN=" & to_hstring(ARLEN) &
             " ARBURST=" & to_hstring(ARBURST);
    end procedure;

    procedure drive_single_rbeat(txn_idx : natural; inject_mismatch : boolean) is
      variable send_word : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
      variable one : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    begin
      one := (others => '0');
      one(0) := '1';

      -- wait until DUT is ready to accept a beat
      while RREADY = '0' loop
        wait until rising_edge(ACLK);
      end loop;

      -- sanity check: expected alignment
      assert o_expected_value = tb_expected
        report "DUT expected != TB expected BEFORE txn " & integer'image(txn_idx) &
               " tb=" & to_hstring(tb_expected) &
               " dut=" & to_hstring(o_expected_value)
        severity error;

      if inject_mismatch then
        send_word := tb_expected xor one;
      else
        send_word := tb_expected;
      end if;

      -- present 1-beat response (RLAST=1)
      RDATA  <= send_word;
      RVALID <= '1';
      RLAST  <= '1';

      report "TXN " & integer'image(txn_idx) &
             " send=" & to_hstring(send_word) &
             " expected=" & to_hstring(tb_expected) &
             " inject_mismatch=" & boolean'image(inject_mismatch) &
             " mismatch_flag_before=" & std_logic'image(o_mismatch);

      -- handshake occurs on this cycle (RREADY already high)
      wait until rising_edge(ACLK);

      RVALID <= '0';
      RLAST  <= '0';

      -- advance TB expected for next txn (expected <= next(expected))
      tb_expected <= tb_next;

      -- mismatch flag expectation:
      if txn_idx < 3 then
        assert o_mismatch = '0'
          report "o_mismatch asserted too early at txn " & integer'image(txn_idx)
          severity error;
      else
        assert o_mismatch = '1'
          report "o_mismatch not asserted at/after injected mismatch (txn " & integer'image(txn_idx) & ")"
          severity error;
      end if;

      -- optional: observe done pulse (should pulse after accepting RLAST beat)
      -- wait a couple cycles so we can see it if desired
      wait_cycles(1);
    end procedure;

  begin
    -- reset
    INPUT_ADDRESS <= x"0000000000001000";
    ARESETn <= '0';
    i_start <= '0';
    RVALID  <= '0';
    RLAST   <= '0';
    ARREADY <= '0';
    wait_cycles(5);
    ARESETn <= '1';
    wait_cycles(3);

    -- Initialize TB expected:
    -- DUT does expected = next(init_with_seed) on the FIRST transaction start.
    tb_expected <= apply_seed(P_INIT_VALUE, STARTING_SEED);
    wait until rising_edge(ACLK);
    tb_expected <= tb_next; -- first expected word
    wait until rising_edge(ACLK);

    -- Run 5 transactions, each with 1 R beat (RLAST=1)
    for txn in 1 to 5 loop
      report "---- START TXN " & integer'image(txn) & " ----";
      pulse_start;
      handshake_ar;
      drive_single_rbeat(txn, (txn = 3));
      wait_cycles(3); -- gap between transactions
    end loop;

    report "Finished. o_mismatch=" & std_logic'image(o_mismatch);
    wait;
  end process;
end architecture;
