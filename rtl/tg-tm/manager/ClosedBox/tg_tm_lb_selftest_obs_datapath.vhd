library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Datapath slice for closed-box self-test observation block.
-- Keeps only static vectors (addr/seed) and mismatch sticky status.
entity tg_tm_lb_selftest_obs_datapath is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_sample_mismatch : in  std_logic;
    i_tm_lfsr_comparison_mismatch : in  std_logic;

    o_tg_addr : out std_logic_vector(63 downto 0);
    o_tg_seed : out std_logic_vector(31 downto 0);
    o_tm_addr : out std_logic_vector(63 downto 0);
    o_tm_seed : out std_logic_vector(31 downto 0);
    o_error   : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_datapath is
  constant c_SEED_INIT : unsigned(31 downto 0) := to_unsigned(16#1ACEB00C#, 32);
  signal r_error : std_logic := '0';
begin
  o_tg_addr <= (others => '0');
  o_tm_addr <= (others => '0');
  o_tg_seed <= std_logic_vector(c_SEED_INIT);
  o_tm_seed <= std_logic_vector(c_SEED_INIT);
  o_error   <= r_error;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_error <= '0';
      else
        if (i_sample_mismatch = '1') and (i_tm_lfsr_comparison_mismatch = '1') then
          r_error <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
