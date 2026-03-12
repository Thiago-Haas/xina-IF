library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity buffer_fifo_debug is
  generic (
    p_DATA_WIDTH   : positive := 32;
    p_BUFFER_DEPTH : positive := 4
  );
  port (
    ACLK   : in std_logic;
    ARESET : in std_logic;

    -- Read
    READ_i    : in  std_logic;
    READ_OK_o : out std_logic;
    DATA_o    : out std_logic_vector(p_DATA_WIDTH - 1 downto 0);

    -- Write
    WRITE_i    : in  std_logic;
    DATA_i     : in  std_logic_vector(p_DATA_WIDTH - 1 downto 0);
    WRITE_OK_o : out std_logic;

    -- ERROR INJECTION (DEBUG)
    INJECT_EN_i   : in  std_logic := '0';
    INJECT_IDX_i  : in  integer   := 0;  -- 0..p_BUFFER_DEPTH-1
    INJECT_MASK_i : in  std_logic_vector(p_DATA_WIDTH - 1 downto 0) := (others => '0')
  );
end buffer_fifo_debug;

architecture rtl of buffer_fifo_debug is

  type FIFO_TYPE is array (p_BUFFER_DEPTH - 1 downto 0) of std_logic_vector(p_DATA_WIDTH - 1 downto 0);
  signal FIFO_r_w : FIFO_TYPE;

  signal READ_PTR_w : unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0) := (others => '0');

begin

  process (all)
    variable var_READ_PTR : unsigned(READ_PTR_w'range) := (others => '0');
    variable inj_idx_v    : integer;
  begin
    var_READ_PTR := READ_PTR_w;

    if (ARESET = '1') then
      READ_PTR_w <= (others => '0');

    elsif rising_edge(ACLK) then

      -- normal FIFO behavior
      if (WRITE_i = '1' and var_READ_PTR /= p_BUFFER_DEPTH) then
        FIFO_r_w(0) <= DATA_i;

        for i in 1 to p_BUFFER_DEPTH - 1 loop
          FIFO_r_w(i) <= FIFO_r_w(i - 1);
        end loop;

        if not (READ_i = '1' and READ_PTR_w /= 0) then
          var_READ_PTR := var_READ_PTR + 1;
        end if;

      elsif (READ_i = '1' and READ_PTR_w /= 0) then
        var_READ_PTR := var_READ_PTR - 1;
      end if;

      -- ERROR INJECTION (after normal update)
      if INJECT_EN_i = '1' then
        inj_idx_v := INJECT_IDX_i;
        if (inj_idx_v >= 0) and (inj_idx_v < integer(p_BUFFER_DEPTH)) then
          FIFO_r_w(inj_idx_v) <= FIFO_r_w(inj_idx_v) xor INJECT_MASK_i;
        end if;
      end if;

      READ_PTR_w <= var_READ_PTR;
    end if;

    -- combinational outputs based on var_READ_PTR
    if (var_READ_PTR /= 0) then READ_OK_o <= '1'; else READ_OK_o <= '0'; end if;
    if (var_READ_PTR /= p_BUFFER_DEPTH) then WRITE_OK_o <= '1'; else WRITE_OK_o <= '0'; end if;

    if (to_integer(var_READ_PTR) = 0) then
      DATA_o <= FIFO_r_w(0);
    else
      DATA_o <= FIFO_r_w(to_integer(var_READ_PTR - 1));
    end if;

  end process;

end rtl;
