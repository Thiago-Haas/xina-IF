library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Tiny, LUT-cheap pseudo-random generator for TG.
-- Internals:
--   * ONE 8-bit LFSR register (r_lfsr)
--   * Re-seeded on i_init_pulse (every transaction)
--   * Advanced on i_step_pulse (every accepted data beat)
--
-- Output:
--   * Word built by spreading the 8-bit value across byte lanes using rotations (wiring-only).
--   * Byte[23:16] is the raw 8-bit LFSR value.
entity tg_write_lfsr is
  generic (
    p_OUT_WIDTH : positive := 32
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_init_pulse : in std_logic;
    i_step_pulse : in std_logic;

    i_seed  : in  std_logic_vector(31 downto 0);

    o_word  : out std_logic_vector(p_OUT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of tg_write_lfsr is
  signal r_lfsr : std_logic_vector(7 downto 0) := x"01";

  function rotl8(b : std_logic_vector(7 downto 0); sh : natural) return std_logic_vector is
    variable v : std_logic_vector(7 downto 0);
    constant s : natural := sh mod 8;
  begin
    v := b(7-s downto 0) & b(7 downto 8-s);
    return v;
  end function;

  -- 8-bit LFSR step (Fibonacci): x^8 + x^6 + x^5 + x^4 + 1
  function lfsr8_next(b : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable fb : std_logic;
    variable v  : std_logic_vector(7 downto 0);
  begin
    fb := b(7) xor b(5) xor b(4) xor b(3);
    v  := b(6 downto 0) & fb;
    return v;
  end function;

  function seed_to_byte(seed : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable x : std_logic_vector(7 downto 0);
  begin
    x := seed(7 downto 0) xor seed(15 downto 8) xor seed(23 downto 16) xor seed(31 downto 24);
    -- avoid all-zero lockup: force bit0=1
    x(0) := x(0) or '1';
    return x;
  end function;

  signal w_b0, w_b1, w_b2, w_b3 : std_logic_vector(7 downto 0);
begin

  w_b0 <= rotl8(r_lfsr, 1);
  w_b1 <= rotl8(r_lfsr, 3);
  w_b2 <= r_lfsr;
  w_b3 <= rotl8(r_lfsr, 2);

  p_pack : process(w_b0, w_b1, w_b2, w_b3)
    variable v : std_logic_vector(p_OUT_WIDTH-1 downto 0);
  begin
    v := (others => '0');
    if p_OUT_WIDTH >= 8 then
      v(7 downto 0) := w_b0;
    end if;
    if p_OUT_WIDTH >= 16 then
      v(15 downto 8) := w_b1;
    end if;
    if p_OUT_WIDTH >= 24 then
      v(23 downto 16) := w_b2;
    end if;
    if p_OUT_WIDTH >= 32 then
      v(31 downto 24) := w_b3;
    end if;
    o_word <= v;
  end process;

  process(ACLK)
    variable v_seed : std_logic_vector(7 downto 0);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_lfsr <= x"01";
      else
        if i_init_pulse = '1' then
          v_seed := seed_to_byte(i_seed);
          r_lfsr <= lfsr8_next(v_seed);  -- first output corresponds to next(seed_byte)
        elsif i_step_pulse = '1' then
          r_lfsr <= lfsr8_next(r_lfsr);
        end if;
      end if;
    end if;
  end process;

end architecture;
