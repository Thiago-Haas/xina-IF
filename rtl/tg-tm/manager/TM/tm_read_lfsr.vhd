library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Ultra-small LFSR + index generator for TM expected payload.
-- Must match tg_write_lfsr bit-for-bit.
entity tm_read_lfsr is
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

architecture rtl of tm_read_lfsr is
  signal r_lfsr : std_logic_vector(p_LFSR_BITS - 1 downto 0) := (others => '0');
  signal r_idx  : unsigned(p_INDEX_BITS - 1 downto 0) := (others => '0');

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

  p_pack: process(all)
    variable v         : std_logic_vector(p_OUT_WIDTH - 1 downto 0);
    variable v_idx_slv : std_logic_vector(p_INDEX_BITS - 1 downto 0);
    constant C_PAYLOAD_BITS : integer := p_LFSR_BITS + p_INDEX_BITS;
  begin
    v := (others => '0');
    v_idx_slv := std_logic_vector(r_idx);
    v(p_LFSR_BITS-1 downto 0) := r_lfsr;

    if C_PAYLOAD_BITS <= p_OUT_WIDTH then
      v(C_PAYLOAD_BITS-1 downto p_LFSR_BITS) := std_logic_vector(r_idx);
    else
      v(p_OUT_WIDTH-1 downto p_LFSR_BITS) := v_idx_slv(p_OUT_WIDTH-1 - p_LFSR_BITS downto 0);
    end if;

    o_word <= v;
  end process;

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
          r_idx  <= r_idx + 1;
        end if;
      end if;
    end if;
  end process;
end rtl;
