library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for traffic_mon_control.
--
-- Same philosophy as control_tmr.vhd / traffic_gen_control_tmr.vhd:
--   * 3 replicated controllers
--   * majority vote on every output
--   * error_o asserts when any replica disagrees
--   * when correct_enable_i='1', output is the voted value; otherwise replica 0 is passed through

entity traffic_mon_control_tmr is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    start_i : in  std_logic := '1';
    done_o  : out std_logic;

    -- Handshake inputs (from AXI slave)
    ARREADY : in  std_logic;
    RVALID  : in  std_logic;
    RLAST   : in  std_logic;

    -- AXI control outputs (to AXI slave)
    ARVALID : out std_logic;
    RREADY  : out std_logic;

    -- datapath control
    rbeat_hs_comb_o   : out std_logic;
    seed_pulse_o      : out std_logic;

    -- hardening
    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of traffic_mon_control_tmr is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  constant C_VOTE_WIDTH : positive := 5;

  type tmr_sl_t is array (2 downto 0) of std_logic;
  type t_bundle_array is array (2 downto 0) of std_logic_vector(C_VOTE_WIDTH - 1 downto 0);

  signal bundle_w            : t_bundle_array;
  signal voted_w             : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal error_bits_w        : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal done_w            : tmr_sl_t;
  signal arvalid_w         : tmr_sl_t;
  signal rready_w          : tmr_sl_t;
  signal rbeat_hs_comb_w   : tmr_sl_t;
  signal seed_pulse_w      : tmr_sl_t;
begin

  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_traffic_mon_control : label is "TRUE";
    attribute syn_preserve of u_traffic_mon_control : label is true;
    attribute KEEP_HIERARCHY of u_traffic_mon_control : label is "TRUE";
  begin
    u_traffic_mon_control: entity work.traffic_mon_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        start_i => start_i,
        done_o  => done_w(i),

        ARREADY => ARREADY,
        RVALID  => RVALID,
        RLAST   => RLAST,

        ARVALID => arvalid_w(i),
        RREADY  => rready_w(i),

        rbeat_hs_comb_o   => rbeat_hs_comb_w(i),
        seed_pulse_o      => seed_pulse_w(i)
      );

    bundle_w(i) <= done_w(i) & arvalid_w(i) & rready_w(i) &
                   rbeat_hs_comb_w(i) & seed_pulse_w(i);
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
      corrected_o => voted_w,
      error_bits_o => error_bits_w,
      error_o => error_o
    );

  done_o          <= voted_w(4);
  ARVALID         <= voted_w(3);
  RREADY          <= voted_w(2);
  rbeat_hs_comb_o <= voted_w(1);
  seed_pulse_o    <= voted_w(0);
end architecture;
