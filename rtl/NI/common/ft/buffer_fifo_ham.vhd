library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.hamming_pkg.all;
use work.xina_noc_pkg.all;

entity buffer_fifo_ham is
  generic (
    p_DATA_WIDTH   : positive := 32;
    p_BUFFER_DEPTH : positive := 4;
    DETECT_DOUBLE  : boolean  := TRUE;
    p_USE_HAM_FIFO_CTRL_TMR : boolean := c_ENABLE_HAM_FIFO_CTRL_TMR
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

    -- Hamming decoder control/status
    correct_error_i : in  std_logic := '1';  -- default: correct if possible
    single_err_o    : out std_logic;
    double_err_o    : out std_logic;
    enc_stage_data_o : out std_logic_vector(p_DATA_WIDTH + get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE) - 1 downto 0);

    -- TMR control/observation for FIFO control-state block (stage_valid + fifo_count)
    OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_HAM_FIFO_CTRL_TMR_ERROR_o         : out std_logic
  );
end buffer_fifo_ham;

architecture rtl of buffer_fifo_ham is

  constant c_PARITY_WIDTH : integer := get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE);
  constant c_ENC_WIDTH    : integer := p_DATA_WIDTH + c_PARITY_WIDTH;

  -- FIFO storage
  type fifo_type_t is array (p_BUFFER_DEPTH - 1 downto 0) of std_logic_vector(c_ENC_WIDTH - 1 downto 0);
  signal fifo_mem_r     : fifo_type_t := (others => (others => '0'));
  signal fifo_data_out  : std_logic_vector(c_ENC_WIDTH - 1 downto 0);

  -- Control block outputs
  signal stage_valid_w   : std_logic;
  signal stage_push_w    : std_logic;
  signal stage_load_w    : std_logic;
  signal fifo_do_write_w : std_logic;
  signal fifo_do_read_w  : std_logic;
  signal fifo_write_ok_w : std_logic;
  signal fifo_read_ok_w  : std_logic;
  signal fifo_count_w    : unsigned(integer(ceil(log2(real(p_BUFFER_DEPTH)))) downto 0);
  signal ctrl_tmr_err_w  : std_logic;

  signal enc_reg_word_r   : std_logic_vector(c_ENC_WIDTH - 1 downto 0);
  signal enc_word_w     : std_logic_vector(c_ENC_WIDTH - 1 downto 0);





  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute KEEP_HIERARCHY : string;
  attribute DONT_TOUCH of enc_reg_word_r : signal is "TRUE";
  attribute DONT_TOUCH of fifo_mem_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of enc_reg_word_r : signal is true;
  attribute syn_preserve of fifo_mem_r : signal is true;
begin

  gen_ctrl_plain : if not p_USE_HAM_FIFO_CTRL_TMR generate
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
        WRITE_REQ_i => WRITE_i,
        READ_REQ_i  => READ_i,
        STAGE_VALID_o   => stage_valid_w,
        STAGE_LOAD_o    => stage_load_w,
        STAGE_PUSH_o    => stage_push_w,
        FIFO_DO_WRITE_o => fifo_do_write_w,
        FIFO_DO_READ_o  => fifo_do_read_w,
        FIFO_WRITE_OK_o => fifo_write_ok_w,
        FIFO_READ_OK_o  => fifo_read_ok_w,
        FIFO_COUNT_o    => fifo_count_w
      );
    ctrl_tmr_err_w <= '0';
  end generate;

  gen_ctrl_tmr : if p_USE_HAM_FIFO_CTRL_TMR generate
  begin
    u_buffer_fifo_ham_ctrl_tmr: entity work.buffer_fifo_ham_ctrl_tmr
      generic map(
        p_BUFFER_DEPTH => p_BUFFER_DEPTH
      )
      port map(
        ACLK   => ACLK,
        ARESET => ARESET,
        WRITE_REQ_i => WRITE_i,
        READ_REQ_i  => READ_i,
        STAGE_VALID_o   => stage_valid_w,
        STAGE_LOAD_o    => stage_load_w,
        STAGE_PUSH_o    => stage_push_w,
        FIFO_DO_WRITE_o => fifo_do_write_w,
        FIFO_DO_READ_o  => fifo_do_read_w,
        FIFO_WRITE_OK_o => fifo_write_ok_w,
        FIFO_READ_OK_o  => fifo_read_ok_w,
        FIFO_COUNT_o    => fifo_count_w,
        correct_enable_i => OBS_HAM_FIFO_CTRL_TMR_CORRECT_ERROR_i,
        error_o          => ctrl_tmr_err_w
      );
  end generate;

  OBS_HAM_FIFO_CTRL_TMR_ERROR_o <= ctrl_tmr_err_w;

  p_fifo_mem : process (ACLK, ARESET)
  begin
    if ARESET = '1' then
      fifo_mem_r <= (others => (others => '0'));
    elsif rising_edge(ACLK) then
      if fifo_do_write_w = '1' then
        fifo_mem_r(0) <= enc_reg_word_r;
        for i in 1 to p_BUFFER_DEPTH - 1 loop
          fifo_mem_r(i) <= fifo_mem_r(i - 1);
        end loop;
      end if;
    end if;
  end process;

  fifo_data_out <= fifo_mem_r(0) when (to_integer(fifo_count_w) = 0) else
                   fifo_mem_r(to_integer(fifo_count_w - 1));

  -- propagate read OK outward (read path unchanged)
  READ_OK_o <= fifo_read_ok_w;

  -----------------------------------------------------------------------------
  -- Hamming decode (combinational) of FIFO output
  -----------------------------------------------------------------------------
  u_dec : entity work.hamming_decoder
    generic map (
      DATA_SIZE     => p_DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map (
      encoded_i       => fifo_data_out,
      correct_error_i => correct_error_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      data_o          => DATA_o
    );

  -----------------------------------------------------------------------------
  -- Write path: use hamming_register as a clean "encode staging register"
  --  * Accept WRITE_i when stage is empty
  --  * Push encoded word into FIFO when FIFO has space
  -----------------------------------------------------------------------------
  -- External "write ok" now means: you can load the staging register this cycle.
  -- (This makes the design simpler and avoids tying acceptance directly to FIFO.)
  WRITE_OK_o <= not stage_valid_w;

  u_ham_enc : entity work.hamming_encoder
    generic map (
      DATA_SIZE     => p_DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map (
      data_i    => DATA_i,
      encoded_o => enc_word_w
    );

  -- Staging register: stores encoded word accepted from the external write side.
  p_stage_data : process (ACLK, ARESET)
  begin
    if ARESET = '1' then
      enc_reg_word_r <= (others => '0');
    elsif rising_edge(ACLK) then
      if stage_load_w = '1' then
        enc_reg_word_r <= enc_word_w;
      end if;
    end if;
  end process;

  -- Expose the encoded word as seen by the decoder input.
  enc_stage_data_o <= fifo_data_out;

end rtl;
