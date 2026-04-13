library IEEE;
use IEEE.std_logic_1164.all;

-- UART command control for subordinate self-test.
-- S/P control run, R emits a one-cycle reset pulse, E/D enable/disable
-- correction enables exported toward the protected subordinate blocks.
entity subordinate_uart_command_control is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    uart_rdone_i : in  std_logic;
    uart_rdata_i : in  std_logic_vector(7 downto 0);
    uart_rerr_i  : in  std_logic;

    run_enable_o     : out std_logic;
    reset_pulse_o    : out std_logic;
    correction_enable_o : out std_logic
  );
end entity;

architecture rtl of subordinate_uart_command_control is
  signal run_enable_r : std_logic := '1';
  signal reset_pulse_r : std_logic := '0';
  signal correction_enable_r : std_logic := '1';
begin
  run_enable_o <= run_enable_r;
  reset_pulse_o <= reset_pulse_r;
  correction_enable_o <= correction_enable_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        run_enable_r <= '1';
        reset_pulse_r <= '0';
        correction_enable_r <= '1';
      else
        reset_pulse_r <= '0';
        if uart_rdone_i = '1' and uart_rerr_i = '0' then
          case uart_rdata_i is
            when x"53" => run_enable_r <= '1'; -- S
            when x"50" => run_enable_r <= '0'; -- P
            when x"52" => reset_pulse_r <= '1'; -- R
            when x"45" => correction_enable_r <= '1'; -- E
            when x"44" => correction_enable_r <= '0'; -- D
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
