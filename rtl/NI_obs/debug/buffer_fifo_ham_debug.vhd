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
    i_READ    : in  std_logic;
    o_READ_OK : out std_logic;
    o_DATA    : out std_logic_vector(p_DATA_WIDTH - 1 downto 0);

    -- Write
    i_WRITE    : in  std_logic;
    i_DATA     : in  std_logic_vector(p_DATA_WIDTH - 1 downto 0);
    o_WRITE_OK : out std_logic;

    -- Hamming decoder control/status
    correct_error_i : in  std_logic := '1';
    single_err_o    : out std_logic;
    double_err_o    : out std_logic;

    -- ERROR INJECTION (DEBUG) - inside FIFO storage (encoded word)
    i_INJECT_EN   : in  std_logic := '0';
    i_INJECT_IDX  : in  integer   := 0;
    i_INJECT_MASK : in  std_logic_vector(p_DATA_WIDTH + get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE) - 1 downto 0)
                     := (others => '0')
  );
end buffer_fifo_ham_debug;

architecture rtl of buffer_fifo_ham_debug is

  constant c_PARITY_WIDTH : integer := get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE);

  signal w_DATA_ENCODE : std_logic_vector(p_DATA_WIDTH + c_PARITY_WIDTH - 1 downto 0);
  signal w_DATA_DECODE : std_logic_vector(p_DATA_WIDTH + c_PARITY_WIDTH - 1 downto 0);

begin

  buffer_fifo_dbg : entity work.buffer_fifo_debug
    generic map(
      p_DATA_WIDTH   => p_DATA_WIDTH + c_PARITY_WIDTH,
      p_BUFFER_DEPTH => p_BUFFER_DEPTH
    )
    port map(
      ACLK   => ACLK,
      ARESET => ARESET,

      o_READ_OK  => o_READ_OK,
      i_READ     => i_READ,
      o_DATA     => w_DATA_DECODE,

      o_WRITE_OK => o_WRITE_OK,
      i_WRITE    => i_WRITE,
      i_DATA     => w_DATA_ENCODE,

      i_INJECT_EN   => i_INJECT_EN,
      i_INJECT_IDX  => i_INJECT_IDX,
      i_INJECT_MASK => i_INJECT_MASK
    );

  hamming_encoder : entity work.hamming_encoder
    generic map(
      DATA_SIZE     => p_DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map(
      data_i    => i_DATA,
      encoded_o => w_DATA_ENCODE
    );

  hamming_decoder : entity work.hamming_decoder
    generic map(
      DATA_SIZE     => p_DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map(
      encoded_i       => w_DATA_DECODE,
      correct_error_i => correct_error_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      data_o          => o_DATA
    );

end rtl;
