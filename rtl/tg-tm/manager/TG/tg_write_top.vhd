library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Minimal top for the write phase (AW/W/B).
entity tg_write_top is
  generic (
    p_USE_TG_CTRL_TMR              : boolean := c_ENABLE_TG_CTRL_TMR;
    p_USE_TG_CTRL_TMR_INJECT_ERROR : boolean := c_ENABLE_TG_CTRL_TMR_INJECT_ERROR;
    p_USE_TG_HAMMING               : boolean := c_ENABLE_TG_HAMMING_PROTECTION;
    p_USE_TG_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TG_HAMMING_DOUBLE_DETECT;
    p_USE_TG_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TG_HAMMING_INJECT_ERROR
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

    -- Write request channel
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);
    AWVALID : out std_logic;
    AWREADY : in  std_logic;

    -- Write data channel
    WVALID  : out std_logic;
    WREADY  : in  std_logic;
    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic;

    -- Write response channel
    BID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
    BVALID : in  std_logic;
    BREADY : out std_logic;

    -- observation (routed to top)
    i_OBS_TG_HAM_BUFFER_CORRECT_ERROR : in std_logic := '1';
    i_OBS_TG_TMR_CTRL_CORRECT_ERROR   : in std_logic := '1';

    o_OBS_TG_TMR_CTRL_ERROR        : out std_logic;
    o_OBS_TG_HAM_BUFFER_SINGLE_ERR : out std_logic;
    o_OBS_TG_HAM_BUFFER_DOUBLE_ERR : out std_logic;
    o_OBS_TG_HAM_BUFFER_ENC_DATA   : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end tg_write_top;

architecture rtl of tg_write_top is
  signal w_write_done      : std_logic;
  signal w_seed_pulse      : std_logic;
  signal w_wbeat_pulse     : std_logic;
  signal w_ctrl_tmr_err   : std_logic;
  signal w_ham_single_err : std_logic;
  signal w_ham_double_err : std_logic;
  signal w_ham_enc_data   : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);
begin

  gen_ctrl_plain : if (not p_USE_TG_CTRL_TMR) generate
    
    w_ctrl_tmr_err <= '0';
  end generate;

  gen_ctrl_tmr : if p_USE_TG_CTRL_TMR generate
  begin
    u_CTRL_TMR: entity work.tg_write_controller_tmr
      generic map(
        p_USE_TMR_INJECT_ERROR => p_USE_TG_CTRL_TMR_INJECT_ERROR
      )
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_start => i_start,
        o_done  => w_write_done,

        AWREADY => AWREADY,
        WREADY  => WREADY,
        BVALID  => BVALID,

        AWVALID => AWVALID,
        WVALID  => WVALID,
        BREADY  => BREADY,

        o_seed_pulse      => w_seed_pulse,
        o_wbeat_pulse     => w_wbeat_pulse,

        i_correct_enable=> i_OBS_TG_TMR_CTRL_CORRECT_ERROR,
        error_o         => w_ctrl_tmr_err
      );
  end generate;

  u_DP: entity work.tg_write_datapath
    generic map(
      p_USE_HAMMING               => p_USE_TG_HAMMING,
      p_USE_HAMMING_DOUBLE_DETECT => p_USE_TG_HAMMING_DOUBLE_DETECT,
      p_USE_HAMMING_INJECT_ERROR  => p_USE_TG_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_seed_pulse      => w_seed_pulse,
      i_wbeat_pulse     => w_wbeat_pulse,

      AWID    => AWID,
      AWADDR  => AWADDR,
      AWLEN   => AWLEN,
      AWBURST => AWBURST,

      WDATA   => WDATA,

      WLAST   => WLAST,
      
      i_correct_enable => i_OBS_TG_HAM_BUFFER_CORRECT_ERROR,
      o_single_err => w_ham_single_err,
      o_double_err => w_ham_double_err,
      o_ham_buffer_enc_data => w_ham_enc_data
    );

  o_done <= w_write_done;

  -- observation outputs
  o_OBS_TG_TMR_CTRL_ERROR        <= w_ctrl_tmr_err;
  o_OBS_TG_HAM_BUFFER_SINGLE_ERR <= w_ham_single_err;
  o_OBS_TG_HAM_BUFFER_DOUBLE_ERR <= w_ham_double_err;
  o_OBS_TG_HAM_BUFFER_ENC_DATA   <= w_ham_enc_data;
end rtl;
