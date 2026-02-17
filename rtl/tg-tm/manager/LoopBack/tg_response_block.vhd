library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- TG-side response / capture block:
--  * Captures the single payload word into hold (overwrite)
--  * Owns hold_valid + hold_len regs (real state)
--  * Builds WRITE response hdr2 (TYPE=1, OP=1, STATUS=00, LENGTH=0)
entity tg_response_block is
  generic(
    p_TYPE_BIT   : integer := 0;
    p_OP_BIT     : integer := 1;
    p_STATUS_LSB : integer := 2;
    p_STATUS_MSB : integer := 3;
    p_LENGTH_LSB : integer := 6;
    p_LENGTH_MSB : integer := 13
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- RX payload capture interface
    i_store_pld   : in std_logic;
    i_rx_word     : in std_logic_vector(31 downto 0);

    -- commit at end of write request (from controller)
    i_commit_write : in std_logic;
    i_req_len      : in unsigned(7 downto 0);
    i_req_hdr2     : in std_logic_vector(31 downto 0);

    -- to hold write port (addr kept for compatibility)
    o_hold_wr_en   : out std_logic;
    o_hold_wr_addr : out unsigned(15 downto 0);
    o_hold_wr_data : out std_logic_vector(31 downto 0);

    -- hold metadata (state)
    o_hold_len     : out unsigned(7 downto 0);
    o_hold_valid   : out std_logic;

    -- write response hdr2
    o_wr_resp_hdr2 : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of tg_response_block is
  signal r_hold_len   : unsigned(7 downto 0) := (others => '0');
  signal r_hold_valid : std_logic := '0';

  function set_bit(v : std_logic_vector; idx : integer; b : std_logic) return std_logic_vector is
    variable r : std_logic_vector(v'range) := v;
  begin
    r(idx) := b;
    return r;
  end function;

  function set_slice(v : std_logic_vector; lsb : integer; msb : integer; s : std_logic_vector) return std_logic_vector is
    variable r : std_logic_vector(v'range) := v;
  begin
    r(msb downto lsb) := s;
    return r;
  end function;

  signal w_hdr2 : std_logic_vector(31 downto 0);
begin
  -- Hold write: overwrite single stored payload
  o_hold_wr_en   <= i_store_pld;
  o_hold_wr_addr <= (others => '0');   -- ignored by reg-hold
  o_hold_wr_data <= i_rx_word;

  -- expose hold meta regs
  o_hold_len   <= r_hold_len;
  o_hold_valid <= r_hold_valid;

  -- WRITE response hdr2: TYPE=1, OP=1, STATUS=00, LENGTH=0
  w_hdr2 <= set_slice(
              set_slice(
                set_bit(set_bit(i_req_hdr2, p_TYPE_BIT, '1'), p_OP_BIT, '1'),
                p_STATUS_LSB, p_STATUS_MSB, "00"),
              p_LENGTH_LSB, p_LENGTH_MSB, x"00");
  o_wr_resp_hdr2 <= w_hdr2;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_hold_len   <= (others => '0');
        r_hold_valid <= '0';
      else
        if i_commit_write = '1' then
          r_hold_len   <= i_req_len;
          r_hold_valid <= '1';
        end if;
      end if;
    end if;
  end process;

end rtl;