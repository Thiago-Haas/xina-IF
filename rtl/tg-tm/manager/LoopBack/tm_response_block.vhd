library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tm_response_block is
  generic(
    p_TYPE_BIT   : integer := 0;
    p_OP_BIT     : integer := 1;
    p_STATUS_LSB : integer := 2;
    p_STATUS_MSB : integer := 3;
    p_LENGTH_LSB : integer := 6;
    p_LENGTH_MSB : integer := 13
  );
  port(
    i_req_hdr2 : in std_logic_vector(31 downto 0);
    i_req_len  : in unsigned(7 downto 0);

    i_hold_valid   : in std_logic;
    i_hold_rd_data : in std_logic_vector(31 downto 0);

    o_rd_resp_hdr2 : out std_logic_vector(31 downto 0);
    o_payload_word : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of tm_response_block is
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
  -- READ response: TYPE=1, OP=0, STATUS=00, LENGTH=req_len
  w_hdr2 <= set_slice(
              set_slice(
                set_bit(set_bit(i_req_hdr2, p_TYPE_BIT, '1'), p_OP_BIT, '0'),
                p_STATUS_LSB, p_STATUS_MSB, "00"),
              p_LENGTH_LSB, p_LENGTH_MSB, std_logic_vector(i_req_len));
  o_rd_resp_hdr2 <= w_hdr2;

  -- gate payload if no stored data yet
  o_payload_word <= i_hold_rd_data when i_hold_valid = '1' else (others => '0');
end rtl;