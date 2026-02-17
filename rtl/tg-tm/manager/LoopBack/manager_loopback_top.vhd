library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Connect to NI NoC-side:
--   NI.l_in_*  -> loopback.lin_*   (NI -> loopback RX)
--   NI.l_out_* <- loopback.lout_*  (loopback TX -> NI)
entity manager_loopback_top is
  generic(
    p_MAX_PAYLOAD_WORDS : natural := 256
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- RX from NI (NI -> "NoC")
    lin_data : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    lin_val  : in  std_logic;
    lin_ack  : out std_logic;

    -- TX to NI ("NoC" -> NI)
    lout_data : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    lout_val  : out std_logic;
    lout_ack  : in  std_logic
  );
end entity;

architecture rtl of manager_loopback_top is
  -- controller <-> datapath
  signal dp_store_hdr0   : std_logic;
  signal dp_store_hdr1   : std_logic;
  signal dp_store_hdr2   : std_logic;
  signal dp_store_addr   : std_logic;
  signal dp_store_pld    : std_logic;
  signal dp_set_meta     : std_logic;
  signal dp_commit_write : std_logic;

  signal dp_pld_widx : unsigned(15 downto 0);
  signal dp_pld_ridx : unsigned(15 downto 0);

  signal dp_rx_word : std_logic_vector(31 downto 0);

  signal dp_req_is_write : std_logic;
  signal dp_req_is_read  : std_logic;
  signal dp_req_len      : unsigned(7 downto 0);
  signal dp_hold_len     : unsigned(7 downto 0);
  signal dp_hold_valid   : std_logic;

  signal dp_tx_word : std_logic_vector(31 downto 0);
  signal dp_tx_ctrl : std_logic;

  signal ctrl_rx_fire : std_logic;
  signal ctrl_tx_sel  : unsigned(2 downto 0);
  signal ctrl_tx_valid: std_logic;

begin
  u_DP: entity work.manager_loopback_datapath
    generic map(
      p_MAX_PAYLOAD_WORDS => p_MAX_PAYLOAD_WORDS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_rx_word => dp_rx_word,

      i_store_hdr0   => dp_store_hdr0,
      i_store_hdr1   => dp_store_hdr1,
      i_store_hdr2   => dp_store_hdr2,
      i_store_addr   => dp_store_addr,
      i_store_pld    => dp_store_pld,
      i_set_meta     => dp_set_meta,
      i_commit_write => dp_commit_write,

      i_pld_widx => dp_pld_widx,
      i_pld_ridx => dp_pld_ridx,

      o_req_is_write => dp_req_is_write,
      o_req_is_read  => dp_req_is_read,
      o_req_len      => dp_req_len,

      o_hold_len   => dp_hold_len,
      o_hold_valid => dp_hold_valid,

      i_tx_sel  => ctrl_tx_sel,
      o_tx_word => dp_tx_word,
      o_tx_ctrl => dp_tx_ctrl
    );

  u_CTRL: entity work.manager_loopback_controller
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_val  => lin_val,
      lin_ack  => lin_ack,
      lin_data => lin_data,

      lout_ack   => lout_ack,
      lout_val   => ctrl_tx_valid,
      tx_sel     => ctrl_tx_sel,

      rx_fire => ctrl_rx_fire,

      dp_store_hdr0   => dp_store_hdr0,
      dp_store_hdr1   => dp_store_hdr1,
      dp_store_hdr2   => dp_store_hdr2,
      dp_store_addr   => dp_store_addr,
      dp_store_pld    => dp_store_pld,
      dp_set_meta     => dp_set_meta,
      dp_commit_write => dp_commit_write,

      dp_pld_widx => dp_pld_widx,
      dp_pld_ridx => dp_pld_ridx,

      dp_req_is_write => dp_req_is_write,
      dp_req_is_read  => dp_req_is_read,
      dp_req_len      => dp_req_len,

      dp_hold_len   => dp_hold_len,
      dp_hold_valid => dp_hold_valid
    );

  -- latch incoming word32 on RX handshake
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        dp_rx_word <= (others => '0');
      else
        if ctrl_rx_fire = '1' then
          dp_rx_word <= lin_data(31 downto 0);
        end if;
      end if;
    end if;
  end process;

  -- drive TX flit = {ctrl, word}
  lout_val  <= ctrl_tx_valid;
  lout_data <= dp_tx_ctrl & dp_tx_word;

end rtl;