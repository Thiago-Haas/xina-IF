library IEEE;
use IEEE.std_logic_1164.all;

-- Read-phase controller (AR -> R).
-- FSM matches the diagram:
--   s0_AR: assert ARVALID until ARREADY
--   s1_R : assert RREADY until RVALID handshake; finish when RLAST=1
--
-- Pulses:
--  * o_done            : 1 cycle when last R beat is accepted (RVALID&RREADY&RLAST)
entity tm_read_controller is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    i_start : in  std_logic := '1';  -- pulse or level; if held '1' it will restart immediately after done
    o_done  : out std_logic;

    -- Handshake inputs (from AXI slave)
    ARREADY : in  std_logic;
    RVALID  : in  std_logic;
    RLAST   : in  std_logic;

    -- AXI control outputs (to AXI slave)
    ARVALID : out std_logic;
    RREADY  : out std_logic;

    -- datapath control
    -- combinational same-cycle handshake (use this to step datapath with no 1-cycle delay)
    o_rbeat_hs_comb   : out std_logic;
    -- seed-only-once logic moved here (mirrors TG)
    o_seed_pulse      : out std_logic
  );
end entity;

architecture rtl of tm_read_controller is
  constant C_STATE_IDLE : std_logic_vector(1 downto 0) := "00";
  constant C_STATE_AR   : std_logic_vector(1 downto 0) := "01";
  constant C_STATE_R    : std_logic_vector(1 downto 0) := "10";
  signal state_r : std_logic_vector(1 downto 0) := C_STATE_IDLE;

  signal arvalid_i, rready_i : std_logic;
  signal ar_hs, r_hs : std_logic;

  signal done_pulse_r  : std_logic := '0';
  signal seed_pulse_r  : std_logic := '0';
  signal seeded_r    : std_logic := '0';
begin
  arvalid_i <= '1' when (state_r = C_STATE_AR) else '0';
  rready_i  <= '1' when (state_r = C_STATE_R)  else '0';

  ARVALID <= arvalid_i;
  RREADY  <= rready_i;

  ar_hs <= arvalid_i and ARREADY;
  r_hs  <= rready_i  and RVALID;

  -- Expose same-cycle read-data handshake (combinational)
  o_rbeat_hs_comb <= r_hs;

  o_done            <= done_pulse_r;
  o_seed_pulse      <= seed_pulse_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      done_pulse_r  <= '0';
      seed_pulse_r  <= '0';

      if ARESETn = '0' then
        state_r <= C_STATE_IDLE;
        seeded_r <= '0';
      else
        case state_r is
          when C_STATE_IDLE =>
            if i_start = '1' then
              if seeded_r = '0' then
                seed_pulse_r <= '1';
                seeded_r   <= '1';
              end if;
              state_r <= C_STATE_AR;
            end if;

          when C_STATE_AR =>
            if ar_hs = '1' then
              state_r <= C_STATE_R;
            end if;

          when C_STATE_R =>
            if r_hs = '1' then
              if RLAST = '1' then
                done_pulse_r <= '1';
                state_r <= C_STATE_IDLE;
              end if;
            end if;
          when others =>
            state_r <= C_STATE_IDLE;
        end case;
      end if;
    end if;
  end process;
end rtl;
