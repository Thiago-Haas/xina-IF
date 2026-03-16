library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity loopback_datapath is
  generic (
    p_USE_LB_HAMMING               : boolean := c_ENABLE_LB_HAMMING_PROTECTION;
    p_USE_LB_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_LB_HAMMING_DOUBLE_DETECT;
    p_USE_LB_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_LB_HAMMING_INJECT_ERROR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    cap_en_i    : in  std_logic;
    cap_flit_i  : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    cap_idx_i   : in  unsigned(5 downto 0);
    rd_payload_o     : out std_logic_vector(31 downto 0);

    -- Hamming observe/correct (same "style" as TG/TM datapaths)
    OBS_LB_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    single_err_o     : out std_logic;
    double_err_o     : out std_logic;
    ham_buffer_enc_data_o : out std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    -- pulse when payload captured
    hold_valid_o : out std_logic
  );
end entity;

architecture rtl of loopback_datapath is

  signal payload_cap_w : std_logic;
  signal payload_w     : std_logic_vector(31 downto 0);

  signal single_err_w  : std_logic;
  signal double_err_w  : std_logic;

  -- optional observability of encoded reg (not exported here, but kept for debug parity with TG)
  -- width = 32 + get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT)
  signal enc_payload_w : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal payload_dec_w : std_logic_vector(31 downto 0);





  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of payload_dec_w : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of payload_dec_w : signal is true;
begin
  ------------------------------------------------------------------------------
  -- Capture condition: payload at fixed flit index 4 when ctrl=0
  ------------------------------------------------------------------------------
  payload_cap_w <= '1' when (cap_en_i = '1') and
                          (cap_idx_i = to_unsigned(4, cap_idx_i'length)) and
                          (cap_flit_i(cap_flit_i'left) = '0')
                   else '0';

  payload_w <= cap_flit_i(31 downto 0);

  -- pulse to controller (no reg here)
  hold_valid_o <= payload_cap_w;

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
      correct_en_i => OBS_LB_HAM_BUFFER_CORRECT_ERROR_i,
      write_en_i   => payload_cap_w,
      data_i       => payload_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => single_err_w,
      double_err_o => double_err_w,
      enc_data_o   => enc_payload_w,
      data_o       => payload_dec_w
    );

  -- outputs
  single_err_o <= single_err_w;
  double_err_o <= double_err_w;
  ham_buffer_enc_data_o <= enc_payload_w;

  -- for READ responses, always drive the (decoded) payload
  rd_payload_o <= payload_dec_w;

end architecture;
