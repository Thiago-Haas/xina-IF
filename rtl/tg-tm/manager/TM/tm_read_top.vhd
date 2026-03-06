library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Top for the read phase (AR/R) with minimal comparator output.
entity tm_read_top is
  generic(
    p_INIT_VALUE : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- optional hardening (mirrors TG)
    p_USE_TM_CTRL_TMR              : boolean := c_ENABLE_TM_CTRL_TMR;
    p_USE_TM_HAMMING               : boolean := c_ENABLE_TM_HAMMING_PROTECTION;
    p_USE_TM_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TM_HAMMING_DOUBLE_DETECT;
    p_USE_TM_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TM_HAMMING_INJECT_ERROR;
    p_USE_TM_TXN_COUNTER_HAMMING   : boolean := c_ENABLE_TM_TXN_COUNTER_HAMMING;
    p_TM_TXN_COUNTER_WIDTH         : natural := c_TM_TRANSACTION_COUNTER_WIDTH
  );
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    -- sequencing
    i_start : in  std_logic := '1';
    o_done  : out std_logic;

    -- control inputs
    INPUT_ADDRESS : in std_logic_vector(63 downto 0);
    STARTING_SEED : in std_logic_vector(31 downto 0);

    -- Read address channel
    ARID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : out std_logic_vector(7 downto 0);
    ARBURST : out std_logic_vector(1 downto 0);
    ARVALID : out std_logic;
    ARREADY : in  std_logic;

    -- Read data channel
    RVALID : in  std_logic;
    RREADY : out std_logic;
    RDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RLAST  : in  std_logic;

    RID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    RRESP  : in  std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');

    -- minimal compare output
    o_mismatch : out std_logic;

    -- debug
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- observation
    i_OBS_TM_HAM_BUFFER_CORRECT_ERROR : in  std_logic := '1';
    i_OBS_TM_TMR_CTRL_CORRECT_ERROR   : in  std_logic := '1';
    i_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR : in std_logic := '1';
    o_OBS_TM_TMR_CTRL_ERROR           : out std_logic;
    o_OBS_TM_HAM_BUFFER_SINGLE_ERR    : out std_logic;
    o_OBS_TM_HAM_BUFFER_DOUBLE_ERR    : out std_logic;
    o_OBS_TM_HAM_BUFFER_ENC_DATA      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    o_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR : out std_logic;
    o_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR : out std_logic;
    o_OBS_TM_HAM_TXN_COUNTER_ENC_DATA   : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    o_TM_TRANSACTION_COUNT              : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0)
  );
end tm_read_top;

architecture rtl of tm_read_top is
  signal w_read_done       : std_logic;
  signal w_txn_start_pulse : std_logic;
  signal w_rbeat_pulse     : std_logic;
  signal w_r_hs_comb       : std_logic;
  signal w_seed_pulse      : std_logic;

  signal w_ctrl_tmr_err    : std_logic := '0';
  signal w_ham_single_err  : std_logic := '0';
  signal w_ham_double_err  : std_logic := '0';
  signal w_ham_buffer_enc_data : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_txn_count_data_in  : std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0);
  signal w_txn_count_data_out : std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0);
  signal w_txn_count_enc_data : std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal w_txn_count_single_err : std_logic := '0';
  signal w_txn_count_double_err : std_logic := '0';
begin

  -- Controller selection: plain vs TMR
  gen_ctrl_plain : if not p_USE_TM_CTRL_TMR generate
    u_CTRL: entity work.tm_read_controller
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_start => i_start,
        o_done  => w_read_done,

        ARREADY => ARREADY,
        RVALID  => RVALID,
        RLAST   => RLAST,

        ARVALID => ARVALID,
        RREADY  => RREADY,

        o_txn_start_pulse => w_txn_start_pulse,
        o_rbeat_pulse     => w_rbeat_pulse,
        o_rbeat_hs_comb   => w_r_hs_comb,
        o_seed_pulse      => w_seed_pulse
      );
    w_ctrl_tmr_err <= '0';
  end generate;

  gen_ctrl_tmr : if p_USE_TM_CTRL_TMR generate
    u_CTRL_TMR: entity work.tm_read_controller_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_start => i_start,
        o_done  => w_read_done,

        ARREADY => ARREADY,
        RVALID  => RVALID,
        RLAST   => RLAST,

        ARVALID => ARVALID,
        RREADY  => RREADY,

        o_txn_start_pulse => w_txn_start_pulse,
        o_rbeat_pulse     => w_rbeat_pulse,
        o_rbeat_hs_comb   => w_r_hs_comb,
        o_seed_pulse      => w_seed_pulse,

        i_correct_enable  => i_OBS_TM_TMR_CTRL_CORRECT_ERROR,
        error_o           => w_ctrl_tmr_err
      );
  end generate;

  u_DP: entity work.tm_read_datapath
    generic map(
      p_INIT_VALUE           => p_INIT_VALUE,
      p_USE_TM_HAMMING               => p_USE_TM_HAMMING,
      p_USE_TM_HAMMING_DOUBLE_DETECT => p_USE_TM_HAMMING_DOUBLE_DETECT,
      p_USE_TM_HAMMING_INJECT_ERROR  => p_USE_TM_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_seed_pulse      => w_seed_pulse,
      -- Use same-cycle R handshake for stepping/checking (avoid 1-cycle delayed pulse)
      i_rbeat_pulse     => w_r_hs_comb,

      RDATA => RDATA,

      ARID    => ARID,
      ARADDR  => ARADDR,
      ARLEN   => ARLEN,
      ARBURST => ARBURST,

      o_mismatch       => o_mismatch,
      o_expected_value => o_expected_value,

      i_OBS_TM_HAM_BUFFER_CORRECT_ERROR => i_OBS_TM_HAM_BUFFER_CORRECT_ERROR,
      o_ham_single_err => w_ham_single_err,
      o_ham_double_err => w_ham_double_err,
      o_ham_buffer_enc_data => w_ham_buffer_enc_data
    );

  w_txn_count_data_in <= std_logic_vector(unsigned(w_txn_count_data_out) + 1);

  u_TM_TXN_COUNTER: entity work.hamming_register
    generic map(
      DATA_WIDTH     => p_TM_TXN_COUNTER_WIDTH,
      HAMMING_ENABLE => p_USE_TM_TXN_COUNTER_HAMMING,
      DETECT_DOUBLE  => p_USE_TM_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (p_TM_TXN_COUNTER_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => false
    )
    port map(
      correct_en_i => i_OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR,
      write_en_i   => w_read_done,
      data_i       => w_txn_count_data_in,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => w_txn_count_single_err,
      double_err_o => w_txn_count_double_err,
      enc_data_o   => w_txn_count_enc_data,
      data_o       => w_txn_count_data_out
    );

  o_done <= w_read_done;

  -- obs to top
  o_OBS_TM_TMR_CTRL_ERROR        <= w_ctrl_tmr_err;
  o_OBS_TM_HAM_BUFFER_SINGLE_ERR <= w_ham_single_err;
  o_OBS_TM_HAM_BUFFER_DOUBLE_ERR <= w_ham_double_err;
  o_OBS_TM_HAM_BUFFER_ENC_DATA   <= w_ham_buffer_enc_data;
  o_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR <= w_txn_count_single_err;
  o_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR <= w_txn_count_double_err;
  o_OBS_TM_HAM_TXN_COUNTER_ENC_DATA   <= w_txn_count_enc_data;
  o_TM_TRANSACTION_COUNT <= w_txn_count_data_out;
end rtl;
