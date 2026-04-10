library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- Datapath/storage for the subordinate AXI loopback. The control block owns
-- handshakes; this block owns the single payload slot and ID return fields.
entity subordinate_axi_loopback_datapath is
  generic(
    p_USE_PAYLOAD_HAMMING : boolean := c_ENABLE_SUB_LB_PAYLOAD_HAMMING;
    p_USE_RDATA_HAMMING   : boolean := c_ENABLE_SUB_LB_RDATA_HAMMING;
    p_USE_ID_STATE_HAMMING : boolean := c_ENABLE_SUB_LB_ID_STATE_HAMMING;
    p_USE_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT;
    p_USE_PAYLOAD_HAMMING_INJECT_ERROR : boolean := c_ENABLE_SUB_LB_PAYLOAD_HAMMING_INJECT_ERROR;
    p_USE_RDATA_HAMMING_INJECT_ERROR   : boolean := c_ENABLE_SUB_LB_RDATA_HAMMING_INJECT_ERROR;
    p_USE_ID_STATE_HAMMING_INJECT_ERROR : boolean := c_ENABLE_SUB_LB_ID_STATE_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    aw_accept_i : in std_logic;
    w_accept_i  : in std_logic;
    ar_accept_i : in std_logic;

    AWID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);

    WDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST  : in  std_logic;

    BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    ARID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);

    RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o      : out std_logic := '0';
    OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o      : out std_logic := '0';
    OBS_SUB_LB_HAM_RDATA_ENC_DATA_o        : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o      : out std_logic_vector((3 * c_AXI_ID_WIDTH) + work.hamming_pkg.get_ecc_size(3 * c_AXI_ID_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0')
  );
end entity;

architecture rtl of subordinate_axi_loopback_datapath is
  constant C_AXI_RESP_OKAY : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
  constant C_ID_STATE_WIDTH : natural := 3 * c_AXI_ID_WIDTH;

  signal payload_w     : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rdata_w       : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal id_state_w    : std_logic_vector(C_ID_STATE_WIDTH - 1 downto 0);
  signal id_state_next_w : std_logic_vector(C_ID_STATE_WIDTH - 1 downto 0);
  signal id_state_we_w : std_logic;

  signal write_id_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bid_w         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rid_w         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);

  signal payload_single_err_w : std_logic;
  signal payload_double_err_w : std_logic;
  signal payload_enc_data_w   : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal rdata_single_err_w   : std_logic;
  signal rdata_double_err_w   : std_logic;
  signal rdata_enc_data_w     : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
  signal id_state_single_err_w : std_logic;
  signal id_state_double_err_w : std_logic;
  signal id_state_enc_data_w   : std_logic_vector(C_ID_STATE_WIDTH + work.hamming_pkg.get_ecc_size(C_ID_STATE_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);
begin
  write_id_w <= id_state_w((3 * c_AXI_ID_WIDTH) - 1 downto 2 * c_AXI_ID_WIDTH);
  bid_w      <= id_state_w((2 * c_AXI_ID_WIDTH) - 1 downto c_AXI_ID_WIDTH);
  rid_w      <= id_state_w(c_AXI_ID_WIDTH - 1 downto 0);

  BID   <= bid_w;
  BRESP <= C_AXI_RESP_OKAY;
  RID   <= rid_w;
  RDATA <= rdata_w;
  RRESP <= C_AXI_RESP_OKAY;

  process(id_state_w, aw_accept_i, w_accept_i, ar_accept_i, AWID, ARID, write_id_w)
    variable id_state_v : std_logic_vector(C_ID_STATE_WIDTH - 1 downto 0);
  begin
    id_state_v := id_state_w;

    if aw_accept_i = '1' then
      id_state_v((3 * c_AXI_ID_WIDTH) - 1 downto 2 * c_AXI_ID_WIDTH) := AWID;
    end if;

    if w_accept_i = '1' then
      id_state_v((2 * c_AXI_ID_WIDTH) - 1 downto c_AXI_ID_WIDTH) := write_id_w;
    end if;

    if ar_accept_i = '1' then
      id_state_v(c_AXI_ID_WIDTH - 1 downto 0) := ARID;
    end if;

    id_state_next_w <= id_state_v;
  end process;

  id_state_we_w <= aw_accept_i or w_accept_i or ar_accept_i;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if w_accept_i = '1' then
        assert WLAST = '1'
          report "subordinate_axi_loopback expects one-beat WLAST=1 traffic"
          severity warning;
      end if;
    end if;
  end process;

  u_payload_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_DATA_WIDTH,
      HAMMING_ENABLE => p_USE_PAYLOAD_HAMMING,
      DETECT_DOUBLE  => p_USE_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_AXI_DATA_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_PAYLOAD_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i,
      write_en_i   => w_accept_i,
      data_i       => WDATA,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => payload_single_err_w,
      double_err_o => payload_double_err_w,
      enc_data_o   => payload_enc_data_w,
      data_o       => payload_w
    );

  u_rdata_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_DATA_WIDTH,
      HAMMING_ENABLE => p_USE_RDATA_HAMMING,
      DETECT_DOUBLE  => p_USE_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_AXI_DATA_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_RDATA_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i,
      write_en_i   => ar_accept_i,
      data_i       => payload_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => rdata_single_err_w,
      double_err_o => rdata_double_err_w,
      enc_data_o   => rdata_enc_data_w,
      data_o       => rdata_w
    );

  u_id_state_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => C_ID_STATE_WIDTH,
      HAMMING_ENABLE => p_USE_ID_STATE_HAMMING,
      DETECT_DOUBLE  => p_USE_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (C_ID_STATE_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_ID_STATE_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i,
      write_en_i   => id_state_we_w,
      data_i       => id_state_next_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => id_state_single_err_w,
      double_err_o => id_state_double_err_w,
      enc_data_o   => id_state_enc_data_w,
      data_o       => id_state_w
    );

  OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o <= payload_single_err_w;
  OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o <= payload_double_err_w;
  OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o   <= payload_enc_data_w;
  OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o   <= rdata_single_err_w;
  OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o   <= rdata_double_err_w;
  OBS_SUB_LB_HAM_RDATA_ENC_DATA_o     <= rdata_enc_data_w;
  OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o <= id_state_single_err_w;
  OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o <= id_state_double_err_w;
  OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o   <= id_state_enc_data_w;
end architecture;
