library ieee;
use ieee.std_logic_1164.all;

use work.hamming_pkg.all;

entity buffer_fifo_ham_debug is
  generic (
    p_DATA_WIDTH   : positive := 32;
    p_BUFFER_DEPTH : positive := 4;
    DETECT_DOUBLE  : boolean  := TRUE
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
    correct_error_i : in  std_logic := '1';
    single_err_o    : out std_logic;
    double_err_o    : out std_logic;

    -- ERROR INJECTION (DEBUG) - inside FIFO storage (encoded word)
    INJECT_EN_i   : in  std_logic := '0';
    INJECT_IDX_i  : in  integer   := 0;
    INJECT_MASK_i : in  std_logic_vector(p_DATA_WIDTH + get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE) - 1 downto 0)
                     := (others => '0')
  );
end buffer_fifo_ham_debug;

architecture rtl of buffer_fifo_ham_debug is

  constant c_PARITY_WIDTH : integer := get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE);

  signal DATA_ENCODE_w : std_logic_vector(p_DATA_WIDTH + c_PARITY_WIDTH - 1 downto 0);
  signal DATA_DECODE_w : std_logic_vector(p_DATA_WIDTH + c_PARITY_WIDTH - 1 downto 0);

begin

  buffer_fifo_dbg : entity work.buffer_fifo_debug
    generic map(
      p_DATA_WIDTH   => p_DATA_WIDTH + c_PARITY_WIDTH,
      p_BUFFER_DEPTH => p_BUFFER_DEPTH
    )
    port map(
      ACLK   => ACLK,
      ARESET => ARESET,

      READ_OK_o  => READ_OK_o,
      READ_i     => READ_i,
      DATA_o     => DATA_DECODE_w,

      WRITE_OK_o => WRITE_OK_o,
      WRITE_i    => WRITE_i,
      DATA_i     => DATA_ENCODE_w,

      INJECT_EN_i   => INJECT_EN_i,
      INJECT_IDX_i  => INJECT_IDX_i,
      INJECT_MASK_i => INJECT_MASK_i
    );

  hamming_encoder : entity work.hamming_encoder
    generic map(
      DATA_SIZE     => p_DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map(
      data_i    => DATA_i,
      encoded_o => DATA_ENCODE_w
    );

  hamming_decoder : entity work.hamming_decoder
    generic map(
      DATA_SIZE     => p_DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map(
      encoded_i       => DATA_DECODE_w,
      correct_error_i => correct_error_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      data_o          => DATA_o
    );

end rtl;
