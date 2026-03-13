library IEEE;
use IEEE.std_logic_1164.all;

-- Control slice for closed-box self-test observation block.
-- Generates TG/TM one-cycle start pulses.
entity selftest_obs_start_done_control is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;
    experiment_run_enable_i  : in  std_logic;
    experiment_reset_pulse_i : in  std_logic;

    tg_done_i : in  std_logic;
    tm_done_i : in  std_logic;

    tg_start_o : out std_logic;
    tm_start_o : out std_logic
  );
end entity;

architecture rtl of selftest_obs_start_done_control is
  constant C_STATE_TG_PULSE : std_logic_vector(1 downto 0) := "00";
  constant C_STATE_WAIT_TG  : std_logic_vector(1 downto 0) := "01";
  constant C_STATE_TM_PULSE : std_logic_vector(1 downto 0) := "10";
  constant C_STATE_WAIT_TM  : std_logic_vector(1 downto 0) := "11";
  signal state_r : std_logic_vector(1 downto 0) := C_STATE_TG_PULSE;

  signal tg_start_r : std_logic := '0';
  signal tm_start_r : std_logic := '0';

  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of state_r : signal is "TRUE";
  attribute DONT_TOUCH of tg_start_r : signal is "TRUE";
  attribute DONT_TOUCH of tm_start_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of state_r : signal is true;
  attribute syn_preserve of tg_start_r : signal is true;
  attribute syn_preserve of tm_start_r : signal is true;
begin
  tg_start_o <= tg_start_r;
  tm_start_o <= tm_start_r;

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

        if experiment_reset_pulse_i = '1' then
          state_r <= C_STATE_TG_PULSE;
        elsif experiment_run_enable_i = '0' then
          state_r <= C_STATE_TG_PULSE;
        else
          case state_r is
            when C_STATE_TG_PULSE =>
              tg_start_r <= '1';
              state_r    <= C_STATE_WAIT_TG;

            when C_STATE_WAIT_TG =>
              if tg_done_i = '1' then
                state_r <= C_STATE_TM_PULSE;
              end if;

            when C_STATE_TM_PULSE =>
              tm_start_r <= '1';
              state_r    <= C_STATE_WAIT_TM;

            when C_STATE_WAIT_TM =>
              if tm_done_i = '1' then
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
