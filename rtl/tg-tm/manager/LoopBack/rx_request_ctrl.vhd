library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- RX-side controller: receives a full request packet (hdr0,hdr1,hdr2,addr,[payload],checksum)
-- and generates 1-cycle datapath strobes to capture words.
-- Generates a 1-cycle o_done pulse once the checksum word is accepted.
--
-- NOTE ABOUT lin_val/lin_ack:
-- Some NI implementations do not guarantee that the first flit (hdr0) will be held
-- stable until lin_ack goes high. If lin_ack is deasserted while waiting for the first
-- flit, hdr0 can be missed and the FSM desynchronizes (symptom: only hdr0 appears then
-- the transaction stalls).
--
-- To make the loopback robust, this controller advertises readiness (lin_ack='1')
-- whenever enabled, and it handshakes hdr0 directly in the first state.
entity rx_request_ctrl is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_enable : in std_logic;

    -- RX (from NI)
    lin_val  : in  std_logic;
    lin_ack  : out std_logic;

    -- pulse for top to latch i_rx_word
    o_rx_fire : out std_logic;

    -- datapath strobes (1-cycle pulses)
    o_dp_store_hdr0   : out std_logic;
    o_dp_store_hdr1   : out std_logic;
    o_dp_store_hdr2   : out std_logic;
    o_dp_store_addr   : out std_logic;
    o_dp_store_pld    : out std_logic;
    o_dp_set_meta     : out std_logic;
    o_dp_commit_write : out std_logic;

    o_dp_pld_widx : out unsigned(15 downto 0);

    -- decoded from datapath
    i_dp_req_is_write : in std_logic;
    i_dp_req_is_read  : in std_logic;
    i_dp_req_len      : in unsigned(7 downto 0);

    -- latched request info for TX side (stable until next request)
    o_is_read_resp  : out std_logic;
    o_payload_words : out unsigned(15 downto 0);

    o_done : out std_logic
  );
end entity;

architecture rtl of rx_request_ctrl is
  type t_state is (s_hdr0, s_hdr1, s_hdr2, s_addr, s_payload, s_checksum);
  signal st : t_state := s_hdr0;

  signal widx         : unsigned(15 downto 0) := (others => '0');
  signal payload_left : unsigned(15 downto 0) := (others => '0');

  signal r_is_read_resp  : std_logic := '0';
  signal r_payload_words : unsigned(15 downto 0) := (others => '0');
  signal r_done          : std_logic := '0';

  -- pulses
  signal p_hdr0, p_hdr1, p_hdr2, p_addr, p_pld, p_setmeta, p_commit : std_logic := '0';

  -- internal ack (avoid reading OUT port in synthesis)
  signal ack_i : std_logic := '0';
  signal rx_hs : std_logic := '0';

  function u16(x : unsigned(7 downto 0)) return unsigned is
    variable v : unsigned(15 downto 0);
  begin
    v := (others => '0');
    v(7 downto 0) := x;
    return v;
  end function;
begin
  -- Always ready while enabled.
  ack_i   <= '1' when (i_enable = '1') else '0';
  lin_ack <= ack_i;

  rx_hs     <= lin_val and ack_i;
  o_rx_fire <= rx_hs;

  o_dp_store_hdr0   <= p_hdr0;
  o_dp_store_hdr1   <= p_hdr1;
  o_dp_store_hdr2   <= p_hdr2;
  o_dp_store_addr   <= p_addr;
  o_dp_store_pld    <= p_pld;
  o_dp_set_meta     <= p_setmeta;
  o_dp_commit_write <= p_commit;

  o_dp_pld_widx <= widx;

  o_is_read_resp  <= r_is_read_resp;
  o_payload_words <= r_payload_words;
  o_done          <= r_done;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st <= s_hdr0;
        widx <= (others => '0');
        payload_left <= (others => '0');
        r_is_read_resp <= '0';
        r_payload_words <= (others => '0');
        r_done <= '0';

        p_hdr0 <= '0'; p_hdr1 <= '0'; p_hdr2 <= '0'; p_addr <= '0';
        p_pld <= '0'; p_setmeta <= '0'; p_commit <= '0';
      else
        -- default pulses low
        p_hdr0 <= '0'; p_hdr1 <= '0'; p_hdr2 <= '0'; p_addr <= '0';
        p_pld <= '0'; p_setmeta <= '0'; p_commit <= '0';
        r_done <= '0';

        if i_enable = '0' then
          st <= s_hdr0;
          widx <= (others => '0');
          payload_left <= (others => '0');
        else
          case st is
            when s_hdr0 =>
              if rx_hs = '1' then
                p_hdr0 <= '1';
                st <= s_hdr1;
              end if;

            when s_hdr1 =>
              if rx_hs = '1' then
                p_hdr1 <= '1';
                st <= s_hdr2;
              end if;

            when s_hdr2 =>
              if rx_hs = '1' then
                p_hdr2    <= '1';
                p_setmeta <= '1';
                st <= s_addr;
              end if;

            when s_addr =>
              if rx_hs = '1' then
                p_addr <= '1';
                if i_dp_req_is_write = '1' then
                  widx <= (others => '0');
                  payload_left <= u16(i_dp_req_len) + 1; -- LEN+1 payload words
                  st <= s_payload;
                else
                  st <= s_checksum;
                end if;
              end if;

            when s_payload =>
              if rx_hs = '1' then
                p_pld <= '1';
                widx <= widx + 1;
                if payload_left = 1 then
                  p_commit <= '1';
                  st <= s_checksum;
                end if;
                payload_left <= payload_left - 1;
              end if;

            when s_checksum =>
              if rx_hs = '1' then
                r_is_read_resp <= i_dp_req_is_read;
                if i_dp_req_is_read = '1' then
                  r_payload_words <= u16(i_dp_req_len) + 1;
                else
                  r_payload_words <= (others => '0');
                end if;

                r_done <= '1';
                st <= s_hdr0;
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;

end rtl;
