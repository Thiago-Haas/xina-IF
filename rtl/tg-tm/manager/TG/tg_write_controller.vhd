library IEEE;
use IEEE.std_logic_1164.all;

-- Write-phase controller (AW -> W -> B).
-- Generates datapath control pulses:
--  * o_seed_pulse:      asserted for 1 cycle ONLY for the first transaction after reset
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
    o_seed_pulse      : out std_logic;
    o_wbeat_pulse     : out std_logic
  );
end entity;

architecture rtl of tg_write_controller is
  constant C_STATE_IDLE : std_logic_vector(1 downto 0) := "00";
  constant C_STATE_AW   : std_logic_vector(1 downto 0) := "01";
  constant C_STATE_W    : std_logic_vector(1 downto 0) := "10";
  constant C_STATE_B    : std_logic_vector(1 downto 0) := "11";
  signal state_r : std_logic_vector(1 downto 0) := C_STATE_IDLE;

  -- Seed gating (only once after reset)
  signal seeded_r : std_logic := '0';

  signal awvalid_i, wvalid_i, bready_i : std_logic;
  signal aw_hs, w_hs, b_hs : std_logic;

  signal done_pulse_r  : std_logic := '0';
  signal seed_pulse_r  : std_logic := '0';
  signal wbeat_pulse_r : std_logic := '0';
begin
  awvalid_i <= '1' when (state_r = C_STATE_AW) else '0';
  wvalid_i  <= '1' when (state_r = C_STATE_W)  else '0';
  -- Keep BREADY high during the whole active transaction (not only in s_b)
  bready_i  <= '0' when (state_r = C_STATE_IDLE) else '1';

  AWVALID <= awvalid_i;
  WVALID  <= wvalid_i;
  BREADY  <= bready_i;

  aw_hs <= awvalid_i and AWREADY;
  w_hs  <= wvalid_i  and WREADY;
  b_hs  <= bready_i  and BVALID;

  o_done            <= done_pulse_r;
  o_seed_pulse      <= seed_pulse_r;
  o_wbeat_pulse     <= wbeat_pulse_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      done_pulse_r  <= '0';
      seed_pulse_r  <= '0';
      wbeat_pulse_r <= '0';

      if ARESETn = '0' then
        state_r <= C_STATE_IDLE;
        seeded_r <= '0';
      else
        case state_r is
          when C_STATE_IDLE =>
            if i_start = '1' then
              -- Seed only on the very first transaction after reset.
              if seeded_r = '0' then
                seed_pulse_r <= '1';
                seeded_r <= '1';
              end if;
              state_r <= C_STATE_AW;
            end if;

          when C_STATE_AW =>
            if aw_hs = '1' then
              state_r <= C_STATE_W;
            end if;

          when C_STATE_W =>
            if w_hs = '1' then
              wbeat_pulse_r <= '1';

              -- AXI-compliant slaves must keep BVALID asserted until BREADY is high
              -- and the handshake occurs. Since we keep BREADY high for the whole
              -- active transaction, we can simply wait for B in s_b.
              state_r <= C_STATE_B;
            end if;

          when C_STATE_B =>
            if b_hs = '1' then
              done_pulse_r <= '1';
              state_r <= C_STATE_IDLE;
            end if;
          when others =>
            state_r <= C_STATE_IDLE;
        end case;
      end if;
    end if;
  end process;
end rtl;
