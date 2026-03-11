library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_dp is
  generic (
    p_USE_LB_HAMMING               : boolean := c_ENABLE_LB_HAMMING_PROTECTION;
    p_USE_LB_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_LB_HAMMING_DOUBLE_DETECT;
    p_USE_LB_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_LB_HAMMING_INJECT_ERROR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_cap_en    : in  std_logic;
    i_cap_flit  : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_cap_idx   : in  unsigned(5 downto 0);
    o_rd_payload     : out std_logic_vector(31 downto 0);

    -- Hamming observe/correct (same "style" as TG/TM datapaths)
    i_OBS_LB_HAM_BUFFER_CORRECT_ERROR : in  std_logic := '1';
    o_single_err     : out std_logic;
    o_double_err     : out std_logic;
    o_ham_buffer_enc_data : out std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    -- pulse when payload captured
    o_hold_valid : out std_logic
  );
end entity;

architecture rtl of lb_dp is

  signal w_payload_cap : std_logic;
  signal w_payload     : std_logic_vector(31 downto 0);

  signal w_single_err  : std_logic;
  signal w_double_err  : std_logic;

  -- optional observability of encoded reg (not exported here, but kept for debug parity with TG)
  -- width = 32 + get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT)
  signal w_enc_payload : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal payload_dec_r : std_logic_vector(31 downto 0);

begin
  ------------------------------------------------------------------------------
  -- Capture condition: payload at fixed flit index 4 when ctrl=0
  ------------------------------------------------------------------------------
  w_payload_cap <= '1' when (i_cap_en = '1') and
                          (i_cap_idx = to_unsigned(4, i_cap_idx'length)) and
                          (i_cap_flit(i_cap_flit'left) = '0')
                   else '0';

  w_payload <= i_cap_flit(31 downto 0);

  -- pulse to controller (no reg here)
  o_hold_valid <= w_payload_cap;

  ------------------------------------------------------------------------------
  -- TG-style Hamming-protected 32-bit payload register
  ------------------------------------------------------------------------------
  u_PAYLOAD_REG : entity work.hamming_register
    generic map(
      DATA_WIDTH     => 32,
      HAMMING_ENABLE => p_USE_LB_HAMMING,
      DETECT_DOUBLE  => p_USE_LB_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (31 downto 0 => '0'),
      INJECT_ERROR   => p_USE_LB_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => i_OBS_LB_HAM_BUFFER_CORRECT_ERROR,
      write_en_i   => w_payload_cap,
      data_i       => w_payload,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => w_single_err,
      double_err_o => w_double_err,
      enc_data_o   => w_enc_payload,
      data_o       => payload_dec_r
    );

  -- outputs
  o_single_err <= w_single_err;
  o_double_err <= w_double_err;
  o_ham_buffer_enc_data <= w_enc_payload;

  -- for READ responses, always drive the (decoded) payload
  o_rd_payload <= payload_dec_r;

end architecture;
