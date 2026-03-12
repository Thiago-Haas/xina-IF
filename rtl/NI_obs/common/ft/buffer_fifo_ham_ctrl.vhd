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

    WRITE_REQ_i : in std_logic;
    READ_REQ_i  : in std_logic;

    STAGE_VALID_o  : out std_logic;
    STAGE_LOAD_o   : out std_logic;
    STAGE_PUSH_o   : out std_logic;
    FIFO_DO_WRITE_o: out std_logic;
    FIFO_DO_READ_o : out std_logic;
    FIFO_WRITE_OK_o: out std_logic;
    FIFO_READ_OK_o : out std_logic;
    FIFO_COUNT_o   : out unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0)
  );
end entity;

architecture rtl of buffer_fifo_ham_ctrl is
  signal stage_valid_r : std_logic := '0';
  signal fifo_count_r  : unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0) := (others => '0');

  signal fifo_write_ok_w : std_logic;
  signal fifo_read_ok_w  : std_logic;
  signal stage_load_w    : std_logic;
  signal stage_push_w    : std_logic;
  signal fifo_do_write_w : std_logic;
  signal fifo_do_read_w  : std_logic;
begin
  fifo_read_ok_w  <= '1' when (fifo_count_r /= 0) else '0';
  fifo_write_ok_w <= '1' when (fifo_count_r /= p_BUFFER_DEPTH) else '0';

  stage_load_w    <= WRITE_REQ_i and (not stage_valid_r);
  stage_push_w    <= stage_valid_r and fifo_write_ok_w;
  fifo_do_write_w <= stage_push_w;
  fifo_do_read_w  <= READ_REQ_i and fifo_read_ok_w;

  STAGE_VALID_o   <= stage_valid_r;
  STAGE_LOAD_o    <= stage_load_w;
  STAGE_PUSH_o    <= stage_push_w;
  FIFO_DO_WRITE_o <= fifo_do_write_w;
  FIFO_DO_READ_o  <= fifo_do_read_w;
  FIFO_WRITE_OK_o <= fifo_write_ok_w;
  FIFO_READ_OK_o  <= fifo_read_ok_w;
  FIFO_COUNT_o    <= fifo_count_r;

  p_ctrl : process (ACLK, ARESET)
    variable v_count : unsigned(fifo_count_r'range);
  begin
    if ARESET = '1' then
      stage_valid_r <= '0';
      fifo_count_r  <= (others => '0');
    elsif rising_edge(ACLK) then
      if stage_load_w = '1' then
        stage_valid_r <= '1';
      elsif stage_push_w = '1' then
        stage_valid_r <= '0';
      end if;

      v_count := fifo_count_r;
      if (fifo_do_write_w = '1') and (fifo_do_read_w = '0') then
        v_count := v_count + 1;
      elsif (fifo_do_write_w = '0') and (fifo_do_read_w = '1') then
        v_count := v_count - 1;
      end if;
      fifo_count_r <= v_count;
    end if;
  end process;
end architecture;

