library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for selftest_uart_command_control.
entity selftest_uart_command_control_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    uart_rdone_i : in  std_logic;
    uart_rdata_i : in  std_logic_vector(7 downto 0);
    uart_rerr_i  : in  std_logic;

    run_enable_o     : out std_logic;
    reset_pulse_o    : out std_logic;
    command_enable_o : out std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of selftest_uart_command_control_tmr is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal run_enable_w     : tmr_sl_t;
  signal reset_pulse_w    : tmr_sl_t;
  signal command_enable_w : tmr_sl_t;

  signal corr_run_enable_w     : std_logic;
  signal corr_reset_pulse_w    : std_logic;
  signal corr_command_enable_w : std_logic;

  signal err_run_enable_w     : std_logic;
  signal err_reset_pulse_w    : std_logic;
  signal err_command_enable_w : std_logic;

  function maj3(a, b, c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  function dis3(a, b, c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_uart_command_ctrl : label is "TRUE";
    attribute syn_preserve of u_uart_command_ctrl : label is true;
    attribute KEEP_HIERARCHY of u_uart_command_ctrl : label is "TRUE";
  begin
    u_uart_command_ctrl : entity work.selftest_uart_command_control
      port map(
        ACLK             => ACLK,
        ARESETn          => ARESETn,
        uart_rdone_i     => uart_rdone_i,
        uart_rdata_i     => uart_rdata_i,
        uart_rerr_i      => uart_rerr_i,
        run_enable_o     => run_enable_w(i),
        reset_pulse_o    => reset_pulse_w(i),
        command_enable_o => command_enable_w(i)
      );
  end generate;

  corr_run_enable_w     <= maj3(run_enable_w(2), run_enable_w(1), run_enable_w(0));
  corr_reset_pulse_w    <= maj3(reset_pulse_w(2), reset_pulse_w(1), reset_pulse_w(0));
  corr_command_enable_w <= maj3(command_enable_w(2), command_enable_w(1), command_enable_w(0));

  err_run_enable_w     <= dis3(run_enable_w(2), run_enable_w(1), run_enable_w(0));
  err_reset_pulse_w    <= dis3(reset_pulse_w(2), reset_pulse_w(1), reset_pulse_w(0));
  err_command_enable_w <= dis3(command_enable_w(2), command_enable_w(1), command_enable_w(0));

  error_o <= err_run_enable_w or err_reset_pulse_w or err_command_enable_w;

  run_enable_o     <= corr_run_enable_w when correct_enable_i = '1' else run_enable_w(0);
  reset_pulse_o    <= corr_reset_pulse_w when correct_enable_i = '1' else reset_pulse_w(0);
  command_enable_o <= corr_command_enable_w when correct_enable_i = '1' else command_enable_w(0);
end architecture;
