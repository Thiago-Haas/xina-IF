library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Debug loopback controller that intentionally mimics the *working* TBs:
--   * lin_ack is a 1-cycle PULSE per accepted flit (VALID/ACK semantics)
--   * capture: accept hdr0(ctrl=1) first, then keep accepting until checksum(ctrl=1)
--   * response TX: hdr0(ctrl=1), hdr1(ctrl=0), hdr2(ctrl=0), payload(ctrl=0)*, checksum(ctrl=1)
--   * TX handshake: hold VAL until ACK, then drop VAL for >=1 cycle, and wait ACK deassert before next flit
--
-- No special "delay B until read" logic here. TB controls TG/TM sequencing.

entity tg_tm_loopback_controller_dbg is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Request stream from NI (NI -> NoC)
    i_lin_data : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_lin_val  : in  std_logic;
    o_lin_ack  : out std_logic;

    -- Response stream to NI (NoC -> NI)
    o_lout_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_lout_val  : out std_logic;
    i_lout_ack  : in  std_logic;

    -- Capture interface to datapath
    o_cap_en   : out std_logic;  -- 1-cycle pulse when we capture i_lin_data
    o_cap_flit : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_cap_idx  : out unsigned(5 downto 0);
    o_cap_last : out std_logic;  -- 1-cycle pulse on checksum flit (ctrl=1 and idx>0)

    -- Decoded request summary from datapath
    i_req_ready    : in  std_logic; -- not strictly needed, kept for observability
    i_req_is_write : in  std_logic;
    i_req_is_read  : in  std_logic;
    i_req_len      : in  unsigned(7 downto 0);

    -- Response headers from datapath
    i_resp_hdr0 : in  std_logic_vector(31 downto 0);
    i_resp_hdr1 : in  std_logic_vector(31 downto 0);
    i_resp_hdr2 : in  std_logic_vector(31 downto 0);

    -- Payload access
    o_rd_payload_idx : out unsigned(7 downto 0);
    i_rd_payload     : in  std_logic_vector(31 downto 0);

    -- Availability tracking (optional)
    i_hold_valid : in  std_logic;
    o_hold_clr   : out std_logic;

    -- DEBUG
    o_dbg_state         : out std_logic_vector(2 downto 0);
    o_dbg_cap_idx       : out unsigned(5 downto 0);
    o_dbg_seen_last     : out std_logic;
    o_dbg_payload_idx   : out unsigned(7 downto 0);
    o_dbg_payload_words : out unsigned(8 downto 0);
    o_dbg_resp_is_read  : out std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_controller_dbg is

  function flit_ctrl(f : std_logic_vector(c_FLIT_WIDTH-1 downto 0)) return std_logic is
  begin
    return f(f'left);
  end function;

  function mk_flit(ctrl : std_logic; w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH-1 downto 0) := (others => '0');
  begin
    f(f'left) := ctrl;
    f(31 downto 0) := w;
    return f;
  end function;

  type t_state is (
    S_RX_WAIT_VAL,
    S_RX_ACK_HI,
    S_RX_WAIT_DROP,
    S_TX_WAIT_ACK_LO,
    S_TX_PAYLOAD_PREP,
    S_TX_WAIT_ACCEPT,
    S_TX_GAP
  );

  signal st : t_state := S_RX_WAIT_VAL;

  signal r_cap_idx   : unsigned(5 downto 0) := (others => '0');
  signal r_seen_last : std_logic := '0';

  signal r_cap_flit  : std_logic_vector(c_FLIT_WIDTH-1 downto 0) := (others => '0');
  signal p_cap_en    : std_logic := '0';
  signal p_cap_last  : std_logic := '0';

  signal r_lin_ack : std_logic := '0';

  signal r_lout_val  : std_logic := '0';
  signal r_lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0) := (others => '0');

  signal r_tx_idx        : unsigned(8 downto 0) := (others => '0');
  signal r_payload_idx   : unsigned(7 downto 0) := (others => '0');
  signal r_payload_words : unsigned(8 downto 0) := (others => '0');
  signal r_resp_is_read  : std_logic := '0';

  function last_idx(payload_words : unsigned(8 downto 0)) return unsigned is
    variable v : unsigned(8 downto 0);
  begin
    v := to_unsigned(3, 9) + payload_words; -- hdr0,hdr1,hdr2 = 0..2 ; checksum at 3+payload_words
    return v;
  end function;

  function st_to_slv(s : t_state) return std_logic_vector is
  begin
    case s is
      when S_RX_WAIT_VAL    => return "000";
      when S_RX_ACK_HI      => return "001";
      when S_RX_WAIT_DROP   => return "010";
      when S_TX_WAIT_ACK_LO  => return "011";
      when S_TX_PAYLOAD_PREP=> return "100";
      when S_TX_WAIT_ACCEPT => return "101";
      when S_TX_GAP         => return "110";
      when others           => return "111";
    end case;
  end function;

begin

  o_lin_ack   <= r_lin_ack;
  o_lout_val  <= r_lout_val;
  o_lout_data <= r_lout_data;

  o_cap_en   <= p_cap_en;
  o_cap_last <= p_cap_last;
  o_cap_flit <= r_cap_flit;
  o_cap_idx  <= r_cap_idx;

  o_rd_payload_idx <= r_payload_idx;

  -- simplified: do not clear hold in this mode
  o_hold_clr <= '0';

  -- debug exports
  o_dbg_state         <= st_to_slv(st);
  o_dbg_cap_idx       <= r_cap_idx;
  o_dbg_seen_last     <= r_seen_last;
  o_dbg_payload_idx   <= r_payload_idx;
  o_dbg_payload_words <= r_payload_words;
  o_dbg_resp_is_read  <= r_resp_is_read;

  process(ACLK)
    variable v_ctrl        : std_logic;
    variable v_is_checksum : std_logic;
    variable v_last        : unsigned(8 downto 0);
    variable v_payload_idx9: unsigned(8 downto 0);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st <= S_RX_WAIT_VAL;
        r_cap_idx   <= (others => '0');
        r_seen_last <= '0';
        r_cap_flit  <= (others => '0');
        p_cap_en    <= '0';
        p_cap_last  <= '0';
        r_lin_ack   <= '0';

        r_lout_val  <= '0';
        r_lout_data <= (others => '0');

        r_tx_idx        <= (others => '0');
        r_payload_idx   <= (others => '0');
        r_payload_words <= (others => '0');
        r_resp_is_read  <= '0';
      else
        -- default pulses low
        p_cap_en   <= '0';
        p_cap_last <= '0';

        case st is

          -----------------------------------------------------------------
          -- RX
          -----------------------------------------------------------------
          when S_RX_WAIT_VAL =>
            r_lout_val <= '0';
            r_lin_ack  <= '0';

            if i_lin_val = '1' then
              -- Sample flit (TB samples before ACK pulse)
              r_cap_flit <= i_lin_data;
              p_cap_en   <= '1';

              v_ctrl := flit_ctrl(i_lin_data);
              v_is_checksum := '0';

              if (v_ctrl = '1') and (r_cap_idx /= to_unsigned(0, r_cap_idx'length)) then
                v_is_checksum := '1';
              end if;

              if v_is_checksum = '1' then
                p_cap_last <= '1';
                r_seen_last <= '1';
              end if;

              -- 1-cycle ACK pulse
              r_lin_ack <= '1';
              st <= S_RX_ACK_HI;
            end if;

          when S_RX_ACK_HI =>
            -- keep ACK high for exactly one cycle
            r_lin_ack <= '0';
            st <= S_RX_WAIT_DROP;

          when S_RX_WAIT_DROP =>
            r_lin_ack <= '0';
            -- wait for VAL to drop to mark beat boundary
            if i_lin_val = '0' then
              if r_seen_last = '1' then
                -- request fully captured -> arm TX
                r_resp_is_read <= i_req_is_read;
                if i_req_is_read = '1' then
                  r_payload_words <= unsigned('0' & i_req_len) + 1;
                else
                  r_payload_words <= (others => '0');
                end if;

                r_tx_idx      <= (others => '0');
                r_payload_idx <= (others => '0');

                -- reset capture counters
                r_cap_idx   <= (others => '0');
                r_seen_last <= '0';

                st <= S_TX_WAIT_ACK_LO;
              else
                r_cap_idx <= r_cap_idx + 1;
                st <= S_RX_WAIT_VAL;
              end if;
            end if;

          -----------------------------------------------------------------
          -- TX
          -----------------------------------------------------------------
          when S_TX_WAIT_ACK_LO =>
            r_lin_ack  <= '0';
            r_lout_val <= '0';

            if i_lout_ack = '0' then
              v_last := last_idx(r_payload_words);

              if r_tx_idx = to_unsigned(0, 9) then
                r_lout_data <= mk_flit('1', i_resp_hdr0);
                r_lout_val  <= '1';
                st <= S_TX_WAIT_ACCEPT;
              elsif r_tx_idx = to_unsigned(1, 9) then
                r_lout_data <= mk_flit('0', i_resp_hdr1);
                r_lout_val  <= '1';
                st <= S_TX_WAIT_ACCEPT;
              elsif r_tx_idx = to_unsigned(2, 9) then
                r_lout_data <= mk_flit('0', i_resp_hdr2);
                r_lout_val  <= '1';
                st <= S_TX_WAIT_ACCEPT;
              elsif r_tx_idx = v_last then
                r_lout_data <= mk_flit('1', (others => '0')); -- checksum
                r_lout_val  <= '1';
                st <= S_TX_WAIT_ACCEPT;
              else
                -- payload beat: program index, then wait one cycle (TB-like) before sending
                v_payload_idx9 := r_tx_idx - to_unsigned(3, 9);
                r_payload_idx  <= v_payload_idx9(7 downto 0);
                st <= S_TX_PAYLOAD_PREP;
              end if;
            end if;

          when S_TX_PAYLOAD_PREP =>
            -- payload word is now available on i_rd_payload (combinational from datapath)
            r_lout_val <= '0';
            if i_lout_ack = '0' then
              r_lout_data <= mk_flit('0', i_rd_payload);
              r_lout_val  <= '1';
              st <= S_TX_WAIT_ACCEPT;
            end if;

          when S_TX_WAIT_ACCEPT =>
            -- hold VAL until accepted
            if i_lout_ack = '1' then
              r_lout_val <= '0';
              st <= S_TX_GAP;
            end if;

          when S_TX_GAP =>
            -- enforce one full cycle with VAL=0
            v_last := last_idx(r_payload_words);
            if r_tx_idx = v_last then
              -- done
              st <= S_RX_WAIT_VAL;
              r_lout_val <= '0';
            else
              r_tx_idx <= r_tx_idx + 1;
              st <= S_TX_WAIT_ACK_LO;
            end if;

          when others =>
            st <= S_RX_WAIT_VAL;

        end case;
      end if;
    end if;
  end process;

end architecture;
