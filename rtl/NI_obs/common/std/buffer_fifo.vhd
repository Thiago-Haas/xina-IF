library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity buffer_fifo is
    generic (
        p_DATA_WIDTH  : positive := 32;
        p_BUFFER_DEPTH: positive := 4
    );
    port (
        ACLK   : in std_logic;
        ARESET : in std_logic;

        -- Read
        READ_i   : in std_logic;
        READ_OK_o: out std_logic;
        DATA_o   : out std_logic_vector(p_DATA_WIDTH - 1 downto 0);

        -- Write.
        WRITE_i   : in std_logic;
        DATA_i    : in std_logic_vector(p_DATA_WIDTH - 1 downto 0);
        WRITE_OK_o: out std_logic
    );
end buffer_fifo;

architecture rtl of buffer_fifo is

  type FIFO_TYPE is array (p_BUFFER_DEPTH - 1 downto 0) of std_logic_vector(p_DATA_WIDTH - 1 downto 0);
  signal FIFO_r_w    : FIFO_TYPE;
  signal READ_PTR_w: unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0) := (others => '0');

begin
    process (all)
        variable var_READ_PTR: unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0) := (others => '0');
    begin
        if (ARESET = '1') then
            READ_PTR_w <= (others => '0');
        elsif (rising_edge(ACLK)) then
            var_READ_PTR := READ_PTR_w;

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

            READ_PTR_w <= var_READ_PTR;
        end if;

        if (var_READ_PTR /= 0) then READ_OK_o <= '1'; else READ_OK_o <= '0'; end if;
        if (var_READ_PTR /= p_BUFFER_DEPTH) then WRITE_OK_o <= '1'; else WRITE_OK_o <= '0'; end if;

        if (to_integer(var_READ_PTR) = 0) then
            DATA_o <= FIFO_r_w(to_integer(var_READ_PTR));
        else
            DATA_o <= FIFO_r_w(to_integer(var_READ_PTR - 1));
        end if;
    end process;
end rtl;