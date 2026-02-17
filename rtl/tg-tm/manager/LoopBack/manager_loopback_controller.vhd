library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Single outstanding packet:
-- RX full request -> TX response.
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

    -- hold info (currently not used for gating, but available)
    dp_hold_len   : in unsigned(7 downto 0);
    dp_hold_valid : in std_logic
  );
end entity;

architecture rtl of manager_loopback_controller is
  type t_state is (
    s_idle,
    s_rx_hdr0, s_rx_hdr1, s_rx_hdr2,
    s_rx_addr,
    s_rx_payload,
    s_rx_checksum,
    s_tx_hdr0, s_tx_hdr1, s_tx_hdr2,
    s_tx_payload,
    s_tx_checksum
  );

  signal st : t_state := s_idle;

  signal widx : unsigned(15 downto 0) := (others => '0');
  signal ridx : unsigned(15 downto 0) := (others => '0');
  signal payload_left : unsigned(15 downto 0) := (others => '0');

  signal r_is_read_resp : std_logic := '0';

  signal r_dp_store_hdr0   : std_logic := '0';
  signal r_dp_store_hdr1   : std_logic := '0';
  signal r_dp_store_hdr2   : std_logic := '0';
  signal r_dp_store_addr   : std_logic := '0';
  signal r_dp_store_pld    : std_logic := '0';
  signal r_dp_set_meta     : std_logic := '0';
  signal r_dp_commit_write : std_logic := '0';

  function u16(x : unsigned(7 downto 0)) return unsigned is
    variable v : unsigned(15 downto 0);
  begin
    v := (others => '0');
    v(7 downto 0) := x;
    return v;
  end function;

  signal rx_hs : std_logic;
  signal tx_hs : std_logic;

begin
  dp_store_hdr0   <= r_dp_store_hdr0;
  dp_store_hdr1   <= r_dp_store_hdr1;
  dp_store_hdr2   <= r_dp_store_hdr2;
  dp_store_addr   <= r_dp_store_addr;
  dp_store_pld    <= r_dp_store_pld;
  dp_set_meta     <= r_dp_set_meta;
  dp_commit_write <= r_dp_commit_write;

  dp_pld_widx <= widx;
  dp_pld_ridx <= ridx;

  -- combinational handshake qualifiers
  rx_hs   <= lin_val and lin_ack;
  tx_hs   <= lout_val and lout_ack;
  rx_fire <= rx_hs;

  -- combinational outputs based on state
  process(all)
  begin
    lin_ack  <= '0';
    lout_val <= '0';
    tx_sel   <= (others => '0');

    case st is
      when s_idle =>
        lin_ack <= '1';

      when s_rx_hdr0 | s_rx_hdr1 | s_rx_hdr2 | s_rx_addr | s_rx_payload | s_rx_checksum =>
        lin_ack <= '1';

      when s_tx_hdr0 =>
        lout_val <= '1'; tx_sel <= "000"; -- hdr0
      when s_tx_hdr1 =>
        lout_val <= '1'; tx_sel <= "001"; -- hdr1
      when s_tx_hdr2 =>
        lout_val <= '1'; tx_sel <= "010"; -- hdr2
      when s_tx_payload =>
        lout_val <= '1'; tx_sel <= "011"; -- payload
      when s_tx_checksum =>
        lout_val <= '1'; tx_sel <= "100"; -- checksum
    end case;
  end process;

  -- sequential state / strobes
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st <= s_idle;
        widx <= (others => '0');
        ridx <= (others => '0');
        payload_left <= (others => '0');
        r_is_read_resp <= '0';

        r_dp_store_hdr0 <= '0';
        r_dp_store_hdr1 <= '0';
        r_dp_store_hdr2 <= '0';
        r_dp_store_addr <= '0';
        r_dp_store_pld  <= '0';
        r_dp_set_meta   <= '0';
        r_dp_commit_write <= '0';
      else
        -- default pulses low
        r_dp_store_hdr0 <= '0';
        r_dp_store_hdr1 <= '0';
        r_dp_store_hdr2 <= '0';
        r_dp_store_addr <= '0';
        r_dp_store_pld  <= '0';
        r_dp_set_meta   <= '0';
        r_dp_commit_write <= '0';

        case st is
          when s_idle =>
            if lin_val = '1' then
              st <= s_rx_hdr0;
            end if;

          when s_rx_hdr0 =>
            if rx_hs='1' then
              r_dp_store_hdr0 <= '1';
              st <= s_rx_hdr1;
            end if;

          when s_rx_hdr1 =>
            if rx_hs='1' then
              r_dp_store_hdr1 <= '1';
              st <= s_rx_hdr2;
            end if;

          when s_rx_hdr2 =>
            if rx_hs='1' then
              r_dp_store_hdr2 <= '1';
              r_dp_set_meta   <= '1'; -- decode OP/TYPE/LEN from THIS word
              st <= s_rx_addr;
            end if;

          when s_rx_addr =>
            if rx_hs='1' then
              r_dp_store_addr <= '1';
              if dp_req_is_write='1' then
                widx <= (others => '0');
                payload_left <= u16(dp_req_len) + 1; -- LEN+1 payload words
                st <= s_rx_payload;
              else
                -- read request has no payload
                st <= s_rx_checksum;
              end if;
            end if;

          when s_rx_payload =>
            if rx_hs='1' then
              r_dp_store_pld <= '1';
              widx <= widx + 1;
              if payload_left = 1 then
                r_dp_commit_write <= '1'; -- commit hold len/valid
                st <= s_rx_checksum;
              end if;
              payload_left <= payload_left - 1;
            end if;

          when s_rx_checksum =>
            if rx_hs='1' then
              -- checksum ignored
              r_is_read_resp <= dp_req_is_read;
              ridx <= (others => '0');
              if dp_req_is_read='1' then
                payload_left <= u16(dp_req_len) + 1; -- response payload length
              else
                payload_left <= (others => '0');
              end if;
              st <= s_tx_hdr0;
            end if;

          when s_tx_hdr0 =>
            if tx_hs='1' then st <= s_tx_hdr1; end if;

          when s_tx_hdr1 =>
            if tx_hs='1' then st <= s_tx_hdr2; end if;

          when s_tx_hdr2 =>
            if tx_hs='1' then
              if r_is_read_resp='1' then
                st <= s_tx_payload;
              else
                st <= s_tx_checksum;
              end if;
            end if;

          when s_tx_payload =>
            if tx_hs='1' then
              ridx <= ridx + 1;
              if payload_left = 1 then
                st <= s_tx_checksum;
              end if;
              payload_left <= payload_left - 1;
            end if;

          when s_tx_checksum =>
            if tx_hs='1' then
              st <= s_idle;
            end if;
        end case;
      end if;
    end if;
  end process;
end rtl;