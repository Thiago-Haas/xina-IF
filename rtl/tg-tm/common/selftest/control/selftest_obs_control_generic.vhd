library IEEE;
use IEEE.std_logic_1164.all;

-- Generic self-test OBS control shell.
-- Keeps UART command decode and start/go sequencing as separate blocks while
-- presenting a single integration point to the self-test top.
entity selftest_obs_control_generic is
  generic(
    G_CORRECTION_WIDTH          : positive := 1;
    G_USE_UART_COMMAND_CTRL_TMR : boolean := true;
    G_USE_START_GO_CTRL_TMR     : boolean := true
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    uart_rdone_i : in  std_logic;
    uart_rdata_i : in  std_logic_vector(7 downto 0);
    uart_rerr_i  : in  std_logic;
    done_i       : in  std_logic;

    start_go_correct_enable_i : in  std_logic;

    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;
    correction_vector_o      : out std_logic_vector(G_CORRECTION_WIDTH - 1 downto 0);
    start_o                  : out std_logic;
    is_read_o                : out std_logic;

    uart_command_ctrl_tmr_error_o : out std_logic;
    start_go_ctrl_tmr_error_o     : out std_logic
  );
end entity;

architecture rtl of selftest_obs_control_generic is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
begin
  u_command: entity work.uart_obs_command_block_generic
    generic map(
      G_CORRECTION_WIDTH => G_CORRECTION_WIDTH,
      p_USE_UART_COMMAND_CTRL_TMR => G_USE_UART_COMMAND_CTRL_TMR
    )
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      uart_rdone_i => uart_rdone_i,
      uart_rdata_i => uart_rdata_i,
      uart_rerr_i => uart_rerr_i,
      experiment_run_enable_o => experiment_run_enable_o,
      experiment_reset_pulse_o => experiment_reset_pulse_o,
      correction_vector_o => correction_vector_o,
      uart_command_ctrl_tmr_error_o => uart_command_ctrl_tmr_error_o
    );

  gen_start_go_plain : if not G_USE_START_GO_CTRL_TMR generate
    attribute DONT_TOUCH of u_start_go : label is "TRUE";
    attribute syn_preserve of u_start_go : label is true;
    attribute KEEP_HIERARCHY of u_start_go : label is "TRUE";
  begin
    u_start_go: entity work.selftest_start_go_control_generic
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        experiment_run_enable_i  => experiment_run_enable_o,
        experiment_reset_pulse_i => experiment_reset_pulse_o,
        done_i                   => done_i,
        start_o                  => start_o,
        is_read_o                => is_read_o
      );
    start_go_ctrl_tmr_error_o <= '0';
  end generate;

  gen_start_go_tmr : if G_USE_START_GO_CTRL_TMR generate
  begin
    u_start_go_tmr: entity work.selftest_start_go_control_generic_tmr
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        experiment_run_enable_i  => experiment_run_enable_o,
        experiment_reset_pulse_i => experiment_reset_pulse_o,
        done_i                   => done_i,
        start_o                  => start_o,
        is_read_o                => is_read_o,
        correct_enable_i         => start_go_correct_enable_i,
        error_o                  => start_go_ctrl_tmr_error_o
      );
  end generate;
end architecture;
