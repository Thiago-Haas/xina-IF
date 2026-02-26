library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Ultra-small payload generator for TM expected payload.
-- Must match tg_write_lfsr bit-for-bit.
entity tm_read_lfsr is
  generic(
    p_LFSR_BITS  : positive := 8;
    -- Kept only for backward compatibility (no registered index in this version).
    p_INDEX_BITS : positive := 8;
    p_OUT_WIDTH  : positive := 32
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_init_pulse : in std_logic;
    i_step_pulse : in std_logic;

    i_seed : in  std_logic_vector(31 downto 0);

    o_word : out std_logic_vector(p_OUT_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of tm_read_lfsr is
  signal r_lfsr : std_logic_vector(p_LFSR_BITS - 1 downto 0) := (others => '0');

  signal w_fb   : std_logic;

  function seed_to_lfsr(s : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v : std_logic_vector(p_LFSR_BITS - 1 downto 0);
  begin
    v := s(p_LFSR_BITS - 1 downto 0);
    v(0) := '1';
    return v;
  end function;
begin
  -- Same taps as TG
  g_taps_8: if p_LFSR_BITS = 8 generate
    w_fb <= r_lfsr(7) xor r_lfsr(5) xor r_lfsr(4) xor r_lfsr(3);
  end generate;

  g_taps_other: if p_LFSR_BITS /= 8 generate
    w_fb <= r_lfsr(p_LFSR_BITS-1) xor r_lfsr(1);
  end generate;

  -- Same packing as TG: byte-wise rotations (mostly wiring)
  p_pack: process(all)
    variable v  : std_logic_vector(p_OUT_WIDTH - 1 downto 0);
    variable b  : std_logic_vector(7 downto 0);
    variable b0 : std_logic_vector(7 downto 0);
    variable b1 : std_logic_vector(7 downto 0);
    variable b2 : std_logic_vector(7 downto 0);
    variable b3 : std_logic_vector(7 downto 0);
  begin
    v := (others => '0');

    b := (others => '0');
    if p_LFSR_BITS >= 8 then
      b := r_lfsr(7 downto 0);
    else
      b(p_LFSR_BITS - 1 downto 0) := r_lfsr;
    end if;

    b0 := b(6 downto 0) & b(7);                -- rotl1
    b1 := b(5 downto 0) & b(7 downto 6);       -- rotl2
    b2 := b(4 downto 0) & b(7 downto 5);       -- rotl3
    b3 := b;                                   -- raw

    if p_OUT_WIDTH >= 8 then
      v(7 downto 0) := b0;
    end if;
    if p_OUT_WIDTH >= 16 then
      v(15 downto 8) := b2;
    end if;
    if p_OUT_WIDTH >= 24 then
      v(23 downto 16) := b3;
    end if;
    if p_OUT_WIDTH >= 32 then
      v(31 downto 24) := b1;
    end if;

    o_word <= v;
  end process;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_lfsr <= (others => '0');
      else
        if i_init_pulse = '1' then
          r_lfsr <= seed_to_lfsr(i_seed);
        elsif i_step_pulse = '1' then
          r_lfsr <= r_lfsr(p_LFSR_BITS-2 downto 0) & w_fb;
        end if;
      end if;
    end if;
  end process;
end rtl;
