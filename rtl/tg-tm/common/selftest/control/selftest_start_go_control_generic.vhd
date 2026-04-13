library IEEE;
use IEEE.std_logic_1164.all;

-- Generic self-test sequencer.
-- Generates one start pulse per transaction and alternates write/read
-- requests while the experiment is enabled.
entity selftest_start_go_control_generic is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    experiment_run_enable_i  : in  std_logic;
    experiment_reset_pulse_i : in  std_logic;
    done_i                   : in  std_logic;

    start_o   : out std_logic;
    is_read_o : out std_logic
  );
end entity;

architecture rtl of selftest_start_go_control_generic is
  constant C_ST_IDLE      : std_logic_vector(2 downto 0) := "000";
  constant C_ST_ISSUE     : std_logic_vector(2 downto 0) := "001";
  constant C_ST_WAIT_DONE : std_logic_vector(2 downto 0) := "010";
  constant C_ST_GAP_0     : std_logic_vector(2 downto 0) := "011";
  constant C_ST_GAP_1     : std_logic_vector(2 downto 0) := "100";

  signal state_r   : std_logic_vector(2 downto 0) := C_ST_IDLE;
  signal start_r   : std_logic := '0';
  signal is_read_r : std_logic := '0';

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of state_r : signal is "TRUE";
  attribute DONT_TOUCH of start_r : signal is "TRUE";
  attribute DONT_TOUCH of is_read_r : signal is "TRUE";
  attribute syn_preserve of state_r : signal is true;
  attribute syn_preserve of start_r : signal is true;
  attribute syn_preserve of is_read_r : signal is true;
begin
  start_o <= start_r;
  is_read_o <= is_read_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      start_r <= '0';
      if ARESETn = '0' or experiment_reset_pulse_i = '1' then
        state_r <= C_ST_IDLE;
        is_read_r <= '0';
      else
        case state_r is
          when C_ST_IDLE =>
            if experiment_run_enable_i = '1' then
              start_r <= '1';
              state_r <= C_ST_ISSUE;
            end if;

          when C_ST_ISSUE =>
            state_r <= C_ST_WAIT_DONE;

          when C_ST_WAIT_DONE =>
            if done_i = '1' then
              is_read_r <= not is_read_r;
              if experiment_run_enable_i = '1' then
                state_r <= C_ST_GAP_0;
              else
                state_r <= C_ST_IDLE;
              end if;
            end if;

          when C_ST_GAP_0 =>
            if experiment_run_enable_i = '0' then
              state_r <= C_ST_IDLE;
            else
              state_r <= C_ST_GAP_1;
            end if;

          when C_ST_GAP_1 =>
            if experiment_run_enable_i = '0' then
              state_r <= C_ST_IDLE;
            else
              start_r <= '1';
              state_r <= C_ST_ISSUE;
            end if;

          when others =>
            state_r <= C_ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
