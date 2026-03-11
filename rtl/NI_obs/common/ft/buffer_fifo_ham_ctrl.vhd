library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity buffer_fifo_ham_ctrl is
  generic (
    p_BUFFER_DEPTH : positive := 4
  );
  port (
    ACLK   : in std_logic;
    ARESET : in std_logic;

    i_WRITE_REQ : in std_logic;
    i_READ_REQ  : in std_logic;

    o_STAGE_VALID  : out std_logic;
    o_STAGE_LOAD   : out std_logic;
    o_STAGE_PUSH   : out std_logic;
    o_FIFO_DO_WRITE: out std_logic;
    o_FIFO_DO_READ : out std_logic;
    o_FIFO_WRITE_OK: out std_logic;
    o_FIFO_READ_OK : out std_logic;
    o_FIFO_COUNT   : out unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0)
  );
end entity;

architecture rtl of buffer_fifo_ham_ctrl is
  signal stage_valid_r : std_logic := '0';
  signal fifo_count_r  : unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0) := (others => '0');

  signal w_fifo_write_ok : std_logic;
  signal w_fifo_read_ok  : std_logic;
  signal w_stage_load    : std_logic;
  signal w_stage_push    : std_logic;
  signal w_fifo_do_write : std_logic;
  signal w_fifo_do_read  : std_logic;
begin
  w_fifo_read_ok  <= '1' when (fifo_count_r /= 0) else '0';
  w_fifo_write_ok <= '1' when (fifo_count_r /= p_BUFFER_DEPTH) else '0';

  w_stage_load    <= i_WRITE_REQ and (not stage_valid_r);
  w_stage_push    <= stage_valid_r and w_fifo_write_ok;
  w_fifo_do_write <= w_stage_push;
  w_fifo_do_read  <= i_READ_REQ and w_fifo_read_ok;

  o_STAGE_VALID   <= stage_valid_r;
  o_STAGE_LOAD    <= w_stage_load;
  o_STAGE_PUSH    <= w_stage_push;
  o_FIFO_DO_WRITE <= w_fifo_do_write;
  o_FIFO_DO_READ  <= w_fifo_do_read;
  o_FIFO_WRITE_OK <= w_fifo_write_ok;
  o_FIFO_READ_OK  <= w_fifo_read_ok;
  o_FIFO_COUNT    <= fifo_count_r;

  p_ctrl : process (ACLK, ARESET)
    variable v_count : unsigned(fifo_count_r'range);
  begin
    if ARESET = '1' then
      stage_valid_r <= '0';
      fifo_count_r  <= (others => '0');
    elsif rising_edge(ACLK) then
      if w_stage_load = '1' then
        stage_valid_r <= '1';
      elsif w_stage_push = '1' then
        stage_valid_r <= '0';
      end if;

      v_count := fifo_count_r;
      if (w_fifo_do_write = '1') and (w_fifo_do_read = '0') then
        v_count := v_count + 1;
      elsif (w_fifo_do_write = '0') and (w_fifo_do_read = '1') then
        v_count := v_count - 1;
      end if;
      fifo_count_r <= v_count;
    end if;
  end process;
end architecture;

