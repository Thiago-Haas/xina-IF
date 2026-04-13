library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_subordinate_ni_pkg.all;

-- UART report controller for subordinate self-test.
entity subordinate_uart_encode_ctrl is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    tm_done_rise_i : in std_logic;
    period_report_due_i : in std_logic;
    new_event_i : in std_logic;
    uart_tready_i : in std_logic;
    uart_tdone_i  : in std_logic;

    period_report_consume_o : out std_logic;
    latch_event_flags_o : out std_logic;
    load_report_o : out std_logic;
    select_event_flags_o : out std_logic;
    char_index_o : out unsigned(5 downto 0);
    uart_tstart_o : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_encode_ctrl is
  constant C_LINE_LEN : natural := 7 + 8 + 7 + (c_SUB_TM_UART_FLAGS_WIDTH / 4) + 1;
  constant C_ST_IDLE : std_logic_vector(1 downto 0) := "00";
  constant C_ST_SEND : std_logic_vector(1 downto 0) := "01";
  constant C_ST_WAIT_DONE : std_logic_vector(1 downto 0) := "10";

  signal state_r : std_logic_vector(1 downto 0) := C_ST_IDLE;
  signal char_index_r : unsigned(5 downto 0) := (others => '0');
  signal start_r : std_logic := '0';
  signal consume_r : std_logic := '0';
  signal latch_event_flags_r : std_logic := '0';
  signal select_event_flags_r : std_logic := '0';
  signal event_report_pending_r : std_logic := '0';

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute DONT_TOUCH of state_r : signal is "TRUE";
  attribute DONT_TOUCH of char_index_r : signal is "TRUE";
  attribute DONT_TOUCH of start_r : signal is "TRUE";
  attribute DONT_TOUCH of consume_r : signal is "TRUE";
  attribute DONT_TOUCH of latch_event_flags_r : signal is "TRUE";
  attribute DONT_TOUCH of select_event_flags_r : signal is "TRUE";
  attribute DONT_TOUCH of event_report_pending_r : signal is "TRUE";
  attribute syn_preserve of state_r : signal is true;
  attribute syn_preserve of char_index_r : signal is true;
  attribute syn_preserve of start_r : signal is true;
  attribute syn_preserve of consume_r : signal is true;
  attribute syn_preserve of latch_event_flags_r : signal is true;
  attribute syn_preserve of select_event_flags_r : signal is true;
  attribute syn_preserve of event_report_pending_r : signal is true;
begin
  char_index_o <= char_index_r;
  uart_tstart_o <= start_r;
  period_report_consume_o <= consume_r;
  latch_event_flags_o <= latch_event_flags_r;
  load_report_o <= consume_r;
  select_event_flags_o <= select_event_flags_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      start_r <= '0';
      consume_r <= '0';
      latch_event_flags_r <= '0';
      select_event_flags_r <= '0';

      if ARESETn = '0' then
        state_r <= C_ST_IDLE;
        char_index_r <= (others => '0');
        event_report_pending_r <= '0';
      else
        if (tm_done_rise_i = '1') and (new_event_i = '1') then
          event_report_pending_r <= '1';
          latch_event_flags_r <= '1';
        end if;

        case state_r is
          when C_ST_IDLE =>
            if (period_report_due_i = '1') or (event_report_pending_r = '1') then
              if event_report_pending_r = '1' then
                select_event_flags_r <= '1';
                event_report_pending_r <= '0';
              end if;
              consume_r <= '1';
              char_index_r <= (others => '0');
              state_r <= C_ST_SEND;
            end if;

          when C_ST_SEND =>
            if uart_tready_i = '1' then
              start_r <= '1';
              state_r <= C_ST_WAIT_DONE;
            end if;

          when C_ST_WAIT_DONE =>
            if uart_tdone_i = '1' then
              if char_index_r = to_unsigned(C_LINE_LEN - 1, char_index_r'length) then
                state_r <= C_ST_IDLE;
              else
                char_index_r <= char_index_r + 1;
                state_r <= C_ST_SEND;
              end if;
            end if;

          when others =>
            state_r <= C_ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
