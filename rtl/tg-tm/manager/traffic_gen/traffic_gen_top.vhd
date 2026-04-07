library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

-- Minimal top for the write phase (AW/W/B).
entity traffic_gen_top is
  generic (
    p_USE_TG_CTRL_TMR              : boolean := c_ENABLE_TG_CTRL_TMR;
    p_USE_TG_HAMMING               : boolean := c_ENABLE_TG_HAMMING_PROTECTION;
    p_USE_TG_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_TG_HAMMING_DOUBLE_DETECT;
    p_USE_TG_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_TG_HAMMING_INJECT_ERROR
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
    OBS_TG_HAM_BUFFER_CORRECT_ERROR_i : in std_logic := '1';
    OBS_TG_TMR_CTRL_CORRECT_ERROR_i   : in std_logic := '1';

    OBS_TG_TMR_CTRL_ERROR_o        : out std_logic;
    OBS_TG_HAM_BUFFER_SINGLE_ERR_o : out std_logic;
    OBS_TG_HAM_BUFFER_DOUBLE_ERR_o : out std_logic;
    OBS_TG_HAM_BUFFER_ENC_DATA_o   : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end traffic_gen_top;

architecture rtl of traffic_gen_top is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
  signal write_done_w      : std_logic;
  signal seed_pulse_w      : std_logic;
  signal wbeat_pulse_w     : std_logic;
  signal ctrl_tmr_err_w   : std_logic;
  signal ham_single_err_w : std_logic;
  signal ham_double_err_w : std_logic;
  signal ham_enc_data_w   : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_TG_HAMMING_DOUBLE_DETECT) - 1 downto 0);
begin

  gen_ctrl_plain : if (not p_USE_TG_CTRL_TMR) generate
    attribute DONT_TOUCH of u_traffic_gen_control : label is "TRUE";
    attribute syn_preserve of u_traffic_gen_control : label is true;
    attribute KEEP_HIERARCHY of u_traffic_gen_control : label is "TRUE";
  begin
    u_traffic_gen_control: entity work.traffic_gen_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        start_i => start_i,
        done_o  => write_done_w,
        AWREADY => AWREADY,
        WREADY  => WREADY,
        BVALID  => BVALID,
        AWVALID => AWVALID,
        WVALID  => WVALID,
        BREADY  => BREADY,
        seed_pulse_o  => seed_pulse_w,
        wbeat_pulse_o => wbeat_pulse_w
      );
    ctrl_tmr_err_w <= '0';
  end generate;

  gen_ctrl_tmr : if p_USE_TG_CTRL_TMR generate
  begin
    u_traffic_gen_control_tmr: entity work.traffic_gen_control_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        start_i => start_i,
        done_o  => write_done_w,

        AWREADY => AWREADY,
        WREADY  => WREADY,
        BVALID  => BVALID,

        AWVALID => AWVALID,
        WVALID  => WVALID,
        BREADY  => BREADY,

        seed_pulse_o      => seed_pulse_w,
        wbeat_pulse_o     => wbeat_pulse_w,

        correct_enable_i=> OBS_TG_TMR_CTRL_CORRECT_ERROR_i,
        error_o         => ctrl_tmr_err_w
      );
  end generate;

  u_traffic_gen_datapath: entity work.traffic_gen_datapath
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

      seed_pulse_i      => seed_pulse_w,
      wbeat_pulse_i     => wbeat_pulse_w,

      AWID    => AWID,
      AWADDR  => AWADDR,
      AWLEN   => AWLEN,
      AWBURST => AWBURST,

      WDATA   => WDATA,

      WLAST   => WLAST,
      
      correct_enable_i => OBS_TG_HAM_BUFFER_CORRECT_ERROR_i,
      single_err_o => ham_single_err_w,
      double_err_o => ham_double_err_w,
      ham_buffer_enc_data_o => ham_enc_data_w
    );

  done_o <= write_done_w;

  -- observation outputs
  OBS_TG_TMR_CTRL_ERROR_o        <= ctrl_tmr_err_w;
  OBS_TG_HAM_BUFFER_SINGLE_ERR_o <= ham_single_err_w;
  OBS_TG_HAM_BUFFER_DOUBLE_ERR_o <= ham_double_err_w;
  OBS_TG_HAM_BUFFER_ENC_DATA_o   <= ham_enc_data_w;
end rtl;
