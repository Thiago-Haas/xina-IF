library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Single-word LFSR hold register (32-bit).
-- Keeps the same interface as before for drop-in compatibility.
-- i_wr_addr, i_rd_addr and p_MAX_WORDS are ignored.
entity lfsr_hold is
  generic(
    p_MAX_WORDS : natural := 256  -- kept for compatibility (unused)
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_wr_en   : in  std_logic;
    i_wr_addr : in  unsigned(15 downto 0); -- unused
    i_wr_data : in  std_logic_vector(31 downto 0);

    i_rd_addr : in  unsigned(15 downto 0); -- unused
    o_rd_data : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of lfsr_hold is
  signal r_hold : std_logic_vector(31 downto 0) := (others => '0');
begin
  -- No extra register: read is directly the stored word
  o_rd_data <= r_hold;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_hold <= (others => '0');
      else
        if i_wr_en = '1' then
          r_hold <= i_wr_data; -- overwrite with latest payload
        end if;
      end if;
    end if;
  end process;

end rtl;