library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Ultra-minimal loopback controller (NON-DBG)
--  * TB-faithful RX: lin_ack is a 1-cycle pulse per accepted flit and we wait for lin_val to drop.
--  * TX: hold lout_val until lout_ack, force a 1-cycle gap, then next flit.
--  * Response headers/hdr2 are CONSTANTS; only payload comes from datapath.
--  * Assumes fixed traffic pattern: WRITE request then READ request then repeats.
entity lb_ctrl is
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
    o_cap_en   : out std_logic;
    o_cap_flit : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_cap_idx  : out unsigned(5 downto 0);
    o_cap_last : out std_logic;

    -- Decoded request summary from datapath (unused)
    i_req_ready    : in  std_logic;
    i_req_is_write : in  std_logic;
    i_req_is_read  : in  std_logic;
    i_req_len      : in  unsigned(7 downto 0);

    -- Response headers from datapath (unused)
    i_resp_hdr0 : in  std_logic_vector(31 downto 0);
    i_resp_hdr1 : in  std_logic_vector(31 downto 0);
    i_resp_hdr2 : in  std_logic_vector(31 downto 0);

    -- Payload access
    o_rd_payload_idx : out unsigned(7 downto 0);
    i_rd_payload     : in  std_logic_vector(31 downto 0);

    -- Availability tracking (optional)
    i_hold_valid : in  std_logic;
    o_hold_clr   : out std_logic
  );
end entity;

architecture rtl of lb_ctrl is

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

  --------------------------------------------------------------------------
  -- CONSTANT RESPONSE WORDS
  -- Edit these two if your hdr0/hdr1 differ.
  --------------------------------------------------------------------------
  constant c_RESP_HDR0_CONST : std_logic_vector(31 downto 0) := x"00000000";
  constant c_RESP_HDR1_CONST : std_logic_vector(31 downto 0) := x"00000100";

  -- hdr2 constants (all fields zero except TYPE/OPC)
  -- TYPE bit = bit0, OPC bit = bit1
  constant c_HDR2_WR : std_logic_vector(31 downto 0) := x"00000001"; -- TYPE=1, OPC=0
  constant c_HDR2_RD : std_logic_vector(31 downto 0) := x"00000002"; -- TYPE=0, OPC=1

  type t_state is (
    S_RX_WAIT_VAL,
    S_RX_ACK_HI,
    S_RX_WAIT_DROP,
    S_TX_WAIT_ACK_LO,
    S_TX_WAIT_ACCEPT,
    S_TX_GAP
  );

  signal st : t_state := S_RX_WAIT_VAL;

  -- RX capture index + checksum tracking
  signal r_cap_idx   : unsigned(5 downto 0) := (others => '0');
  signal r_seen_last : std_logic := '0';

  signal p_cap_en   : std_logic := '0';
  signal p_cap_last : std_logic := '0';
  signal r_lin_ack  : std_logic := '0';

  -- TX sequencing (max: hdr0,hdr1,hdr2,payload,checksum)
  signal r_tx_idx        : unsigned(3 downto 0) := (others => '0');
  signal r_payload_words : unsigned(1 downto 0) := (others => '0'); -- 0 or 1

  -- Alternating pattern: start with WRITE response, then READ response, repeat
  signal r_next_is_read : std_logic := '0';

  -- Registered hold clear (avoid multiple drivers)
  signal r_hold_clr : std_logic := '0';

  -- Combinational TX flit and last index
  signal tx_flit : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal tx_last : unsigned(3 downto 0);

