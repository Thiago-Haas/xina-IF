library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity subordinate_noc_traffic_mon_control_tmr is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i   : in  std_logic;
    is_read_i : in  std_logic;
    done_pulse_o : out std_logic;
    done_o    : out std_logic;

    l_in_val_i : in  std_logic;
    l_in_ack_o : out std_logic;

    load_expected_o : out std_logic;
    step_lfsr_o     : out std_logic;
    lfsr_seeded_o   : out std_logic;
    accept_flit_o   : out std_logic;
    flit_idx_o      : out unsigned(2 downto 0);
    is_read_o       : out std_logic;

    correct_enable_i : in  std_logic := '1';
    error_o          : out std_logic := '0'
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_control_tmr is
  attribute DONT_TOUCH    : string;
  attribute syn_preserve  : boolean;
  attribute KEEP_HIERARCHY: string;

  constant C_VOTE_WIDTH : positive := 11;

  type t_bundle_array is array (0 to 2) of std_logic_vector(C_VOTE_WIDTH - 1 downto 0);

  signal done_pulse_w    : std_logic_vector(0 to 2);
  signal done_w          : std_logic_vector(0 to 2);
  signal l_in_ack_w      : std_logic_vector(0 to 2);
  signal load_expected_w : std_logic_vector(0 to 2);
  signal step_lfsr_w     : std_logic_vector(0 to 2);
  signal lfsr_seeded_w   : std_logic_vector(0 to 2);
  signal accept_flit_w   : std_logic_vector(0 to 2);
  type t_u3_array is array (0 to 2) of unsigned(2 downto 0);

  signal flit_idx_w      : t_u3_array;
  signal is_read_w       : std_logic_vector(0 to 2);

  signal bundle_w  : t_bundle_array;
  signal voted_w   : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal errors_w  : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
begin
  gen_replica : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_control : label is "TRUE";
    attribute syn_preserve of u_control : label is true;
    attribute KEEP_HIERARCHY of u_control : label is "TRUE";
  begin
    u_control: entity work.subordinate_noc_traffic_mon_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        start_i   => start_i,
        is_read_i => is_read_i,
        done_pulse_o => done_pulse_w(i),
        done_o    => done_w(i),

        l_in_val_i => l_in_val_i,
        l_in_ack_o => l_in_ack_w(i),

        load_expected_o => load_expected_w(i),
        step_lfsr_o     => step_lfsr_w(i),
        lfsr_seeded_o   => lfsr_seeded_w(i),
        accept_flit_o   => accept_flit_w(i),
        flit_idx_o      => flit_idx_w(i),
        is_read_o       => is_read_w(i)
      );

    bundle_w(i) <= done_pulse_w(i) & done_w(i) & l_in_ack_w(i) & load_expected_w(i) &
                   step_lfsr_w(i) & lfsr_seeded_w(i) &
                   accept_flit_w(i) & std_logic_vector(flit_idx_w(i)) &
                   is_read_w(i);
  end generate;

  u_voter: entity work.tmr_voter_block
    generic map(
      p_WIDTH => C_VOTE_WIDTH
    )
    port map(
      A_i => bundle_w(0),
      B_i => bundle_w(1),
      C_i => bundle_w(2),
      correct_enable_i => correct_enable_i,
      corrected_o  => voted_w,
      error_bits_o => errors_w,
      error_o      => error_o
    );

  done_pulse_o    <= voted_w(10);
  done_o          <= voted_w(9);
  l_in_ack_o      <= voted_w(8);
  load_expected_o <= voted_w(7);
  step_lfsr_o     <= voted_w(6);
  lfsr_seeded_o   <= voted_w(5);
  accept_flit_o   <= voted_w(4);
  flit_idx_o      <= unsigned(voted_w(3 downto 1));
  is_read_o       <= voted_w(0);
end architecture;
