library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for manager_uart_command_control.
entity manager_uart_command_control_tmr is
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

architecture rtl of manager_uart_command_control_tmr is
  constant C_VOTER_WIDTH : positive := 3;

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal run_enable_w     : tmr_sl_t;
  signal reset_pulse_w    : tmr_sl_t;
  signal command_enable_w : tmr_sl_t;
  signal voter_a_w        : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_b_w        : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_c_w        : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal corrected_w      : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal error_bits_w     : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_manager_uart_command_control : label is "TRUE";
    attribute syn_preserve of u_manager_uart_command_control : label is true;
    attribute KEEP_HIERARCHY of u_manager_uart_command_control : label is "TRUE";
  begin
    u_manager_uart_command_control: entity work.manager_uart_command_control
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

  voter_a_w <= command_enable_w(0) & reset_pulse_w(0) & run_enable_w(0);
  voter_b_w <= command_enable_w(1) & reset_pulse_w(1) & run_enable_w(1);
  voter_c_w <= command_enable_w(2) & reset_pulse_w(2) & run_enable_w(2);

  u_voter: entity work.tmr_voter_block
    generic map(
      p_WIDTH => C_VOTER_WIDTH
    )
    port map(
      A_i => voter_a_w,
      B_i => voter_b_w,
      C_i => voter_c_w,
      correct_enable_i => correct_enable_i,
      corrected_o => corrected_w,
      error_bits_o => error_bits_w,
      error_o => error_o
    );

  run_enable_o     <= corrected_w(0);
  reset_pulse_o    <= corrected_w(1);
  command_enable_o <= corrected_w(2);
end architecture;
