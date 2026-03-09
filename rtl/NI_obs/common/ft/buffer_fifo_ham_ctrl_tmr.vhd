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

    i_WRITE_REQ : in std_logic;
    i_READ_REQ  : in std_logic;

    o_STAGE_VALID  : out std_logic;
    o_STAGE_LOAD   : out std_logic;
    o_STAGE_PUSH   : out std_logic;
    o_FIFO_DO_WRITE: out std_logic;
    o_FIFO_DO_READ : out std_logic;
    o_FIFO_WRITE_OK: out std_logic;
    o_FIFO_READ_OK : out std_logic;
    o_FIFO_COUNT   : out unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0);

    i_correct_enable : in std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of buffer_fifo_ham_ctrl_tmr is
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
  begin
    u_ctrl : entity work.buffer_fifo_ham_ctrl
      generic map(
        p_BUFFER_DEPTH => p_BUFFER_DEPTH
      )
      port map(
        ACLK   => ACLK,
        ARESET => ARESET,
        i_WRITE_REQ => i_WRITE_REQ,
        i_READ_REQ  => i_READ_REQ,
        o_STAGE_VALID   => stage_valid_w(i),
        o_STAGE_LOAD    => stage_load_w(i),
        o_STAGE_PUSH    => stage_push_w(i),
        o_FIFO_DO_WRITE => fifo_do_write_w(i),
        o_FIFO_DO_READ  => fifo_do_read_w(i),
        o_FIFO_WRITE_OK => fifo_write_ok_w(i),
        o_FIFO_READ_OK  => fifo_read_ok_w(i),
        o_FIFO_COUNT    => fifo_count_w(i)
      );
  end generate;

  error_o <= dis3(stage_valid_w(2), stage_valid_w(1), stage_valid_w(0)) or
             dis3_uns(fifo_count_w(2), fifo_count_w(1), fifo_count_w(0));

  o_STAGE_VALID   <= maj3(stage_valid_w(2), stage_valid_w(1), stage_valid_w(0)) when i_correct_enable = '1' else stage_valid_w(0);
  o_STAGE_LOAD    <= maj3(stage_load_w(2), stage_load_w(1), stage_load_w(0)) when i_correct_enable = '1' else stage_load_w(0);
  o_STAGE_PUSH    <= maj3(stage_push_w(2), stage_push_w(1), stage_push_w(0)) when i_correct_enable = '1' else stage_push_w(0);
  o_FIFO_DO_WRITE <= maj3(fifo_do_write_w(2), fifo_do_write_w(1), fifo_do_write_w(0)) when i_correct_enable = '1' else fifo_do_write_w(0);
  o_FIFO_DO_READ  <= maj3(fifo_do_read_w(2), fifo_do_read_w(1), fifo_do_read_w(0)) when i_correct_enable = '1' else fifo_do_read_w(0);
  o_FIFO_WRITE_OK <= maj3(fifo_write_ok_w(2), fifo_write_ok_w(1), fifo_write_ok_w(0)) when i_correct_enable = '1' else fifo_write_ok_w(0);
  o_FIFO_READ_OK  <= maj3(fifo_read_ok_w(2), fifo_read_ok_w(1), fifo_read_ok_w(0)) when i_correct_enable = '1' else fifo_read_ok_w(0);
  o_FIFO_COUNT    <= maj3_uns(fifo_count_w(2), fifo_count_w(1), fifo_count_w(0)) when i_correct_enable = '1' else fifo_count_w(0);
end architecture;

