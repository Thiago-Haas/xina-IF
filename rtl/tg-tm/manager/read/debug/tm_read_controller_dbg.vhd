library IEEE;
use IEEE.std_logic_1164.all;

-- Read-phase controller (AR -> R) with debug exports.
--
-- FSM:
--   s_idle : wait i_start
--   s_ar   : assert ARVALID until ARREADY
--   s_r    : assert RREADY until RVALID handshake; done when RLAST=1
--
-- Pulses:
--  * o_txn_start_pulse : 1 cycle when a new transaction starts (IDLE->AR)
--  * o_rbeat_pulse     : 1 cycle for each R beat accepted (RVALID&RREADY)
--  * o_done            : 1 cycle when last R beat is accepted (RVALID&RREADY&RLAST)
entity tm_read_controller_dbg is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    i_start : in  std_logic := '1';
    o_done  : out std_logic;

    -- Handshake inputs (from AXI slave)
    ARREADY : in  std_logic;
    RVALID  : in  std_logic;
    RLAST   : in  std_logic;

    -- AXI control outputs (to AXI slave)
    ARVALID : out std_logic;
    RREADY  : out std_logic;

    -- datapath control
    o_txn_start_pulse : out std_logic;
    o_rbeat_pulse     : out std_logic;

    -- ------------------------------------------------------------
    -- Debug exports
    -- ------------------------------------------------------------
    o_dbg_state     : out std_logic_vector(1 downto 0); -- 00=IDLE,01=AR,10=R
    o_dbg_ar_hs     : out std_logic;
    o_dbg_r_hs      : out std_logic;
    o_dbg_last_hs   : out std_logic;
    o_dbg_arvalid   : out std_logic;
    o_dbg_rready    : out std_logic
  );
end entity;

architecture rtl of tm_read_controller_dbg is
  type t_state is (s_idle, s_ar, s_r);
  signal r_state : t_state := s_idle;

  signal arvalid_i, rready_i : std_logic;
  signal ar_hs, r_hs, last_hs : std_logic;

  signal done_pulse  : std_logic := '0';
  signal start_pulse : std_logic := '0';
  signal rbeat_pulse : std_logic := '0';

  function enc_state(s : t_state) return std_logic_vector is
  begin
    case s is
      when s_idle => return "00";
      when s_ar   => return "01";
      when s_r    => return "10";
    end case;
  end function;
begin
  arvalid_i <= '1' when (r_state = s_ar) else '0';
  rready_i  <= '1' when (r_state = s_r)  else '0';

  ARVALID <= arvalid_i;
  RREADY  <= rready_i;

  ar_hs <= arvalid_i and ARREADY;
  r_hs  <= rready_i  and RVALID;
  last_hs <= r_hs and RLAST;

  o_done            <= done_pulse;
  o_txn_start_pulse <= start_pulse;
  o_rbeat_pulse     <= rbeat_pulse;

  -- debug
  o_dbg_state   <= enc_state(r_state);
  o_dbg_ar_hs   <= ar_hs;
  o_dbg_r_hs    <= r_hs;
  o_dbg_last_hs <= last_hs;
  o_dbg_arvalid <= arvalid_i;
  o_dbg_rready  <= rready_i;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      done_pulse  <= '0';
      start_pulse <= '0';
      rbeat_pulse <= '0';

      if ARESETn = '0' then
        r_state <= s_idle;
      else
        case r_state is
          when s_idle =>
            if i_start = '1' then
              start_pulse <= '1';
              r_state <= s_ar;
            end if;

          when s_ar =>
            if ar_hs = '1' then
              r_state <= s_r;
            end if;

          when s_r =>
            if r_hs = '1' then
              rbeat_pulse <= '1';
              if RLAST = '1' then
                done_pulse <= '1';
                r_state <= s_idle;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
end rtl;
