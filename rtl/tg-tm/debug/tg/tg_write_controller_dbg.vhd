library IEEE;
use IEEE.std_logic_1164.all;

-- Write-phase controller (AW -> W -> B).
--
-- DEBUG VERSION:
--  * Exposes FSM state encoding and handshake observability so a TB can
--    print state transitions and AXI transaction progress.
--
-- Robustness note:
--  Some NI/loopback configurations may assert BVALID very quickly (even as a
--  single-cycle pulse). If BREADY is only asserted in s_b, that pulse can be
--  missed and the TG will stall. To make the TG robust, we keep BREADY asserted
--  for the whole transaction (AW/W/B) and latch any observed B handshake until
--  W completes.
entity tg_write_controller_dbg is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    i_start : in  std_logic := '1';  -- tie to '1' for continuous writes
    o_done  : out std_logic;         -- 1-cycle pulse when B handshake completes

    -- Handshake inputs (from AXI slave)
    AWREADY : in  std_logic;
    WREADY  : in  std_logic;
    BVALID  : in  std_logic;

    -- AXI control outputs (to AXI slave)
    AWVALID : out std_logic;
    WVALID  : out std_logic;
    BREADY  : out std_logic;

    -- datapath control
    o_txn_start_pulse : out std_logic;
    o_wbeat_pulse     : out std_logic;

    -- ------------------------------------------------------------------
    -- Debug taps (TB-friendly)
    -- ------------------------------------------------------------------
    -- FSM state encoding: 00=IDLE, 01=AW, 10=W, 11=B
    o_dbg_state        : out std_logic_vector(1 downto 0);

    -- current VAL/READY view
    o_dbg_awvalid      : out std_logic;
    o_dbg_wvalid       : out std_logic;
    o_dbg_bready       : out std_logic;
    o_dbg_awready      : out std_logic;
    o_dbg_wready       : out std_logic;
    o_dbg_bvalid       : out std_logic;

    -- handshake qualifiers (level = valid&ready)
    o_dbg_aw_hs        : out std_logic;
    o_dbg_w_hs         : out std_logic;
    o_dbg_b_hs         : out std_logic;

    -- internal latch: did we see B handshake early?
    o_dbg_bhs_seen     : out std_logic
  );
end entity;

architecture rtl of tg_write_controller_dbg is
  type t_state is (s_idle, s_aw, s_w, s_b);
  signal r_state : t_state := s_idle;

  signal r_bhs_seen : std_logic := '0';

  signal awvalid_i, wvalid_i, bready_i : std_logic;
  signal aw_hs, w_hs, b_hs : std_logic;

  signal done_pulse  : std_logic := '0';
  signal start_pulse : std_logic := '0';
  signal wbeat_pulse : std_logic := '0';
begin
  -- AXI valids
  awvalid_i <= '1' when (r_state = s_aw) else '0';
  wvalid_i  <= '1' when (r_state = s_w)  else '0';

  -- Keep BREADY high during the whole active transaction (not only in s_b)
  bready_i  <= '0' when (r_state = s_idle) else '1';

  AWVALID <= awvalid_i;
  WVALID  <= wvalid_i;
  BREADY  <= bready_i;

  aw_hs <= awvalid_i and AWREADY;
  w_hs  <= wvalid_i  and WREADY;
  b_hs  <= bready_i  and BVALID;

  o_done            <= done_pulse;
  o_txn_start_pulse <= start_pulse;
  o_wbeat_pulse     <= wbeat_pulse;

  -- Debug exports
  with r_state select
    o_dbg_state <= "00" when s_idle,
                   "01" when s_aw,
                   "10" when s_w,
                   "11" when s_b;

  o_dbg_awvalid  <= awvalid_i;
  o_dbg_wvalid   <= wvalid_i;
  o_dbg_bready   <= bready_i;
  o_dbg_awready  <= AWREADY;
  o_dbg_wready   <= WREADY;
  o_dbg_bvalid   <= BVALID;

  o_dbg_aw_hs    <= aw_hs;
  o_dbg_w_hs     <= w_hs;
  o_dbg_b_hs     <= b_hs;

  o_dbg_bhs_seen <= r_bhs_seen;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      done_pulse  <= '0';
      start_pulse <= '0';
      wbeat_pulse <= '0';

      if ARESETn = '0' then
        r_state <= s_idle;
        r_bhs_seen <= '0';
      else
        case r_state is
          when s_idle =>
            if i_start = '1' then
              start_pulse <= '1';
              r_state <= s_aw;
              r_bhs_seen <= '0';
            end if;

          when s_aw =>
            -- Defensive: latch any early B handshake (shouldn't happen, but harmless)
            if b_hs = '1' then
              r_bhs_seen <= '1';
            end if;

            if aw_hs = '1' then
              r_state <= s_w;
            end if;

          when s_w =>
            -- If the NI produces a short BVALID pulse while we're still in s_w,
            -- we must not miss it.
            if b_hs = '1' then
              r_bhs_seen <= '1';
            end if;

            if w_hs = '1' then
              wbeat_pulse <= '1';

              -- If we already observed the B handshake (or it happens in the
              -- same cycle as W), we can complete immediately.
              if (r_bhs_seen = '1') or (b_hs = '1') then
                done_pulse <= '1';
                r_state <= s_idle;
                r_bhs_seen <= '0';
              else
                r_state <= s_b;
              end if;
            end if;

          when s_b =>
            if b_hs = '1' then
              done_pulse <= '1';
              r_state <= s_idle;
              r_bhs_seen <= '0';
            end if;
        end case;
      end if;
    end if;
  end process;
end rtl;
