library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_noc_pkg.all;

-- TMR wrapper for subordinate_selftest_start_go_control.
entity subordinate_selftest_start_go_control_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    experiment_run_enable_i  : in  std_logic;
    experiment_reset_pulse_i : in  std_logic;
    done_i : in  std_logic;

    start_o   : out std_logic;
    is_read_o : out std_logic;
    id_o      : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of subordinate_selftest_start_go_control_tmr is
  constant C_VOTER_WIDTH : positive := c_AXI_ID_WIDTH + 2;

  type tmr_sl_t is array (2 downto 0) of std_logic;
  type tmr_id_t is array (2 downto 0) of std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);

  signal start_w : tmr_sl_t;
  signal is_read_w : tmr_sl_t;
  signal id_w : tmr_id_t;
  signal voter_a_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_b_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal voter_c_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal corrected_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);
  signal error_bits_w : std_logic_vector(C_VOTER_WIDTH - 1 downto 0);

  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;
begin
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_control : label is "TRUE";
    attribute syn_preserve of u_control : label is true;
    attribute KEEP_HIERARCHY of u_control : label is "TRUE";
  begin
    u_control: entity work.subordinate_selftest_start_go_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        experiment_run_enable_i  => experiment_run_enable_i,
        experiment_reset_pulse_i => experiment_reset_pulse_i,
        done_i => done_i,
        start_o => start_w(i),
        is_read_o => is_read_w(i),
        id_o => id_w(i)
      );
  end generate;

  voter_a_w <= id_w(0) & is_read_w(0) & start_w(0);
  voter_b_w <= id_w(1) & is_read_w(1) & start_w(1);
  voter_c_w <= id_w(2) & is_read_w(2) & start_w(2);

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

  start_o <= corrected_w(0);
  is_read_o <= corrected_w(1);
  id_o <= corrected_w(C_VOTER_WIDTH - 1 downto 2);
end architecture;
