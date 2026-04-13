library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;

-- Subordinate self-test sequencer.
-- Generates one start pulse per transaction and alternates write/read requests
-- so the isolated subordinate path sees the same request/response rhythm.
entity subordinate_selftest_start_go_control is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    experiment_run_enable_i  : in  std_logic;
    experiment_reset_pulse_i : in  std_logic;
    done_i : in  std_logic;

    start_o   : out std_logic;
    is_read_o : out std_logic;
    id_o      : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of subordinate_selftest_start_go_control is
  constant C_ST_IDLE      : std_logic_vector(1 downto 0) := "00";
  constant C_ST_ISSUE     : std_logic_vector(1 downto 0) := "01";
  constant C_ST_WAIT_DONE : std_logic_vector(1 downto 0) := "10";
  constant C_ST_GAP       : std_logic_vector(1 downto 0) := "11";
  constant C_RESTART_GAP_CYCLES : unsigned(0 downto 0) := "1";

  signal state_r   : std_logic_vector(1 downto 0) := C_ST_IDLE;
  signal start_r   : std_logic := '0';
  signal is_read_r : std_logic := '0';
  signal id_r      : unsigned(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal gap_count_r : unsigned(0 downto 0) := (others => '0');

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of state_r : signal is "TRUE";
  attribute DONT_TOUCH of start_r : signal is "TRUE";
  attribute DONT_TOUCH of is_read_r : signal is "TRUE";
  attribute DONT_TOUCH of id_r : signal is "TRUE";
  attribute DONT_TOUCH of gap_count_r : signal is "TRUE";
  attribute syn_preserve of state_r : signal is true;
  attribute syn_preserve of start_r : signal is true;
  attribute syn_preserve of is_read_r : signal is true;
  attribute syn_preserve of id_r : signal is true;
  attribute syn_preserve of gap_count_r : signal is true;
begin
  start_o <= start_r;
  is_read_o <= is_read_r;
  id_o <= std_logic_vector(id_r);

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      start_r <= '0';
      if ARESETn = '0' or experiment_reset_pulse_i = '1' then
        state_r <= C_ST_IDLE;
        is_read_r <= '0';
        id_r <= (others => '0');
        gap_count_r <= (others => '0');
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
              if is_read_r = '1' then
                id_r <= id_r + 1;
              end if;
              is_read_r <= not is_read_r;
              if experiment_run_enable_i = '1' then
                gap_count_r <= C_RESTART_GAP_CYCLES;
                state_r <= C_ST_GAP;
              else
                state_r <= C_ST_IDLE;
              end if;
            end if;

          when C_ST_GAP =>
            if experiment_run_enable_i = '0' then
              state_r <= C_ST_IDLE;
            elsif gap_count_r = 0 then
              start_r <= '1';
              state_r <= C_ST_ISSUE;
            else
              gap_count_r <= gap_count_r - 1;
            end if;

          when others =>
            state_r <= C_ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
