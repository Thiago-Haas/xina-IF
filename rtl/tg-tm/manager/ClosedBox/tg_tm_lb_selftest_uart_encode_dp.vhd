library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- Datapath for UART encode block:
-- * assembles and stores packed fault/status data
-- * selects current nibble from packed fault/status data
-- * converts nibble to ASCII hex
-- * outputs label character selected by controller
entity tg_tm_lb_selftest_uart_encode_dp is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_load_base  : in  std_logic;
    i_load_enc   : in  std_logic;
    i_tm_count   : in  std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
    i_flags      : in  std_logic_vector(c_TM_UART_FLAGS_WIDTH - 1 downto 0);
    i_enc_src    : in  std_logic_vector(3 downto 0);
    i_enc_data   : in  std_logic_vector(79 downto 0);

    i_nibble_index : in  unsigned(4 downto 0);
    i_label_sel    : in  std_logic_vector(2 downto 0);
    i_label_index  : in  natural range 1 to 8;
    o_hex_char     : out std_logic_vector(7 downto 0);
    o_label_char   : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of tg_tm_lb_selftest_uart_encode_dp is
  constant C_BASE_TM_LSB : natural := c_TM_UART_FLAGS_WIDTH;
  constant C_BASE_TM_MSB : natural := C_BASE_TM_LSB + c_TM_TRANSACTION_COUNTER_WIDTH - 1;

  constant C_LABEL_TS    : string := "TS=";
  constant C_LABEL_TM    : string := "TM=";
  constant C_LABEL_FLAGS : string := " FLAGS=";
  constant C_LABEL_ENC   : string := "ENC SRC=";
  constant C_LABEL_DATA  : string := " DATA=";

  signal r_fault_data  : std_logic_vector(83 downto 0) := (others => '0');
  signal w_nibble_data : std_logic_vector(3 downto 0);

  function f_char_to_slv8(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;
begin
  assert (C_BASE_TM_MSB <= 83)
    report "TM+FLAGS payload width exceeds datapath storage width"
    severity failure;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_fault_data <= (others => '0');
      else
        if i_load_base = '1' then
          r_fault_data <= (others => '0');
          r_fault_data(C_BASE_TM_MSB downto C_BASE_TM_LSB) <= i_tm_count;
          r_fault_data(c_TM_UART_FLAGS_WIDTH - 1 downto 0) <= i_flags;
        end if;

        if i_load_enc = '1' then
          r_fault_data(83 downto 80) <= i_enc_src;
          r_fault_data(79 downto 0)  <= i_enc_data;
        end if;
      end if;
    end if;
  end process;

  with to_integer(i_nibble_index) select
    w_nibble_data <=
      r_fault_data(83 downto 80) when 20,
      r_fault_data(79 downto 76) when 19,
      r_fault_data(75 downto 72) when 18,
      r_fault_data(71 downto 68) when 17,
      r_fault_data(67 downto 64) when 16,
      r_fault_data(63 downto 60) when 15,
      r_fault_data(59 downto 56) when 14,
      r_fault_data(55 downto 52) when 13,
      r_fault_data(51 downto 48) when 12,
      r_fault_data(47 downto 44) when 11,
      r_fault_data(43 downto 40) when 10,
      r_fault_data(39 downto 36) when 9,
      r_fault_data(35 downto 32) when 8,
      r_fault_data(31 downto 28) when 7,
      r_fault_data(27 downto 24) when 6,
      r_fault_data(23 downto 20) when 5,
      r_fault_data(19 downto 16) when 4,
      r_fault_data(15 downto 12) when 3,
      r_fault_data(11 downto 8)  when 2,
      r_fault_data(7 downto 4)   when 1,
      r_fault_data(3 downto 0)   when others;

  u_utf8_hex: entity work.utf8_hex
    port map(
      ctl_writelf_i => '0',
      data_i        => w_nibble_data,
      utf_data_o    => o_hex_char
    );

  process(i_label_sel, i_label_index)
  begin
    o_label_char <= x"3F"; -- '?'
    case i_label_sel is
      when "000" =>
        if i_label_index <= C_LABEL_TS'length then
          o_label_char <= f_char_to_slv8(C_LABEL_TS(i_label_index));
        end if;
      when "001" =>
        if i_label_index <= C_LABEL_TM'length then
          o_label_char <= f_char_to_slv8(C_LABEL_TM(i_label_index));
        end if;
      when "010" =>
        if i_label_index <= C_LABEL_FLAGS'length then
          o_label_char <= f_char_to_slv8(C_LABEL_FLAGS(i_label_index));
        end if;
      when "011" =>
        if i_label_index <= C_LABEL_ENC'length then
          o_label_char <= f_char_to_slv8(C_LABEL_ENC(i_label_index));
        end if;
      when "100" =>
        if i_label_index <= C_LABEL_DATA'length then
          o_label_char <= f_char_to_slv8(C_LABEL_DATA(i_label_index));
        end if;
      when others =>
        null;
    end case;
  end process;
end architecture;
