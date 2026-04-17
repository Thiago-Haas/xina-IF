library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_manager_ni_pkg.all;

entity manager_uart_encode_datapath is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    load_base_i  : in  std_logic;
    load_enc_i   : in  std_logic;
    event_report_i : in std_logic;
    event_enc_valid_i : in std_logic;
    rx_count_i   : in  std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0);
    ok_count_i   : in  std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0);
    flags_i      : in  std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
    enc_src_i    : in  std_logic_vector(3 downto 0);
    enc_data_i   : in  std_logic_vector(79 downto 0);

    nibble_index_i : in  unsigned(4 downto 0);
    label_sel_i    : in  std_logic_vector(2 downto 0);
    label_index_i  : in  natural range 1 to 8;
    pending_enc_line_o : out std_logic;
    report_has_flags_o : out std_logic;
    hex_char_o     : out std_logic_vector(7 downto 0);
    label_char_o   : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of manager_uart_encode_datapath is
  constant C_LABEL_RX    : string := "RX=";
  constant C_LABEL_OK    : string := " OK=";
  constant C_LABEL_FLAGS : string := " FLAGS=";

  signal rx_count_r : std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0) := (others => '0');
  signal ok_count_r : std_logic_vector(c_TM_COUNTER_WIDTH - 1 downto 0) := (others => '0');
  signal flags_r    : std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0) := (others => '0');
  signal hex_nibble_w : std_logic_vector(3 downto 0);

  function f_char(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;

  function f_hex(n : std_logic_vector(3 downto 0)) return std_logic_vector is
  begin
    case n is
      when x"0" => return x"30";
      when x"1" => return x"31";
      when x"2" => return x"32";
      when x"3" => return x"33";
      when x"4" => return x"34";
      when x"5" => return x"35";
      when x"6" => return x"36";
      when x"7" => return x"37";
      when x"8" => return x"38";
      when x"9" => return x"39";
      when x"A" => return x"41";
      when x"B" => return x"42";
      when x"C" => return x"43";
      when x"D" => return x"44";
      when x"E" => return x"45";
      when others => return x"46";
    end case;
  end function;

  function f_nibble(data : std_logic_vector; index_from_msb : natural) return std_logic_vector is
    variable lo_v : natural;
  begin
    lo_v := 4 * ((data'length / 4) - 1 - index_from_msb);
    return data(lo_v + 3 downto lo_v);
  end function;
begin
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        rx_count_r <= (others => '0');
        ok_count_r <= (others => '0');
        flags_r <= (others => '0');
      elsif load_base_i = '1' then
        rx_count_r <= rx_count_i;
        ok_count_r <= ok_count_i;
        flags_r <= flags_i;
      end if;
    end if;
  end process;

  pending_enc_line_o <= '0';
  report_has_flags_o <= '1';

  with label_sel_i select
    hex_nibble_w <=
      f_nibble(rx_count_r, to_integer(nibble_index_i)) when "000",
      f_nibble(ok_count_r, to_integer(nibble_index_i)) when "001",
      f_nibble(flags_r, to_integer(nibble_index_i))    when others;

  hex_char_o <= f_hex(hex_nibble_w);

  process(label_sel_i, label_index_i)
  begin
    label_char_o <= x"3F";
    case label_sel_i is
      when "000" =>
        if label_index_i <= C_LABEL_RX'length then
          label_char_o <= f_char(C_LABEL_RX(label_index_i));
        end if;
      when "001" =>
        if label_index_i <= C_LABEL_OK'length then
          label_char_o <= f_char(C_LABEL_OK(label_index_i));
        end if;
      when others =>
        if label_index_i <= C_LABEL_FLAGS'length then
          label_char_o <= f_char(C_LABEL_FLAGS(label_index_i));
        end if;
    end case;
  end process;
end architecture;
