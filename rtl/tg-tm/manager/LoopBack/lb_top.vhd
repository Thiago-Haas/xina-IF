library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- Synthesizable NoC-side loopback (subordinate emulator) for the combined TG/TM+NI top.
-- Split into controller + datapath, with optional ECC hardening (TMR on ctrl, Hamming on DP reg).
entity lb_top is
  generic (
    p_MEM_ADDR_BITS        : natural := 10;

    p_USE_LB_CTRL_TMR              : boolean := c_ENABLE_LB_CTRL_TMR;
    p_USE_LB_HAMMING               : boolean := c_ENABLE_LB_HAMMING_PROTECTION;
    p_USE_LB_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_LB_HAMMING_DOUBLE_DETECT;
    p_USE_LB_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_LB_HAMMING_INJECT_ERROR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Connect to tg_tm_ni_top NoC ports
    -- Request stream from NI:
    lin_data_i : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lin_val_i  : in  std_logic;
    lin_ack_o  : out std_logic;

    -- Response stream to NI:
    lout_data_o : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lout_val_o  : out std_logic;
    lout_ack_i  : in  std_logic;

    -- observation / correction (routed to top like TG)
    OBS_LB_HAM_BUFFER_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_LB_TMR_CTRL_CORRECT_ERROR_i   : in  std_logic := '1';

    OBS_LB_TMR_CTRL_ERROR_o        : out std_logic;
    OBS_LB_HAM_BUFFER_SINGLE_ERR_o : out std_logic;
    OBS_LB_HAM_BUFFER_DOUBLE_ERR_o : out std_logic;
    OBS_LB_HAM_BUFFER_ENC_DATA_o   : out std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end entity;

architecture rtl of lb_top is

  -- Control-domain signals
  signal ctrl_cap_en_w          : std_logic;
  signal ctrl_cap_flit_ctrl_w   : std_logic;
  signal ctrl_cap_idx_w         : unsigned(5 downto 0);
  signal ctrl_tx_next_is_read_w : std_logic;
  signal ctrl_tx_flit_sel_w     : std_logic_vector(2 downto 0);

  -- Datapath-domain signals
  signal dp_cap_flit_w       : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal dp_rd_payload_w     : std_logic_vector(31 downto 0);
  signal dp_hold_valid_pulse_w : std_logic;

  signal ctrl_tmr_err_w   : std_logic;
  signal ham_single_err_w : std_logic;
  signal ham_double_err_w : std_logic;
  signal ham_enc_data_w   : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

begin
  u_ctrl_adapter: entity work.lb_ctrl_adapter
    port map(
      lin_data_i       => lin_data_i,
      cap_flit_ctrl_i  => ctrl_cap_flit_ctrl_w,
      tx_flit_sel_i    => ctrl_tx_flit_sel_w,
      tx_next_is_read_i=> ctrl_tx_next_is_read_w,
      rd_payload_i     => dp_rd_payload_w,
      cap_flit_o       => dp_cap_flit_w,
      lout_data_o      => lout_data_o
    );

  u_dp: entity work.lb_dp
    generic map(
      p_USE_LB_HAMMING               => p_USE_LB_HAMMING,
      p_USE_LB_HAMMING_DOUBLE_DETECT => p_USE_LB_HAMMING_DOUBLE_DETECT,
      p_USE_LB_HAMMING_INJECT_ERROR  => p_USE_LB_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      cap_en_i   => ctrl_cap_en_w,
      cap_flit_i => dp_cap_flit_w,
      cap_idx_i  => ctrl_cap_idx_w,
      rd_payload_o => dp_rd_payload_w,

      -- hamming obs/correct
      OBS_LB_HAM_BUFFER_CORRECT_ERROR_i => OBS_LB_HAM_BUFFER_CORRECT_ERROR_i,
      single_err_o     => ham_single_err_w,
      double_err_o     => ham_double_err_w,
      ham_buffer_enc_data_o => ham_enc_data_w,

      -- payload-captured pulse
      hold_valid_o => dp_hold_valid_pulse_w
    );

  gen_ctrl_plain : if (not p_USE_LB_CTRL_TMR) generate
  begin
    ctrl_tmr_err_w <= '0';

    u_ctrl: entity work.lb_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        lin_ctrl_i => lin_data_i(c_FLIT_WIDTH-1),
        lin_val_i  => lin_val_i,
        lin_ack_o  => lin_ack_o,

        lout_val_o  => lout_val_o,
        lout_ack_i  => lout_ack_i,
        tx_next_is_read_o => ctrl_tx_next_is_read_w,
        tx_flit_sel_o     => ctrl_tx_flit_sel_w,

        cap_en_o   => ctrl_cap_en_w,
        cap_flit_ctrl_o => ctrl_cap_flit_ctrl_w,
        cap_idx_o  => ctrl_cap_idx_w,

        hold_valid_i => dp_hold_valid_pulse_w
      );
  end generate;

  gen_ctrl_tmr : if p_USE_LB_CTRL_TMR generate
  begin
    u_ctrl_tmr: entity work.lb_ctrl_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        lin_ctrl_i => lin_data_i(c_FLIT_WIDTH-1),
        lin_val_i  => lin_val_i,
        lin_ack_o  => lin_ack_o,

        lout_val_o  => lout_val_o,
        lout_ack_i  => lout_ack_i,
        tx_next_is_read_o => ctrl_tx_next_is_read_w,
        tx_flit_sel_o     => ctrl_tx_flit_sel_w,

        cap_en_o   => ctrl_cap_en_w,
        cap_flit_ctrl_o => ctrl_cap_flit_ctrl_w,
        cap_idx_o  => ctrl_cap_idx_w,

        hold_valid_i => dp_hold_valid_pulse_w,

        correct_enable_i => OBS_LB_TMR_CTRL_CORRECT_ERROR_i,
        error_o          => ctrl_tmr_err_w
      );
  end generate;

  -- observation outputs (same pattern as TG)
  OBS_LB_TMR_CTRL_ERROR_o        <= ctrl_tmr_err_w;
  OBS_LB_HAM_BUFFER_SINGLE_ERR_o <= ham_single_err_w;
  OBS_LB_HAM_BUFFER_DOUBLE_ERR_o <= ham_double_err_w;
  OBS_LB_HAM_BUFFER_ENC_DATA_o   <= ham_enc_data_w;

end architecture;
