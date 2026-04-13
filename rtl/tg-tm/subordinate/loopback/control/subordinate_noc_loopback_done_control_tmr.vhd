library IEEE;
use IEEE.std_logic_1164.all;

entity subordinate_noc_loopback_done_control_tmr is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i    : in  std_logic;
    gen_done_i : in  std_logic;
    mon_done_i : in  std_logic;

    done_o : out std_logic;

    correct_enable_i : in  std_logic := '1';
    error_o          : out std_logic := '0'
  );
end entity;

architecture rtl of subordinate_noc_loopback_done_control_tmr is
  attribute DONT_TOUCH     : string;
  attribute syn_preserve   : boolean;
  attribute KEEP_HIERARCHY : string;

  constant C_VOTE_WIDTH : positive := 1;

  type t_bundle_array is array (0 to 2) of std_logic_vector(C_VOTE_WIDTH - 1 downto 0);

  signal done_w   : std_logic_vector(0 to 2);
  signal bundle_w : t_bundle_array;
  signal voted_w  : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal errors_w : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
begin
  gen_replica : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_control : label is "TRUE";
    attribute syn_preserve of u_control : label is true;
    attribute KEEP_HIERARCHY of u_control : label is "TRUE";
  begin
    u_control: entity work.subordinate_noc_loopback_done_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,
        start_i    => start_i,
        gen_done_i => gen_done_i,
        mon_done_i => mon_done_i,
        done_o     => done_w(i)
      );

    bundle_w(i)(0) <= done_w(i);
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
      corrected_o      => voted_w,
      error_bits_o     => errors_w,
      error_o          => error_o
    );

  done_o <= voted_w(0);
end architecture;
