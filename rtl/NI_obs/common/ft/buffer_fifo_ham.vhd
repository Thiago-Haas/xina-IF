library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.hamming_pkg.all;

entity buffer_fifo_ham is
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
    correct_error_i : in  std_logic := '1';  -- default: correct if possible
    single_err_o    : out std_logic;
    double_err_o    : out std_logic;
    o_enc_stage_data : out std_logic_vector(p_DATA_WIDTH + get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE) - 1 downto 0)
  );
end buffer_fifo_ham;

architecture rtl of buffer_fifo_ham is

  constant c_PARITY_WIDTH : integer := get_ecc_size(p_DATA_WIDTH, DETECT_DOUBLE);
  constant c_ENC_WIDTH    : integer := p_DATA_WIDTH + c_PARITY_WIDTH;

  -- FIFO-side signals
  signal fifo_write_ok  : std_logic;
  signal fifo_read_ok   : std_logic;
  signal fifo_data_out  : std_logic_vector(c_ENC_WIDTH - 1 downto 0);

  -- Write staging (encoded word produced by hamming_register)
  signal stage_valid    : std_logic := '0';
  signal stage_push     : std_logic;
  signal stage_load     : std_logic;

  signal enc_reg_word   : std_logic_vector(c_ENC_WIDTH - 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- FIFO storing ENCODED words
  -----------------------------------------------------------------------------
  u_fifo : entity work.buffer_fifo
    generic map (
      p_DATA_WIDTH   => c_ENC_WIDTH,
      p_BUFFER_DEPTH => p_BUFFER_DEPTH
    )
    port map (
      ACLK       => ACLK,
      ARESET     => ARESET,

      o_READ_OK  => fifo_read_ok,
      i_READ     => i_READ,
      o_DATA     => fifo_data_out,

      o_WRITE_OK => fifo_write_ok,
      i_WRITE    => stage_push,
      i_DATA     => enc_reg_word
    );

  -- propagate read OK outward (read path unchanged)
  o_READ_OK <= fifo_read_ok;

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
      data_o          => o_DATA
    );

  -----------------------------------------------------------------------------
  -- Write path: use hamming_register as a clean "encode staging register"
  --  * Accept i_WRITE when stage is empty
  --  * Push encoded word into FIFO when FIFO has space
  -----------------------------------------------------------------------------
  stage_load <= i_WRITE and (not stage_valid);
  stage_push <= stage_valid and fifo_write_ok;

  -- External "write ok" now means: you can load the staging register this cycle.
  -- (This makes the design simpler and avoids tying acceptance directly to FIFO.)
  o_WRITE_OK <= not stage_valid;

  u_ham_reg : entity work.hamming_register
    generic map (
      DATA_WIDTH     => p_DATA_WIDTH,
      HAMMING_ENABLE => true,
      DETECT_DOUBLE  => DETECT_DOUBLE,
      RESET_VALUE    => (p_DATA_WIDTH-1 downto 0 => '0'),
      INJECT_ERROR   => false
    )
    port map (
      correct_en_i => '1',        -- not relevant for encode; keep enabled
      write_en_i   => stage_load, -- capture raw data only when we accept a write
      data_i       => i_DATA,
      rstn_i       => not ARESET,
      clk_i        => ACLK,

      single_err_o => open,
      double_err_o => open,
      enc_data_o   => enc_reg_word,
      data_o       => open
    );

  -- Stage valid flag
  p_stage : process (ACLK, ARESET)
  begin
    if ARESET = '1' then
      stage_valid <= '0';
    elsif rising_edge(ACLK) then
      -- once loaded, remain valid until pushed into FIFO
      if stage_load = '1' then
        stage_valid <= '1';
      elsif stage_push = '1' then
        stage_valid <= '0';
      end if;
    end if;
  end process;

  o_enc_stage_data <= enc_reg_word;

end rtl;
