library IEEE;
use IEEE.std_logic_1164.all;

-- Control slice for closed-box self-test observation block.
-- Generates TG/TM one-cycle start pulses and a sample pulse for mismatch capture.
entity tg_tm_lb_selftest_obs_control is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_tg_done : in  std_logic;
    i_tm_done : in  std_logic;

    o_tg_start : out std_logic;
    o_tm_start : out std_logic;

    o_sample_mismatch : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_control is
  type t_state is (S_TG_PULSE, S_WAIT_TG, S_TM_PULSE, S_WAIT_TM);
  signal r_state : t_state := S_TG_PULSE;

  signal r_tg_start        : std_logic := '0';
  signal r_tm_start        : std_logic := '0';
  signal r_sample_mismatch : std_logic := '0';
begin
  o_tg_start        <= r_tg_start;
  o_tm_start        <= r_tm_start;
  o_sample_mismatch <= r_sample_mismatch;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_state           <= S_TG_PULSE;
        r_tg_start        <= '0';
        r_tm_start        <= '0';
        r_sample_mismatch <= '0';
      else
        r_tg_start        <= '0';
        r_tm_start        <= '0';
        r_sample_mismatch <= '0';

        case r_state is
          when S_TG_PULSE =>
            r_tg_start <= '1';
            r_state    <= S_WAIT_TG;

          when S_WAIT_TG =>
            if i_tg_done = '1' then
              r_state <= S_TM_PULSE;
            end if;

          when S_TM_PULSE =>
            r_tm_start <= '1';
            r_state    <= S_WAIT_TM;

          when S_WAIT_TM =>
            if i_tm_done = '1' then
              r_sample_mismatch <= '1';
              r_state <= S_TG_PULSE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;

