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
    i_READ    : in  std_logic;
    o_READ_OK : out std_logic;
    o_DATA    : out std_logic_vector(p_DATA_WIDTH - 1 downto 0);

    -- Write
    i_WRITE    : in  std_logic;
    i_DATA     : in  std_logic_vector(p_DATA_WIDTH - 1 downto 0);
    o_WRITE_OK : out std_logic;

    -- ERROR INJECTION (DEBUG)
    i_INJECT_EN   : in  std_logic := '0';
    i_INJECT_IDX  : in  integer   := 0;  -- 0..p_BUFFER_DEPTH-1
    i_INJECT_MASK : in  std_logic_vector(p_DATA_WIDTH - 1 downto 0) := (others => '0')
  );
end buffer_fifo_debug;

architecture rtl of buffer_fifo_debug is

  type FIFO_TYPE is array (p_BUFFER_DEPTH - 1 downto 0) of std_logic_vector(p_DATA_WIDTH - 1 downto 0);
  signal w_FIFO_r : FIFO_TYPE;

  signal w_READ_PTR : unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0) := (others => '0');

begin

  process (all)
    variable var_READ_PTR : unsigned(w_READ_PTR'range) := (others => '0');
    variable inj_idx_v    : integer;
  begin
    var_READ_PTR := w_READ_PTR;

    if (ARESET = '1') then
      w_READ_PTR <= (others => '0');

    elsif rising_edge(ACLK) then

      -- normal FIFO behavior
      if (i_WRITE = '1' and var_READ_PTR /= p_BUFFER_DEPTH) then
        w_FIFO_r(0) <= i_DATA;

        for i in 1 to p_BUFFER_DEPTH - 1 loop
          w_FIFO_r(i) <= w_FIFO_r(i - 1);
        end loop;

        if not (i_READ = '1' and w_READ_PTR /= 0) then
          var_READ_PTR := var_READ_PTR + 1;
        end if;

      elsif (i_READ = '1' and w_READ_PTR /= 0) then
        var_READ_PTR := var_READ_PTR - 1;
      end if;

      -- ERROR INJECTION (after normal update)
      if i_INJECT_EN = '1' then
        inj_idx_v := i_INJECT_IDX;
        if (inj_idx_v >= 0) and (inj_idx_v < integer(p_BUFFER_DEPTH)) then
          w_FIFO_r(inj_idx_v) <= w_FIFO_r(inj_idx_v) xor i_INJECT_MASK;
        end if;
      end if;

      w_READ_PTR <= var_READ_PTR;
    end if;

    -- combinational outputs based on var_READ_PTR
    if (var_READ_PTR /= 0) then o_READ_OK <= '1'; else o_READ_OK <= '0'; end if;
    if (var_READ_PTR /= p_BUFFER_DEPTH) then o_WRITE_OK <= '1'; else o_WRITE_OK <= '0'; end if;

    if (to_integer(var_READ_PTR) = 0) then
      o_DATA <= w_FIFO_r(0);
    else
      o_DATA <= w_FIFO_r(to_integer(var_READ_PTR - 1));
    end if;

  end process;

end rtl;
