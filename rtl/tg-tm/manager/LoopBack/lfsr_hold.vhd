library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lfsr_hold is
  generic(
    p_MAX_WORDS : natural := 256
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_wr_en   : in  std_logic;
    i_wr_addr : in  unsigned(15 downto 0);
    i_wr_data : in  std_logic_vector(31 downto 0);

    i_rd_addr : in  unsigned(15 downto 0);
    o_rd_data : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of lfsr_hold is
  type t_mem is array (0 to p_MAX_WORDS-1) of std_logic_vector(31 downto 0);
  signal mem : t_mem := (others => (others => '0'));
  signal r_rd_data : std_logic_vector(31 downto 0) := (others => '0');
begin
  o_rd_data <= r_rd_data;

  process(ACLK)
    variable waddr : integer;
    variable raddr : integer;
  begin
    if rising_edge(ACLK) then
      if ARESETn='0' then
        r_rd_data <= (others=>'0');
      else
        if i_wr_en='1' then
          waddr := to_integer(i_wr_addr);
          if waddr >= 0 and waddr < p_MAX_WORDS then
            mem(waddr) <= i_wr_data;
          end if;
        end if;

        raddr := to_integer(i_rd_addr);
        if raddr >= 0 and raddr < p_MAX_WORDS then
          r_rd_data <= mem(raddr);
        else
          r_rd_data <= (others=>'0');
        end if;
      end if;
    end if;
  end process;
end rtl;