begin

  o_lin_ack  <= r_lin_ack;
  o_hold_clr <= r_hold_clr;

  -- Capture outputs (datapath will only use payload at idx=4)
  o_cap_en   <= p_cap_en;
  o_cap_last <= p_cap_last;
  o_cap_flit <= i_lin_data;
  o_cap_idx  <= r_cap_idx;

  -- Payload index not needed: datapath repeats stored payload
  o_rd_payload_idx <= (others => '0');

  -- Response length: hdr0,hdr1,hdr2,(payload0?),checksum
  tx_last <= to_unsigned(3,4) + resize(r_payload_words, 4);

  -- TX flit generation
  process(all)
    variable idx : unsigned(3 downto 0);
  begin
    idx := r_tx_idx;

    if idx = to_unsigned(0,4) then
      tx_flit <= mk_flit('1', c_RESP_HDR0_CONST);
    elsif idx = to_unsigned(1,4) then
      tx_flit <= mk_flit('0', c_RESP_HDR1_CONST);
    elsif idx = to_unsigned(2,4) then
      if r_next_is_read = '1' then
        tx_flit <= mk_flit('0', c_HDR2_RD);
      else
        tx_flit <= mk_flit('0', c_HDR2_WR);
      end if;
    elsif idx = tx_last then
      tx_flit <= mk_flit('1', (others => '0')); -- checksum
    else
      -- payload only when READ response and payload_words=1
      tx_flit <= mk_flit('0', i_rd_payload);
    end if;
  end process;

  o_lout_val  <= '1' when st = S_TX_WAIT_ACCEPT else '0';
  o_lout_data <= tx_flit;

  process(ACLK)
    variable v_ctrl        : std_logic;
    variable v_is_checksum : std_logic;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st <= S_RX_WAIT_VAL;
        r_cap_idx   <= (others => '0');
        r_seen_last <= '0';
        p_cap_en    <= '0';
        p_cap_last  <= '0';
        r_lin_ack   <= '0';

        r_tx_idx        <= (others => '0');
        r_payload_words <= (others => '0');
        r_next_is_read  <= '0';

        r_hold_clr <= '0';
      else
        -- defaults
        p_cap_en   <= '0';
        p_cap_last <= '0';
        r_lin_ack  <= '0';
        r_hold_clr <= '0';

        case st is

          -- RX: ACK pulse per flit, require lin_val to drop between flits
          when S_RX_WAIT_VAL =>
            if i_lin_val = '1' then
              p_cap_en <= '1';

              v_ctrl := flit_ctrl(i_lin_data);
              v_is_checksum := '0';

              -- hdr0 also has ctrl=1, so ctrl=1 is checksum only after idx>0
              if (v_ctrl = '1') and (r_cap_idx /= to_unsigned(0, r_cap_idx'length)) then
                v_is_checksum := '1';
              end if;

              if v_is_checksum = '1' then
                p_cap_last  <= '1';
                r_seen_last <= '1';
              end if;

              r_lin_ack <= '1';
              st <= S_RX_ACK_HI;
            end if;

          when S_RX_ACK_HI =>
            st <= S_RX_WAIT_DROP;

          when S_RX_WAIT_DROP =>
            if i_lin_val = '0' then
              if r_seen_last = '1' then
                -- request fully captured -> arm TX
                if r_next_is_read = '1' then
                  r_payload_words <= to_unsigned(1, r_payload_words'length); -- exactly one payload word
                else
                  r_payload_words <= to_unsigned(0, r_payload_words'length);
                end if;

                r_tx_idx    <= (others => '0');
                r_cap_idx   <= (others => '0');
                r_seen_last <= '0';
                st <= S_TX_WAIT_ACK_LO;
              else
                r_cap_idx <= r_cap_idx + 1;
                st <= S_RX_WAIT_VAL;
              end if;
            end if;

          -- TX: wait ack low then drive valid until accepted
          when S_TX_WAIT_ACK_LO =>
            if i_lout_ack = '0' then
              st <= S_TX_WAIT_ACCEPT;
            end if;

          when S_TX_WAIT_ACCEPT =>
            if i_lout_ack = '1' then
              -- optional clear after READ response completes
              if (r_next_is_read = '1') and (r_tx_idx = tx_last) then
                r_hold_clr <= '1';
              end if;
              st <= S_TX_GAP;
            end if;

          when S_TX_GAP =>
            if r_tx_idx = tx_last then
              -- toggle for next transaction
              r_next_is_read <= not r_next_is_read;
              st <= S_RX_WAIT_VAL;
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
