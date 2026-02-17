library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Controller hierarchy:
--   rx_request_ctrl  : receives request packet and emits dp_store_* strobes
--   tx_response_ctrl : sends response packet using tx_sel to select datapath words
--   (this wrapper)   : single-outstanding orchestration + latching of rx->tx parameters
entity manager_loopback_controller is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- RX (from NI)
    lin_val  : in  std_logic;
    lin_ack  : out std_logic;
    lin_data : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    -- TX (to NI)
    lout_ack : in  std_logic;
    lout_val : out std_logic;
    tx_sel   : out unsigned(2 downto 0);

    -- pulse for top to latch i_rx_word
    rx_fire : out std_logic;

    -- datapath strobes (1-cycle pulses)
    dp_store_hdr0   : out std_logic;
    dp_store_hdr1   : out std_logic;
    dp_store_hdr2   : out std_logic;
    dp_store_addr   : out std_logic;
    dp_store_pld    : out std_logic;
    dp_set_meta     : out std_logic;
    dp_commit_write : out std_logic;

    dp_pld_widx : out unsigned(15 downto 0);
    dp_pld_ridx : out unsigned(15 downto 0);

    -- decoded from datapath after hdr2
    dp_req_is_write : in std_logic;
    dp_req_is_read  : in std_logic;
    dp_req_len      : in unsigned(7 downto 0);

    -- hold info (available)
    dp_hold_len   : in unsigned(7 downto 0);
    dp_hold_valid : in std_logic
  );
end entity;

architecture rtl of manager_loopback_controller is
  -- mode: 0 = receiving request, 1 = transmitting response
  signal mode_tx : std_logic := '0';

  -- RX side
  signal rx_ack   : std_logic;
  signal rx_fire_i: std_logic;
  signal rx_done  : std_logic;

  signal rx_dp_store_hdr0   : std_logic;
  signal rx_dp_store_hdr1   : std_logic;
  signal rx_dp_store_hdr2   : std_logic;
  signal rx_dp_store_addr   : std_logic;
  signal rx_dp_store_pld    : std_logic;
  signal rx_dp_set_meta     : std_logic;
  signal rx_dp_commit_write : std_logic;
  signal rx_widx            : unsigned(15 downto 0);

  signal rx_is_read_resp    : std_logic;
  signal rx_payload_words   : unsigned(15 downto 0);

  -- Latched info for TX
  signal r_is_read_resp  : std_logic := '0';
  signal r_payload_words : unsigned(15 downto 0) := (others => '0');

  -- TX side
  signal tx_done  : std_logic;
  signal tx_val   : std_logic;
  signal tx_sel_i : unsigned(2 downto 0);
  signal tx_ridx  : unsigned(15 downto 0);
  signal tx_start : std_logic := '0';
begin
  -- datapath strobes from RX block
  dp_store_hdr0   <= rx_dp_store_hdr0;
  dp_store_hdr1   <= rx_dp_store_hdr1;
  dp_store_hdr2   <= rx_dp_store_hdr2;
  dp_store_addr   <= rx_dp_store_addr;
  dp_store_pld    <= rx_dp_store_pld;
  dp_set_meta     <= rx_dp_set_meta;
  dp_commit_write <= rx_dp_commit_write;

  dp_pld_widx <= rx_widx;
  dp_pld_ridx <= tx_ridx;

  -- outputs
  lin_ack  <= rx_ack;
  lout_val <= tx_val;
  tx_sel   <= tx_sel_i;
  rx_fire  <= rx_fire_i;

  -- NOTE: lin_data is captured by the TOP when rx_fire pulses; controller doesn't need lin_data directly.

  u_RX: entity work.rx_request_ctrl
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_enable => not mode_tx,

      lin_val  => lin_val,
      lin_ack  => rx_ack,

      o_rx_fire => rx_fire_i,

      o_dp_store_hdr0   => rx_dp_store_hdr0,
      o_dp_store_hdr1   => rx_dp_store_hdr1,
      o_dp_store_hdr2   => rx_dp_store_hdr2,
      o_dp_store_addr   => rx_dp_store_addr,
      o_dp_store_pld    => rx_dp_store_pld,
      o_dp_set_meta     => rx_dp_set_meta,
      o_dp_commit_write => rx_dp_commit_write,

      o_dp_pld_widx => rx_widx,

      i_dp_req_is_write => dp_req_is_write,
      i_dp_req_is_read  => dp_req_is_read,
      i_dp_req_len      => dp_req_len,

      o_is_read_resp  => rx_is_read_resp,
      o_payload_words => rx_payload_words,

      o_done => rx_done
    );

  u_TX: entity work.tx_response_ctrl
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_enable => mode_tx,
      i_start  => tx_start,

      lout_ack => lout_ack,
      lout_val => tx_val,
      tx_sel   => tx_sel_i,

      o_dp_pld_ridx => tx_ridx,

      i_is_read_resp  => r_is_read_resp,
      i_payload_words => r_payload_words,

      o_done => tx_done
    );

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        mode_tx <= '0';
        r_is_read_resp <= '0';
        r_payload_words <= (others => '0');
        tx_start <= '0';
      else
        tx_start <= '0';

        if mode_tx = '0' then
          if rx_done = '1' then
            r_is_read_resp  <= rx_is_read_resp;
            r_payload_words <= rx_payload_words;

            mode_tx <= '1';
            tx_start <= '1';
          end if;
        else
          if tx_done = '1' then
            mode_tx <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

end rtl;
