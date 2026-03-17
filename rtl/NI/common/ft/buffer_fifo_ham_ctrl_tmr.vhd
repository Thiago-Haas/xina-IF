library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity buffer_fifo_ham_ctrl_tmr is
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
    FIFO_COUNT_o   : out unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0);

    correct_enable_i : in std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of buffer_fifo_ham_ctrl_tmr is
  attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  function maj3(a, b, c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  function dis3(a, b, c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;

  function maj3_uns(a, b, c : unsigned) return unsigned is
    variable v : unsigned(a'range);
  begin
    for i in a'range loop
      v(i) := maj3(a(i), b(i), c(i));
    end loop;
    return v;
  end function;

  function dis3_uns(a, b, c : unsigned) return std_logic is
    variable e : std_logic := '0';
  begin
    for i in a'range loop
      e := e or dis3(a(i), b(i), c(i));
    end loop;
    return e;
  end function;

  type tmr_sl_t is array (0 to 2) of std_logic;
  type tmr_cnt_t is array (0 to 2) of unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0);

  signal stage_valid_w   : tmr_sl_t;
  signal stage_load_w    : tmr_sl_t;
  signal stage_push_w    : tmr_sl_t;
  signal fifo_do_write_w : tmr_sl_t;
  signal fifo_do_read_w  : tmr_sl_t;
  signal fifo_write_ok_w : tmr_sl_t;
  signal fifo_read_ok_w  : tmr_sl_t;
  signal fifo_count_w    : tmr_cnt_t;
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_ctrl : label is "TRUE";
        attribute syn_preserve of u_ctrl : label is true;
    attribute KEEP_HIERARCHY of u_ctrl : label is "TRUE";
  begin
    u_buffer_fifo_ham_ctrl: entity work.buffer_fifo_ham_ctrl
      generic map(
        p_BUFFER_DEPTH => p_BUFFER_DEPTH
      )
      port map(
        ACLK   => ACLK,
        ARESET => ARESET,
        WRITE_REQ_i => WRITE_REQ_i,
        READ_REQ_i  => READ_REQ_i,
        STAGE_VALID_o   => stage_valid_w(i),
        STAGE_LOAD_o    => stage_load_w(i),
        STAGE_PUSH_o    => stage_push_w(i),
        FIFO_DO_WRITE_o => fifo_do_write_w(i),
        FIFO_DO_READ_o  => fifo_do_read_w(i),
        FIFO_WRITE_OK_o => fifo_write_ok_w(i),
        FIFO_READ_OK_o  => fifo_read_ok_w(i),
        FIFO_COUNT_o    => fifo_count_w(i)
      );
  end generate;

  error_o <= dis3(stage_valid_w(2), stage_valid_w(1), stage_valid_w(0)) or
             dis3_uns(fifo_count_w(2), fifo_count_w(1), fifo_count_w(0));

  STAGE_VALID_o   <= maj3(stage_valid_w(2), stage_valid_w(1), stage_valid_w(0)) when correct_enable_i = '1' else stage_valid_w(0);
  STAGE_LOAD_o    <= maj3(stage_load_w(2), stage_load_w(1), stage_load_w(0)) when correct_enable_i = '1' else stage_load_w(0);
  STAGE_PUSH_o    <= maj3(stage_push_w(2), stage_push_w(1), stage_push_w(0)) when correct_enable_i = '1' else stage_push_w(0);
  FIFO_DO_WRITE_o <= maj3(fifo_do_write_w(2), fifo_do_write_w(1), fifo_do_write_w(0)) when correct_enable_i = '1' else fifo_do_write_w(0);
  FIFO_DO_READ_o  <= maj3(fifo_do_read_w(2), fifo_do_read_w(1), fifo_do_read_w(0)) when correct_enable_i = '1' else fifo_do_read_w(0);
  FIFO_WRITE_OK_o <= maj3(fifo_write_ok_w(2), fifo_write_ok_w(1), fifo_write_ok_w(0)) when correct_enable_i = '1' else fifo_write_ok_w(0);
  FIFO_READ_OK_o  <= maj3(fifo_read_ok_w(2), fifo_read_ok_w(1), fifo_read_ok_w(0)) when correct_enable_i = '1' else fifo_read_ok_w(0);
  FIFO_COUNT_o    <= maj3_uns(fifo_count_w(2), fifo_count_w(1), fifo_count_w(0)) when correct_enable_i = '1' else fifo_count_w(0);
end architecture;
