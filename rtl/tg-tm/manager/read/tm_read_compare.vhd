library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Comparator / scoreboard block for TM.
-- Encapsulates the comparison between incoming RDATA and the expected LFSR word.
--
-- Behavior:
--  * On reset or i_init_pulse: clears mismatch counter, sets sticky match to '1'
--  * On each i_check_pulse: compares i_rdata vs i_expected
--      - o_last_match updates with that result
--      - o_match_sticky stays '1' only if all checks matched since last init
--      - o_mismatch_cnt increments on mismatches
entity tm_read_compare is
  generic(
    p_WIDTH : positive := 32
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_init_pulse  : in std_logic; -- re-arm / clear stats
    i_check_pulse : in std_logic; -- do comparison on this cycle (typically RVALID&RREADY)

    i_expected : in std_logic_vector(p_WIDTH - 1 downto 0);
    i_rdata    : in std_logic_vector(p_WIDTH - 1 downto 0);

    o_match_sticky : out std_logic;
    o_last_match   : out std_logic;
    o_mismatch_cnt : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of tm_read_compare is
  signal r_match_sticky : std_logic := '1';
  signal r_last_match   : std_logic := '1';
  signal r_mismatch_cnt : unsigned(15 downto 0) := (others => '0');
begin
  o_match_sticky <= r_match_sticky;
  o_last_match   <= r_last_match;
  o_mismatch_cnt <= r_mismatch_cnt;

  process(ACLK)
    variable v_match : std_logic;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_match_sticky <= '1';
        r_last_match   <= '1';
        r_mismatch_cnt <= (others => '0');
      else
        if i_init_pulse = '1' then
          r_match_sticky <= '1';
          r_last_match   <= '1';
          r_mismatch_cnt <= (others => '0');

        elsif i_check_pulse = '1' then
          if i_rdata = i_expected then
            v_match := '1';
          else
            v_match := '0';
          end if;

          r_last_match <= v_match;

          if v_match = '0' then
            r_match_sticky <= '0';
            r_mismatch_cnt <= r_mismatch_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;
