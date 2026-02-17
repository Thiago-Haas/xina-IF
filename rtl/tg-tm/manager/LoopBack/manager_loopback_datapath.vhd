library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

entity manager_loopback_datapath is
  generic(
    p_MAX_PAYLOAD_WORDS : natural := 256  -- kept for compatibility (unused by reg-hold)
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_rx_word : in std_logic_vector(31 downto 0);

    i_store_hdr0   : in std_logic;
    i_store_hdr1   : in std_logic;
    i_store_hdr2   : in std_logic;
    i_store_addr   : in std_logic;
    i_store_pld    : in std_logic;
    i_set_meta     : in std_logic;
    i_commit_write : in std_logic;

    i_pld_widx : in unsigned(15 downto 0);
    i_pld_ridx : in unsigned(15 downto 0);

    o_req_is_write : out std_logic;
    o_req_is_read  : out std_logic;
    o_req_len      : out unsigned(7 downto 0);

    o_hold_len   : out unsigned(7 downto 0);
    o_hold_valid : out std_logic;

    i_tx_sel  : in  unsigned(2 downto 0);
    o_tx_word : out std_logic_vector(31 downto 0);
    o_tx_ctrl : out std_logic
  );
end entity;

architecture rtl of manager_loopback_datapath is
  -- hdr2 bit positions (ASSUMED; adjust if needed)
  constant c_TYPE_BIT   : integer := 0;
  constant c_OP_BIT     : integer := 1;
  constant c_STATUS_LSB : integer := 2;
  constant c_STATUS_MSB : integer := 3;
  constant c_LENGTH_LSB : integer := 6;
  constant c_LENGTH_MSB : integer := 13;

  signal req_hdr0 : std_logic_vector(31 downto 0);
  signal req_hdr1 : std_logic_vector(31 downto 0);
  signal req_hdr2 : std_logic_vector(31 downto 0);
  signal req_op   : std_logic;
  signal req_type : std_logic;
  signal req_len  : unsigned(7 downto 0);

  signal hold_wr_en   : std_logic;
  signal hold_wr_addr : unsigned(15 downto 0);
  signal hold_wr_data : std_logic_vector(31 downto 0);
  signal hold_rd_data : std_logic_vector(31 downto 0);

  signal hold_len   : unsigned(7 downto 0);
  signal hold_valid : std_logic;

  signal wr_resp_hdr2 : std_logic_vector(31 downto 0);
  signal rd_resp_hdr2 : std_logic_vector(31 downto 0);
  signal resp_hdr2    : std_logic_vector(31 downto 0);

  signal resp_hdr0 : std_logic_vector(31 downto 0);
  signal resp_hdr1 : std_logic_vector(31 downto 0);

  signal tm_payload : std_logic_vector(31 downto 0);
begin
  o_req_is_write <= '1' when (req_type='0' and req_op='1') else '0';
  o_req_is_read  <= '1' when (req_type='0' and req_op='0') else '0';
  o_req_len      <= req_len;

  o_hold_len   <= hold_len;
  o_hold_valid <= hold_valid;

  u_REQ: entity work.req_capture_block
    generic map(
      p_TYPE_BIT   => c_TYPE_BIT,
      p_OP_BIT     => c_OP_BIT,
      p_LENGTH_LSB => c_LENGTH_LSB,
      p_LENGTH_MSB => c_LENGTH_MSB
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_rx_word    => i_rx_word,
      i_store_hdr0 => i_store_hdr0,
      i_store_hdr1 => i_store_hdr1,
      i_store_hdr2 => i_store_hdr2,
      i_store_addr => i_store_addr,
      i_set_meta   => i_set_meta,
      o_hdr0 => req_hdr0,
      o_hdr1 => req_hdr1,
      o_hdr2 => req_hdr2,
      o_op   => req_op,
      o_type => req_type,
      o_len  => req_len
    );

  u_TG: entity work.tg_response_block
    generic map(
      p_TYPE_BIT   => c_TYPE_BIT,
      p_OP_BIT     => c_OP_BIT,
      p_STATUS_LSB => c_STATUS_LSB,
      p_STATUS_MSB => c_STATUS_MSB,
      p_LENGTH_LSB => c_LENGTH_LSB,
      p_LENGTH_MSB => c_LENGTH_MSB
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_store_pld    => i_store_pld,
      i_rx_word      => i_rx_word,
      i_commit_write => i_commit_write,
      i_req_len      => req_len,
      i_req_hdr2     => req_hdr2,
      o_hold_wr_en   => hold_wr_en,
      o_hold_wr_addr => hold_wr_addr,
      o_hold_wr_data => hold_wr_data,
      o_hold_len     => hold_len,
      o_hold_valid   => hold_valid,
      o_wr_resp_hdr2 => wr_resp_hdr2
    );

  u_HOLD: entity work.lfsr_hold
    generic map(
      p_MAX_WORDS => p_MAX_PAYLOAD_WORDS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_wr_en   => hold_wr_en,
      i_wr_addr => hold_wr_addr,
      i_wr_data => hold_wr_data,
      i_rd_addr => i_pld_ridx,
      o_rd_data => hold_rd_data
    );

  u_TM: entity work.tm_response_block
    generic map(
      p_TYPE_BIT   => c_TYPE_BIT,
      p_OP_BIT     => c_OP_BIT,
      p_STATUS_LSB => c_STATUS_LSB,
      p_STATUS_MSB => c_STATUS_MSB,
      p_LENGTH_LSB => c_LENGTH_LSB,
      p_LENGTH_MSB => c_LENGTH_MSB
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      i_req_hdr2 => req_hdr2,
      i_req_len  => req_len,
      i_hold_valid   => hold_valid,
      i_hold_rd_data => hold_rd_data,
      i_tx_sel       => i_tx_sel,
      o_rd_resp_hdr2 => rd_resp_hdr2,
      o_payload_word => tm_payload
    );

  -- response swap
  resp_hdr0 <= req_hdr1;
  resp_hdr1 <= req_hdr0;

  -- hdr2 selection based on OP
  resp_hdr2 <= rd_resp_hdr2 when req_op='0' else wr_resp_hdr2;

  -- tx mux
  process(all)
  begin
    o_tx_word <= (others=>'0');
    o_tx_ctrl <= '0';

    case i_tx_sel is
      when "000" => o_tx_word <= resp_hdr0;     o_tx_ctrl <= '1'; -- hdr0
      when "001" => o_tx_word <= resp_hdr1;     o_tx_ctrl <= '0'; -- hdr1
      when "010" => o_tx_word <= resp_hdr2;     o_tx_ctrl <= '0'; -- hdr2
      when "011" => o_tx_word <= tm_payload;    o_tx_ctrl <= '0'; -- payload
      when "100" => o_tx_word <= (others=>'0'); o_tx_ctrl <= '1'; -- checksum
      when others => o_tx_word <= (others=>'0'); o_tx_ctrl <= '0';
    end case;
  end process;

end rtl;