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
    i_OBS_LB_HAM_BUFFER_CORRECT_ERROR : in  std_logic := '1';
    i_OBS_LB_TMR_CTRL_CORRECT_ERROR   : in  std_logic := '1';

    o_OBS_LB_TMR_CTRL_ERROR        : out std_logic;
    o_OBS_LB_HAM_BUFFER_SINGLE_ERR : out std_logic;
    o_OBS_LB_HAM_BUFFER_DOUBLE_ERR : out std_logic;
    o_OBS_LB_HAM_BUFFER_ENC_DATA   : out std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0)
  );
end entity;

architecture rtl of lb_top is

  signal cap_en   : std_logic;
  signal cap_flit_ctrl : std_logic;
  signal cap_flit : std_logic_vector(c_FLIT_WIDTH-1 downto 0);

  signal rd_payload_idx : unsigned(7 downto 0);
  signal rd_payload     : std_logic_vector(31 downto 0);

  signal hold_valid_pulse : std_logic; -- DP pulse when payload captured
  signal hold_clr         : std_logic;
  signal tx_next_is_read  : std_logic;
  signal tx_has_payload   : std_logic;

  signal w_ctrl_tmr_err   : std_logic;
  signal w_ham_single_err : std_logic;
  signal w_ham_double_err : std_logic;
  signal w_ham_enc_data   : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

begin
  rd_payload_idx <= (others => '0');

  u_ctrl_adapter: entity work.lb_ctrl_adapter
    port map(
      ACLK             => ACLK,
      ARESETn          => ARESETn,
      i_lin_data       => lin_data_i,
      i_cap_flit_ctrl  => cap_flit_ctrl,
      i_lout_val       => lout_val_o,
      i_lout_ack       => lout_ack_i,
      i_tx_next_is_read=> tx_next_is_read,
      i_tx_has_payload => tx_has_payload,
      i_rd_payload     => rd_payload,
      o_cap_flit       => cap_flit,
      o_lout_data      => lout_data_o
    );

  u_dp: entity work.lb_dp
    generic map(
      p_MEM_ADDR_BITS       => p_MEM_ADDR_BITS,
      p_USE_LB_HAMMING               => p_USE_LB_HAMMING,
      p_USE_LB_HAMMING_DOUBLE_DETECT => p_USE_LB_HAMMING_DOUBLE_DETECT,
      p_USE_LB_HAMMING_INJECT_ERROR  => p_USE_LB_HAMMING_INJECT_ERROR
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_cap_en   => cap_en,
      i_cap_flit => cap_flit,
      i_cap_last => '0',

      o_req_ready    => open,
      o_req_is_write => open,
      o_req_is_read  => open,
      o_req_len      => open,
      o_req_burst    => open,
      o_req_base_idx => open,

      i_rd_payload_idx => rd_payload_idx,
      o_rd_payload     => rd_payload,

      o_resp_hdr0 => open,
      o_resp_hdr1 => open,
      o_resp_hdr2 => open,

      -- hamming obs/correct
      i_OBS_LB_HAM_BUFFER_CORRECT_ERROR => i_OBS_LB_HAM_BUFFER_CORRECT_ERROR,
      o_single_err     => w_ham_single_err,
      o_double_err     => w_ham_double_err,
      o_ham_buffer_enc_data => w_ham_enc_data,

      -- payload-captured pulse
      o_hold_valid => hold_valid_pulse,
      i_hold_clr   => hold_clr
    );

  gen_ctrl_plain : if (not p_USE_LB_CTRL_TMR) generate
  begin
    w_ctrl_tmr_err <= '0';

    u_ctrl: entity work.lb_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_lin_ctrl => lin_data_i(c_FLIT_WIDTH-1),
        i_lin_val  => lin_val_i,
        o_lin_ack  => lin_ack_o,

        o_lout_val  => lout_val_o,
        i_lout_ack  => lout_ack_i,
        o_tx_next_is_read => tx_next_is_read,
        o_tx_has_payload  => tx_has_payload,

        o_cap_en   => cap_en,
        o_cap_flit_ctrl => cap_flit_ctrl,

        i_hold_valid => hold_valid_pulse,
        o_hold_clr   => hold_clr
      );
  end generate;

  gen_ctrl_tmr : if p_USE_LB_CTRL_TMR generate
  begin
    u_ctrl_tmr: entity work.lb_ctrl_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_lin_ctrl => lin_data_i(c_FLIT_WIDTH-1),
        i_lin_val  => lin_val_i,
        o_lin_ack  => lin_ack_o,

        o_lout_val  => lout_val_o,
        i_lout_ack  => lout_ack_i,
        o_tx_next_is_read => tx_next_is_read,
        o_tx_has_payload  => tx_has_payload,

        o_cap_en   => cap_en,
        o_cap_flit_ctrl => cap_flit_ctrl,

        i_hold_valid => hold_valid_pulse,
        o_hold_clr   => hold_clr,

        i_correct_enable => i_OBS_LB_TMR_CTRL_CORRECT_ERROR,
        error_o          => w_ctrl_tmr_err
      );
  end generate;

  -- observation outputs (same pattern as TG)
  o_OBS_LB_TMR_CTRL_ERROR        <= w_ctrl_tmr_err;
  o_OBS_LB_HAM_BUFFER_SINGLE_ERR <= w_ham_single_err;
  o_OBS_LB_HAM_BUFFER_DOUBLE_ERR <= w_ham_double_err;
  o_OBS_LB_HAM_BUFFER_ENC_DATA   <= w_ham_enc_data;

end architecture;
