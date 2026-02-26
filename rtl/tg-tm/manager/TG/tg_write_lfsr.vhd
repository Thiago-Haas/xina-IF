library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Ultra-small LFSR + index generator.
-- Goal: minimize LUTs and registers.
--  * LFSR width is small (default 8 bits)
--  * Index is small and wraps naturally on overflow
--  * Output word packs {idx, lfsr} in the LSBs, rest zeros (wiring-only)
--
-- Notes:
--  * Sequence advances only on i_step_pulse (handshake pulse)
--  * Re-initializes on i_init_pulse (typically txn_start)
entity tg_write_lfsr is
  generic(
    p_LFSR_BITS  : positive := 8;
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
  signal r_idx  : unsigned(p_INDEX_BITS - 1 downto 0) := (others => '0');

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

  -- Output packing: LSBs carry the changing fields, MSBs are zero.
  p_pack: process(all)
    variable v         : std_logic_vector(p_OUT_WIDTH - 1 downto 0);
    variable v_idx_slv : std_logic_vector(p_INDEX_BITS - 1 downto 0);
    constant C_PAYLOAD_BITS : integer := p_LFSR_BITS + p_INDEX_BITS;
  begin
    v := (others => '0');
    v_idx_slv := std_logic_vector(r_idx);

    -- LFSR in LSBs
    v(p_LFSR_BITS-1 downto 0) := r_lfsr;

    -- IDX above it, if it fits
    if C_PAYLOAD_BITS <= p_OUT_WIDTH then
      v(C_PAYLOAD_BITS-1 downto p_LFSR_BITS) := std_logic_vector(r_idx);
    else
      -- truncate idx if user picked something too large
      v(p_OUT_WIDTH-1 downto p_LFSR_BITS) := v_idx_slv(p_OUT_WIDTH-1 - p_LFSR_BITS downto 0);
    end if;

    o_word <= v;
  end process;

  -- State update
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_lfsr <= (others => '0');
        r_idx  <= (others => '0');
      else
        if i_init_pulse = '1' then
          r_lfsr <= seed_to_lfsr(i_seed);
          r_idx  <= (others => '0');
        elsif i_step_pulse = '1' then
          r_lfsr <= r_lfsr(p_LFSR_BITS-2 downto 0) & w_fb;
          r_idx  <= r_idx + 1; -- wraps naturally on overflow
        end if;
      end if;
    end if;
  end process;

end rtl;
