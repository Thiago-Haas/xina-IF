library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for manager_start_done_control.
-- Same style used by other control TMR blocks in TG/TM/LB:
-- * 3 replicas
-- * majority vote on outputs
-- * disagreement flag (error_o)
-- * optional correction bypass via correct_enable_i
entity manager_start_done_control_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    experiment_run_enable_i  : in  std_logic;
    experiment_reset_pulse_i : in  std_logic;
    tg_done_i : in  std_logic;
    tm_done_i : in  std_logic;

    tg_start_o : out std_logic;
    tm_start_o : out std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of manager_start_done_control_tmr is
  constant C_VOTER_WIDTH : positive := 2;

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal tg_start_w : tmr_sl_t;
  signal tm_start_w : tmr_sl_t;
  signal voter_a_w    : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_b_w    : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_c_w    : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal corrected_w  : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal error_bits_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_manager_start_done_control : label is "TRUE";
    attribute syn_preserve of u_manager_start_done_control : label is true;
    attribute KEEP_HIERARCHY of u_manager_start_done_control : label is "TRUE";
  begin
    u_manager_start_done_control: entity work.manager_start_done_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        experiment_run_enable_i  => experiment_run_enable_i,
        experiment_reset_pulse_i => experiment_reset_pulse_i,
        tg_done_i => tg_done_i,
        tm_done_i => tm_done_i,
        tg_start_o => tg_start_w(i),
        tm_start_o => tm_start_w(i)
      );
  end generate;

  voter_a_w <= tm_start_w(0) & tg_start_w(0);
  voter_b_w <= tm_start_w(1) & tg_start_w(1);
  voter_c_w <= tm_start_w(2) & tg_start_w(2);

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

  tg_start_o <= corrected_w(0);
  tm_start_o <= corrected_w(1);
end architecture;
