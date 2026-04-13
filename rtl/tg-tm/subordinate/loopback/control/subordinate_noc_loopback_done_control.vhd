library IEEE;
use IEEE.std_logic_1164.all;

entity subordinate_noc_loopback_done_control is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i    : in  std_logic;
    gen_done_i : in  std_logic;
    mon_done_i : in  std_logic;

    done_o : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_loopback_done_control is
  signal gen_done_seen_r : std_logic := '0';
  signal mon_done_seen_r : std_logic := '0';
begin
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        gen_done_seen_r <= '0';
        mon_done_seen_r <= '0';
      elsif start_i = '1' then
        gen_done_seen_r <= '0';
        mon_done_seen_r <= '0';
      else
        if gen_done_i = '1' then
          gen_done_seen_r <= '1';
        end if;
        if mon_done_i = '1' then
          mon_done_seen_r <= '1';
        end if;
      end if;
    end if;
  end process;

  done_o <= gen_done_seen_r and mon_done_seen_r;
end architecture;
