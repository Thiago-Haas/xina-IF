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
    start_i : in  std_logic := '1';
    done_o  : out std_logic;

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

    -- comparator output
    tm_lfsr_comparison_mismatch_o : out std_logic;

    -- debug
    expected_value_o : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- observation
    OBS_TM_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_TM_TMR_CTRL_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_i : in std_logic := '1';
    OBS_TM_TMR_CTRL_ERROR_o           : out std_logic;
    OBS_TM_HAM_BUFFER_SINGLE_ERR_o    : out std_logic;
    OBS_TM_HAM_BUFFER_DOUBLE_ERR_o    : out std_logic;
    OBS_TM_HAM_BUFFER_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_o : out std_logic;
    OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_o : out std_logic;
    OBS_TM_HAM_TXN_COUNTER_ENC_DATA_o   : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
    TM_TRANSACTION_COUNT_o              : out std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0)
  );
end tm_read_top;

architecture rtl of tm_read_top is
  signal read_done_w       : std_logic;
  signal hs_comb_w       : std_logic;
  signal seed_pulse_w      : std_logic;

  signal ctrl_tmr_err_w    : std_logic := '0';
  signal ham_single_err_w  : std_logic := '0';
  signal ham_double_err_w  : std_logic := '0';
  signal ham_buffer_enc_data_w : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal txn_count_data_out_w : std_logic_vector(p_TM_TXN_COUNTER_WIDTH - 1 downto 0);
  signal txn_count_enc_data_w : std_logic_vector(p_TM_TXN_COUNTER_WIDTH + work.hamming_pkg.get_ecc_size(p_TM_TXN_COUNTER_WIDTH, p_USE_TM_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal txn_count_single_err_w : std_logic := '0';
  signal txn_count_double_err_w : std_logic := '0';
begin

  -- Controller selection: plain vs TMR
  gen_ctrl_plain : if not p_USE_TM_CTRL_TMR generate
    u_CTRL: entity work.tm_read_controller
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        start_i => start_i,
        done_o  => read_done_w,

        ARREADY => ARREADY,
        RVALID  => RVALID,
        RLAST   => RLAST,

        ARVALID => ARVALID,
        RREADY  => RREADY,

        rbeat_hs_comb_o   => hs_comb_w,
        seed_pulse_o      => seed_pulse_w
      );
    ctrl_tmr_err_w <= '0';
  end generate;

  gen_ctrl_tmr : if p_USE_TM_CTRL_TMR generate
    u_CTRL_TMR: entity work.tm_read_controller_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        start_i => start_i,
        done_o  => read_done_w,

        ARREADY => ARREADY,
        RVALID  => RVALID,
        RLAST   => RLAST,

        ARVALID => ARVALID,
        RREADY  => RREADY,

        rbeat_hs_comb_o   => hs_comb_w,
        seed_pulse_o      => seed_pulse_w,

        correct_enable_i  => OBS_TM_TMR_CTRL_CORRECT_ERROR_i,
        error_o           => ctrl_tmr_err_w
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

      seed_pulse_i      => seed_pulse_w,
      -- Use same-cycle R handshake for stepping/checking (avoid 1-cycle delayed pulse)
      rbeat_pulse_i     => hs_comb_w,

      RDATA => RDATA,

      ARID    => ARID,
      ARADDR  => ARADDR,
      ARLEN   => ARLEN,
      ARBURST => ARBURST,

      lfsr_comparison_mismatch_o => tm_lfsr_comparison_mismatch_o,
      expected_value_o => expected_value_o,

      OBS_TM_HAM_BUFFER_CORRECT_ERROR_i => OBS_TM_HAM_BUFFER_CORRECT_ERROR_i,
      ham_single_err_o => ham_single_err_w,
      ham_double_err_o => ham_double_err_w,
      ham_buffer_enc_data_o => ham_buffer_enc_data_w
    );

  u_TM_TXN_COUNTER: entity work.tm_read_transaction_counter_hamming
    generic map(
      p_TM_TXN_COUNTER_WIDTH         => p_TM_TXN_COUNTER_WIDTH,
      p_USE_TM_COUNTER_HAMMING       => p_USE_TM_TXN_COUNTER_HAMMING,
      p_USE_TM_HAMMING_DOUBLE_DETECT => p_USE_TM_HAMMING_DOUBLE_DETECT
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      increment_en_i => read_done_w,
      OBS_TM_HAM_COUNTER_CORRECT_ERROR_i => OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_i,
      TM_TRANSACTION_COUNT_o => txn_count_data_out_w,
      OBS_TM_HAM_COUNTER_SINGLE_ERR_o => txn_count_single_err_w,
      OBS_TM_HAM_COUNTER_DOUBLE_ERR_o => txn_count_double_err_w,
      OBS_TM_HAM_COUNTER_ENC_DATA_o   => txn_count_enc_data_w
    );

  done_o <= read_done_w;

  -- obs to top
  OBS_TM_TMR_CTRL_ERROR_o        <= ctrl_tmr_err_w;
  OBS_TM_HAM_BUFFER_SINGLE_ERR_o <= ham_single_err_w;
  OBS_TM_HAM_BUFFER_DOUBLE_ERR_o <= ham_double_err_w;
  OBS_TM_HAM_BUFFER_ENC_DATA_o   <= ham_buffer_enc_data_w;
  OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR_o <= txn_count_single_err_w;
  OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR_o <= txn_count_double_err_w;
  OBS_TM_HAM_TXN_COUNTER_ENC_DATA_o   <= txn_count_enc_data_w;
  TM_TRANSACTION_COUNT_o <= txn_count_data_out_w;
end rtl;
