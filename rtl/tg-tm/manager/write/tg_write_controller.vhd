library IEEE;
use IEEE.std_logic_1164.all;

-- Write-phase controller (AW -> W -> B).
-- Generates datapath control pulses:
--  * o_txn_start_pulse: asserted for 1 cycle when a new transaction starts (IDLE->AW)
--  * o_wbeat_pulse:     asserted for 1 cycle when W handshake completes (WVALID&WREADY)
entity tg_write_controller is
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
    o_wbeat_pulse     : out std_logic
  );
end entity;

architecture rtl of tg_write_controller is
  type t_state is (s_idle, s_aw, s_w, s_b);
  signal r_state : t_state := s_idle;

  signal awvalid_i, wvalid_i, bready_i : std_logic;
  signal aw_hs, w_hs, b_hs : std_logic;

  signal done_pulse  : std_logic := '0';
  signal start_pulse : std_logic := '0';
  signal wbeat_pulse : std_logic := '0';
begin
  awvalid_i <= '1' when (r_state = s_aw) else '0';
  wvalid_i  <= '1' when (r_state = s_w)  else '0';
  bready_i  <= '1' when (r_state = s_b)  else '0';

  AWVALID <= awvalid_i;
  WVALID  <= wvalid_i;
  BREADY  <= bready_i;

  aw_hs <= awvalid_i and AWREADY;
  w_hs  <= wvalid_i  and WREADY;
  b_hs  <= bready_i  and BVALID;

  o_done            <= done_pulse;
  o_txn_start_pulse <= start_pulse;
  o_wbeat_pulse     <= wbeat_pulse;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      done_pulse  <= '0';
      start_pulse <= '0';
      wbeat_pulse <= '0';

      if ARESETn = '0' then
        r_state <= s_idle;
      else
        case r_state is
          when s_idle =>
            if i_start = '1' then
              start_pulse <= '1';
              r_state <= s_aw;
            end if;

          when s_aw =>
            if aw_hs = '1' then
              r_state <= s_w;
            end if;

          when s_w =>
            if w_hs = '1' then
              wbeat_pulse <= '1';
              r_state <= s_b;
            end if;

          when s_b =>
            if b_hs = '1' then
              done_pulse <= '1';
              r_state <= s_idle;
            end if;
        end case;
      end if;
    end if;
  end process;
end rtl;
