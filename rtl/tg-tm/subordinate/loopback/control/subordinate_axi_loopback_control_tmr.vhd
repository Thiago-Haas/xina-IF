library IEEE;
use IEEE.std_logic_1164.all;

entity subordinate_axi_loopback_control_tmr is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    AWVALID : in  std_logic;
    AWREADY : out std_logic;
    WVALID  : in  std_logic;
    WREADY  : out std_logic;
    BVALID  : out std_logic;
    BREADY  : in  std_logic;

    ARVALID : in  std_logic;
    ARREADY : out std_logic;
    RVALID  : out std_logic;
    RREADY  : in  std_logic;

    aw_accept_o : out std_logic;
    w_accept_o  : out std_logic;
    ar_accept_o : out std_logic;

    correct_enable_i : in  std_logic := '1';
    error_o          : out std_logic := '0'
  );
end entity;

architecture rtl of subordinate_axi_loopback_control_tmr is
  attribute DONT_TOUCH    : string;
  attribute syn_preserve  : boolean;
  attribute KEEP_HIERARCHY: string;

  constant C_VOTE_WIDTH : positive := 8;

  type t_bundle_array is array (0 to 2) of std_logic_vector(C_VOTE_WIDTH - 1 downto 0);

  signal awready_w   : std_logic_vector(0 to 2);
  signal wready_w    : std_logic_vector(0 to 2);
  signal bvalid_w    : std_logic_vector(0 to 2);
  signal arready_w   : std_logic_vector(0 to 2);
  signal rvalid_w    : std_logic_vector(0 to 2);
  signal aw_accept_w : std_logic_vector(0 to 2);
  signal w_accept_w  : std_logic_vector(0 to 2);
  signal ar_accept_w : std_logic_vector(0 to 2);

  signal bundle_w  : t_bundle_array;
  signal voted_w   : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
  signal errors_w  : std_logic_vector(C_VOTE_WIDTH - 1 downto 0);
begin
  gen_replica : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_control : label is "TRUE";
    attribute syn_preserve of u_control : label is true;
    attribute KEEP_HIERARCHY of u_control : label is "TRUE";
  begin
    u_control: entity work.subordinate_axi_loopback_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        AWVALID => AWVALID,
        AWREADY => awready_w(i),
        WVALID  => WVALID,
        WREADY  => wready_w(i),
        BVALID  => bvalid_w(i),
        BREADY  => BREADY,

        ARVALID => ARVALID,
        ARREADY => arready_w(i),
        RVALID  => rvalid_w(i),
        RREADY  => RREADY,

        aw_accept_o => aw_accept_w(i),
        w_accept_o  => w_accept_w(i),
        ar_accept_o => ar_accept_w(i)
      );

    bundle_w(i) <= awready_w(i) & wready_w(i) & bvalid_w(i) &
                   arready_w(i) & rvalid_w(i) & aw_accept_w(i) &
                   w_accept_w(i) & ar_accept_w(i);
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

  AWREADY     <= voted_w(7);
  WREADY      <= voted_w(6);
  BVALID      <= voted_w(5);
  ARREADY     <= voted_w(4);
  RVALID      <= voted_w(3);
  aw_accept_o <= voted_w(2);
  w_accept_o  <= voted_w(1);
  ar_accept_o <= voted_w(0);
end architecture;
