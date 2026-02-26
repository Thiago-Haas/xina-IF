library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Ultra-small payload generator.
-- Goal: minimize LUTs *and* registers.
--  * Only ONE small state register (default 8-bit LFSR)
--  * No extra payload/index registers
--  * Output word spreads the changing bits across the 32-bit word using
--    simple bit-rotations (mostly wiring, very low LUT)
--
-- Notes:
--  * Sequence advances only on i_step_pulse (handshake pulse)
--  * Re-initializes on i_init_pulse (typically txn_start)
entity tg_write_lfsr is
  generic(
    p_LFSR_BITS  : positive := 8;
    -- Kept only for backward compatibility with older instantiations.
    -- This optimized version does NOT implement a registered index anymore.
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

architecture rtl of tg_write_lfsr is
  -- Keep it intentionally tiny.
  signal r_lfsr : std_logic_vector(p_LFSR_BITS - 1 downto 0) := (others => '0');

  signal w_fb   : std_logic;

  -- helper: force bit0 to '1' so we never load all-zeros (avoids lock-up)
  function seed_to_lfsr(s : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v : std_logic_vector(p_LFSR_BITS - 1 downto 0);
  begin
    v := s(p_LFSR_BITS - 1 downto 0);
    v(0) := '1';
    return v;
  end function;
begin
  -- Keep taps fixed for 8-bit to avoid generic polynomial logic.
  -- Polynomial: x^8 + x^6 + x^5 + x^4 + 1 (max-length for 8-bit)
  -- fb = b7 xor b5 xor b4 xor b3
  g_taps_8: if p_LFSR_BITS = 8 generate
    w_fb <= r_lfsr(7) xor r_lfsr(5) xor r_lfsr(4) xor r_lfsr(3);
  end generate;

  g_taps_other: if p_LFSR_BITS /= 8 generate
    -- Fallback (not max-length, but still a valid tiny shifter): fb = MSB xor bit1
    w_fb <= r_lfsr(p_LFSR_BITS-1) xor r_lfsr(1);
  end generate;

  -- Output packing:
  -- Spread the changing bits across the word with byte-wise rotations.
  -- This keeps switching activity across the bus without extra registers.
  p_pack: process(all)
    variable v  : std_logic_vector(p_OUT_WIDTH - 1 downto 0);
    variable b  : std_logic_vector(7 downto 0);
    variable b0 : std_logic_vector(7 downto 0);
    variable b1 : std_logic_vector(7 downto 0);
    variable b2 : std_logic_vector(7 downto 0);
    variable b3 : std_logic_vector(7 downto 0);
  begin
    v := (others => '0');

    -- Base 8-bit value from the LFSR state (truncate/zero-extend if needed)
    b := (others => '0');
    if p_LFSR_BITS >= 8 then
      b := r_lfsr(7 downto 0);
    else
      b(p_LFSR_BITS - 1 downto 0) := r_lfsr;
    end if;

    -- Pure wiring rotations
    b0 := b(6 downto 0) & b(7);                -- rotl1
    b1 := b(5 downto 0) & b(7 downto 6);       -- rotl2
    b2 := b(4 downto 0) & b(7 downto 5);       -- rotl3
    b3 := b;                                   -- raw

    -- Place bytes so the raw LFSR bits are not always the lowest byte.
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

  -- State update
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
