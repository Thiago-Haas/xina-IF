library IEEE;
use IEEE.std_logic_1164.all;

-- AXI-lite-ish one-beat handshake controller for the subordinate AXI loopback.
entity subordinate_axi_loopback_control is
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
    ar_accept_o : out std_logic
  );
end entity;

architecture rtl of subordinate_axi_loopback_control is
  signal have_aw_r : std_logic := '0';
  signal bvalid_r  : std_logic := '0';
  signal rvalid_r  : std_logic := '0';

  signal awready_w : std_logic;
  signal wready_w  : std_logic;
  signal arready_w : std_logic;
  signal aw_accept_w : std_logic;
  signal w_accept_w  : std_logic;
  signal ar_accept_w : std_logic;
begin
  awready_w <= not have_aw_r;
  wready_w  <= have_aw_r and not bvalid_r;
  arready_w <= not rvalid_r;

  aw_accept_w <= AWVALID and awready_w;
  w_accept_w  <= WVALID and wready_w;
  ar_accept_w <= ARVALID and arready_w;

  AWREADY <= awready_w;
  WREADY  <= wready_w;
  BVALID  <= bvalid_r;
  ARREADY <= arready_w;
  RVALID  <= rvalid_r;

  aw_accept_o <= aw_accept_w;
  w_accept_o  <= w_accept_w;
  ar_accept_o <= ar_accept_w;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        have_aw_r <= '0';
        bvalid_r <= '0';
        rvalid_r <= '0';
      else
        if aw_accept_w = '1' then
          have_aw_r <= '1';
        end if;

        if w_accept_w = '1' then
          have_aw_r <= '0';
          bvalid_r <= '1';
        elsif bvalid_r = '1' and BREADY = '1' then
          bvalid_r <= '0';
        end if;

        if ar_accept_w = '1' then
          rvalid_r <= '1';
        elsif rvalid_r = '1' and RREADY = '1' then
          rvalid_r <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;
