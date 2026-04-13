library IEEE;
use IEEE.std_logic_1164.all;

-- Generic UART command block for OBS/self-test wrappers.
-- Exposes a correction-enable vector so wrappers can map bits to named ports.
entity uart_obs_command_block_generic is
  generic(
    G_CORRECTION_WIDTH : positive := 1;
    p_USE_UART_COMMAND_CTRL_TMR : boolean := true
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    uart_rdone_i : in  std_logic;
    uart_rdata_i : in  std_logic_vector(7 downto 0);
    uart_rerr_i  : in  std_logic;

    experiment_run_enable_o  : out std_logic;
    experiment_reset_pulse_o : out std_logic;
    correction_vector_o      : out std_logic_vector(G_CORRECTION_WIDTH - 1 downto 0);
    uart_command_ctrl_tmr_error_o : out std_logic
  );
end entity;

architecture rtl of uart_obs_command_block_generic is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
  signal correction_enable_w : std_logic;
begin
  gen_command_plain : if not p_USE_UART_COMMAND_CTRL_TMR generate
    attribute DONT_TOUCH of u_control : label is "TRUE";
    attribute syn_preserve of u_control : label is true;
    attribute KEEP_HIERARCHY of u_control : label is "TRUE";
  begin
    u_control: entity work.uart_obs_command_control_generic
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        uart_rdone_i => uart_rdone_i,
        uart_rdata_i => uart_rdata_i,
        uart_rerr_i => uart_rerr_i,
        run_enable_o => experiment_run_enable_o,
        reset_pulse_o => experiment_reset_pulse_o,
        correction_enable_o => correction_enable_w
      );
    uart_command_ctrl_tmr_error_o <= '0';
  end generate;

  gen_command_tmr : if p_USE_UART_COMMAND_CTRL_TMR generate
  begin
    u_control_tmr: entity work.uart_obs_command_control_generic_tmr
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        uart_rdone_i => uart_rdone_i,
        uart_rdata_i => uart_rdata_i,
        uart_rerr_i => uart_rerr_i,
        run_enable_o => experiment_run_enable_o,
        reset_pulse_o => experiment_reset_pulse_o,
        correction_enable_o => correction_enable_w,
        correct_enable_i => '1',
        error_o => uart_command_ctrl_tmr_error_o
      );
  end generate;

  correction_vector_o <= (others => correction_enable_w);
end architecture;
