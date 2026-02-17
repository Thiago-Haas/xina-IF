library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Owns real state: hdr regs + decoded meta regs
entity req_capture_block is
  generic(
    p_TYPE_BIT   : integer := 0;
    p_OP_BIT     : integer := 1;
    p_LENGTH_LSB : integer := 6;
    p_LENGTH_MSB : integer := 13
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_rx_word     : in std_logic_vector(31 downto 0);
    i_store_hdr0  : in std_logic;
    i_store_hdr1  : in std_logic;
    i_store_hdr2  : in std_logic;
    i_store_addr  : in std_logic;
    i_set_meta    : in std_logic;

    o_hdr0 : out std_logic_vector(31 downto 0);
    o_hdr1 : out std_logic_vector(31 downto 0);
    o_hdr2 : out std_logic_vector(31 downto 0);

    o_op   : out std_logic;
    o_type : out std_logic;
    o_len  : out unsigned(7 downto 0)
  );
end entity;

architecture rtl of req_capture_block is
  signal r_hdr0 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_hdr1 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_hdr2 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_addr : std_logic_vector(31 downto 0) := (others => '0');

  signal r_op   : std_logic := '0';
  signal r_type : std_logic := '0';
  signal r_len  : unsigned(7 downto 0) := (others => '0');
begin
  o_hdr0 <= r_hdr0;
  o_hdr1 <= r_hdr1;
  o_hdr2 <= r_hdr2;
  o_op   <= r_op;
  o_type <= r_type;
  o_len  <= r_len;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_hdr0 <= (others => '0');
        r_hdr1 <= (others => '0');
        r_hdr2 <= (others => '0');
        r_addr <= (others => '0');
        r_op   <= '0';
        r_type <= '0';
        r_len  <= (others => '0');
      else
        if i_store_hdr0 = '1' then r_hdr0 <= i_rx_word; end if;
        if i_store_hdr1 = '1' then r_hdr1 <= i_rx_word; end if;
        if i_store_hdr2 = '1' then r_hdr2 <= i_rx_word; end if;
        if i_store_addr = '1' then r_addr <= i_rx_word; end if;

        if i_set_meta = '1' then
          r_type <= i_rx_word(p_TYPE_BIT);
          r_op   <= i_rx_word(p_OP_BIT);
          r_len  <= unsigned(i_rx_word(p_LENGTH_MSB downto p_LENGTH_LSB));
        end if;
      end if;
    end if;
  end process;
end rtl;