library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

entity loopback_control_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    lin_ctrl_i : in  std_logic;
    lin_val_i  : in  std_logic;
    lin_ack_o  : out std_logic;

    lout_val_o  : out std_logic;
    lout_ack_i  : in  std_logic;
    tx_next_is_read_o : out std_logic;
    tx_flit_sel_o     : out std_logic_vector(2 downto 0);

    cap_en_o   : out std_logic;
    cap_flit_ctrl_o : out std_logic;
    cap_idx_o  : out unsigned(5 downto 0);

    hold_valid_i : in  std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of loopback_control_tmr is
  attribute DONT_TOUCH : string;
  attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  constant C_VOTE_WIDTH : positive := 14;

  type tmr_sl  is array (0 to 2) of std_logic;
  type tmr_sel is array (0 to 2) of std_logic_vector(2 downto 0);
  type tmr_u6  is array (0 to 2) of unsigned(5 downto 0);
  type t_bundle_array is array (0 to 2) of std_logic_vector(C_VOTE_WIDTH - 1 downto 0);

  signal bundle_w : t_bundle_array;
  signal voted_w  : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal error_bits_w : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal lin_ack_w  : tmr_sl;
  signal lout_val_w : tmr_sl;
  signal tx_next_is_read_w : tmr_sl;
  signal tx_flit_sel_w : tmr_sel;
  signal cap_en_w   : tmr_sl;
  signal cap_idx_w  : tmr_u6;
  signal cap_flit_ctrl_w : tmr_sl;
begin

  gen_rep : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_loopback_control : label is "TRUE";
    attribute syn_preserve of u_loopback_control : label is true;
    attribute KEEP_HIERARCHY of u_loopback_control : label is "TRUE";
  begin
    u_loopback_control: entity work.loopback_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        lin_ctrl_i => lin_ctrl_i,
        lin_val_i  => lin_val_i,
        lin_ack_o  => lin_ack_w(i),

        lout_val_o  => lout_val_w(i),
        lout_ack_i  => lout_ack_i,
        tx_next_is_read_o => tx_next_is_read_w(i),
        tx_flit_sel_o     => tx_flit_sel_w(i),

        cap_en_o   => cap_en_w(i),
        cap_flit_ctrl_o => cap_flit_ctrl_w(i),
        cap_idx_o  => cap_idx_w(i),

        hold_valid_i => hold_valid_i
      );

    bundle_w(i) <= lin_ack_w(i) & lout_val_w(i) & tx_next_is_read_w(i) &
                   tx_flit_sel_w(i) & cap_en_w(i) & cap_flit_ctrl_w(i) &
                   std_logic_vector(cap_idx_w(i));
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

  lin_ack_o          <= voted_w(13);
  lout_val_o         <= voted_w(12);
  tx_next_is_read_o  <= voted_w(11);
  tx_flit_sel_o      <= voted_w(10 downto 8);
  cap_en_o           <= voted_w(7);
  cap_flit_ctrl_o    <= voted_w(6);
  cap_idx_o          <= unsigned(voted_w(5 downto 0));
end architecture;
