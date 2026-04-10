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

  type tmr_sl_t is array (0 to 2) of std_logic;
  type tmr_cnt_t is array (0 to 2) of unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0);
  constant c_COUNT_WIDTH : positive := integer(ceil(log2(real(p_BUFFER_DEPTH)))) + 1;
  constant c_TMR_VOTE_WIDTH : positive := 7 + c_COUNT_WIDTH;

  signal stage_valid_w   : tmr_sl_t;
  signal stage_load_w    : tmr_sl_t;
  signal stage_push_w    : tmr_sl_t;
  signal fifo_do_write_w : tmr_sl_t;
  signal fifo_do_read_w  : tmr_sl_t;
  signal fifo_write_ok_w : tmr_sl_t;
  signal fifo_read_ok_w  : tmr_sl_t;
  signal fifo_count_w    : tmr_cnt_t;
  signal bundle_a_w      : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
  signal bundle_b_w      : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
  signal bundle_c_w      : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
  signal corr_bundle_w   : std_logic_vector(c_TMR_VOTE_WIDTH - 1 downto 0);
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_buffer_fifo_ham_ctrl : label is "TRUE";
        attribute syn_preserve of u_buffer_fifo_ham_ctrl : label is true;
    attribute KEEP_HIERARCHY of u_buffer_fifo_ham_ctrl : label is "TRUE";
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

  bundle_a_w <= stage_valid_w(0) &
                stage_load_w(0) &
                stage_push_w(0) &
                fifo_do_write_w(0) &
                fifo_do_read_w(0) &
                fifo_write_ok_w(0) &
                fifo_read_ok_w(0) &
                std_logic_vector(fifo_count_w(0));

  bundle_b_w <= stage_valid_w(1) &
                stage_load_w(1) &
                stage_push_w(1) &
                fifo_do_write_w(1) &
                fifo_do_read_w(1) &
                fifo_write_ok_w(1) &
                fifo_read_ok_w(1) &
                std_logic_vector(fifo_count_w(1));

  bundle_c_w <= stage_valid_w(2) &
                stage_load_w(2) &
                stage_push_w(2) &
                fifo_do_write_w(2) &
                fifo_do_read_w(2) &
                fifo_write_ok_w(2) &
                fifo_read_ok_w(2) &
                std_logic_vector(fifo_count_w(2));

  u_buffer_fifo_ham_ctrl_tmr_voter: entity work.tmr_voter_block
    generic map(
      p_WIDTH => c_TMR_VOTE_WIDTH
    )
    port map(
      A_i => bundle_a_w,
      B_i => bundle_b_w,
      C_i => bundle_c_w,
      correct_enable_i => correct_enable_i,
      corrected_o => corr_bundle_w,
      error_bits_o => open,
      error_o => error_o
    );

  STAGE_VALID_o   <= corr_bundle_w(c_TMR_VOTE_WIDTH - 1);
  STAGE_LOAD_o    <= corr_bundle_w(c_TMR_VOTE_WIDTH - 2);
  STAGE_PUSH_o    <= corr_bundle_w(c_TMR_VOTE_WIDTH - 3);
  FIFO_DO_WRITE_o <= corr_bundle_w(c_TMR_VOTE_WIDTH - 4);
  FIFO_DO_READ_o  <= corr_bundle_w(c_TMR_VOTE_WIDTH - 5);
  FIFO_WRITE_OK_o <= corr_bundle_w(c_TMR_VOTE_WIDTH - 6);
  FIFO_READ_OK_o  <= corr_bundle_w(c_TMR_VOTE_WIDTH - 7);
  FIFO_COUNT_o    <= unsigned(corr_bundle_w(c_COUNT_WIDTH - 1 downto 0));
end architecture;
