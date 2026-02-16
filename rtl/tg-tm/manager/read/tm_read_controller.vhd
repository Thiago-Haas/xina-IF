library IEEE;
use IEEE.std_logic_1164.all;

-- Read-phase controller (AR -> R).
-- Adds i_start / o_done handshake so an external block can sequence write then read.
entity tm_read_controller is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    i_start : in  std_logic := '1';  -- tie to '1' for continuous reads
    o_done  : out std_logic;         -- 1-cycle pulse when RLAST handshake completes

    -- Handshake inputs (from AXI slave)
    ARREADY : in  std_logic;
    RVALID  : in  std_logic;
    RLAST   : in  std_logic;

    -- AXI control outputs (to AXI slave)
    ARVALID : out std_logic;
    RREADY  : out std_logic;

    -- pulse to update local LFSR
    o_update_lfsr : out std_logic
  );
end entity;

architecture rtl of tm_read_controller is
  type t_state is (s_idle, s_ar, s_r);
  signal r_state : t_state := s_idle;

  signal arvalid_i, rready_i : std_logic;
  signal ar_hs, r_hs, r_done : std_logic;

  signal done_pulse : std_logic := '0';
begin
  arvalid_i <= '1' when (r_state = s_ar) else '0';
  rready_i  <= '1' when (r_state = s_r)  else '0';

  ARVALID <= arvalid_i;
  RREADY  <= rready_i;

  ar_hs  <= arvalid_i and ARREADY;
  r_hs   <= rready_i and RVALID;
  r_done <= r_hs and RLAST;

  o_done        <= done_pulse;
  o_update_lfsr <= r_done;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      done_pulse <= '0';
      if ARESETn = '0' then
        r_state <= s_idle;
      else
        case r_state is
          when s_idle =>
            if i_start = '1' then
              r_state <= s_ar;
            end if;

          when s_ar =>
            if ar_hs = '1' then
              r_state <= s_r;
            end if;

          when s_r =>
            if r_done = '1' then
              done_pulse <= '1';
              r_state <= s_idle;
            end if;
        end case;
      end if;
    end if;
  end process;
end rtl;
