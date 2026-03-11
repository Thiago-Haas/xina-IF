library IEEE;
use IEEE.std_logic_1164.all;

-- Control slice for closed-box self-test observation block.
-- Generates TG/TM one-cycle start pulses.
entity tg_tm_lb_selftest_obs_control is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;
    i_experiment_run_enable  : in  std_logic;
    i_experiment_reset_pulse : in  std_logic;

    i_tg_done : in  std_logic;
    i_tm_done : in  std_logic;

    o_tg_start : out std_logic;
    o_tm_start : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_obs_control is
  constant C_STATE_TG_PULSE : std_logic_vector(1 downto 0) := "00";
  constant C_STATE_WAIT_TG  : std_logic_vector(1 downto 0) := "01";
  constant C_STATE_TM_PULSE : std_logic_vector(1 downto 0) := "10";
  constant C_STATE_WAIT_TM  : std_logic_vector(1 downto 0) := "11";
  signal state_r : std_logic_vector(1 downto 0) := C_STATE_TG_PULSE;

  signal tg_start_r : std_logic := '0';
  signal tm_start_r : std_logic := '0';
begin
  o_tg_start <= tg_start_r;
  o_tm_start <= tm_start_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        state_r    <= C_STATE_TG_PULSE;
        tg_start_r <= '0';
        tm_start_r <= '0';
      else
        tg_start_r <= '0';
        tm_start_r <= '0';

        if i_experiment_reset_pulse = '1' then
          state_r <= C_STATE_TG_PULSE;
        elsif i_experiment_run_enable = '0' then
          state_r <= C_STATE_TG_PULSE;
        else
          case state_r is
            when C_STATE_TG_PULSE =>
              tg_start_r <= '1';
              state_r    <= C_STATE_WAIT_TG;

            when C_STATE_WAIT_TG =>
              if i_tg_done = '1' then
                state_r <= C_STATE_TM_PULSE;
              end if;

            when C_STATE_TM_PULSE =>
              tm_start_r <= '1';
              state_r    <= C_STATE_WAIT_TM;

            when C_STATE_WAIT_TM =>
              if i_tm_done = '1' then
                state_r <= C_STATE_TG_PULSE;
              end if;
            when others =>
              state_r <= C_STATE_TG_PULSE;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
