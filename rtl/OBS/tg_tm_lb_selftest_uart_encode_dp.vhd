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

    load_base_i  : in  std_logic;
    load_enc_i   : in  std_logic;
    event_report_i : in std_logic;
    event_enc_valid_i : in std_logic;
    tm_count_i   : in  std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0);
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

architecture rtl of tg_tm_lb_selftest_uart_encode_dp is
  constant C_BASE_TM_LSB : natural := c_TM_UART_FLAGS_WIDTH;
  constant C_BASE_TM_MSB : natural := C_BASE_TM_LSB + c_TM_TRANSACTION_COUNTER_WIDTH - 1;

  constant C_LABEL_TS    : string := "TS=";
  constant C_LABEL_TM    : string := "TM=";
  constant C_LABEL_FLAGS : string := " FLAGS=";
  constant C_LABEL_ENC   : string := "ENC SRC=";
  constant C_LABEL_DATA  : string := " DATA=";

  signal fault_data_r  : std_logic_vector(83 downto 0) := (others => '0');
  signal pending_enc_src_r  : std_logic_vector(3 downto 0) := (others => '0');
  signal pending_enc_data_r : std_logic_vector(79 downto 0) := (others => '0');
  signal pending_enc_line_r : std_logic := '0';
  signal report_has_flags_r : std_logic := '0';
  signal nibble_data_w : std_logic_vector(3 downto 0);

  function f_char_to_slv8(c : character) return std_logic_vector is

  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;


  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of fault_data_r : signal is "TRUE";
  attribute DONT_TOUCH of pending_enc_src_r : signal is "TRUE";
  attribute DONT_TOUCH of pending_enc_data_r : signal is "TRUE";
  attribute DONT_TOUCH of pending_enc_line_r : signal is "TRUE";
  attribute DONT_TOUCH of report_has_flags_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of fault_data_r : signal is true;
  attribute syn_preserve of pending_enc_src_r : signal is true;
  attribute syn_preserve of pending_enc_data_r : signal is true;
  attribute syn_preserve of pending_enc_line_r : signal is true;
  attribute syn_preserve of report_has_flags_r : signal is true;
begin
  assert (C_BASE_TM_MSB <= 83)
    report "TM+FLAGS payload width exceeds datapath storage width"
    severity failure;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        fault_data_r <= (others => '0');
        pending_enc_src_r <= (others => '0');
        pending_enc_data_r <= (others => '0');
        pending_enc_line_r <= '0';
        report_has_flags_r <= '0';
      else
        if load_base_i = '1' then
          fault_data_r <= (others => '0');
          fault_data_r(C_BASE_TM_MSB downto C_BASE_TM_LSB) <= tm_count_i;
          if event_report_i = '1' then
            fault_data_r(c_TM_UART_FLAGS_WIDTH - 1 downto 0) <= flags_i;
            report_has_flags_r <= '1';
            if event_enc_valid_i = '1' then
              pending_enc_src_r  <= enc_src_i;
              pending_enc_data_r <= enc_data_i;
              pending_enc_line_r <= '1';
            else
              pending_enc_line_r <= '0';
            end if;
          else
            report_has_flags_r <= '0';
            pending_enc_line_r <= '0';
          end if;
        end if;

        if load_enc_i = '1' then
          fault_data_r(83 downto 80) <= pending_enc_src_r;
          fault_data_r(79 downto 0)  <= pending_enc_data_r;
          pending_enc_line_r <= '0';
        end if;
      end if;
    end if;
  end process;

  pending_enc_line_o <= pending_enc_line_r;
  report_has_flags_o <= report_has_flags_r;

  with to_integer(nibble_index_i) select
    nibble_data_w <=
      fault_data_r(83 downto 80) when 20,
      fault_data_r(79 downto 76) when 19,
      fault_data_r(75 downto 72) when 18,
      fault_data_r(71 downto 68) when 17,
      fault_data_r(67 downto 64) when 16,
      fault_data_r(63 downto 60) when 15,
      fault_data_r(59 downto 56) when 14,
      fault_data_r(55 downto 52) when 13,
      fault_data_r(51 downto 48) when 12,
      fault_data_r(47 downto 44) when 11,
      fault_data_r(43 downto 40) when 10,
      fault_data_r(39 downto 36) when 9,
      fault_data_r(35 downto 32) when 8,
      fault_data_r(31 downto 28) when 7,
      fault_data_r(27 downto 24) when 6,
      fault_data_r(23 downto 20) when 5,
      fault_data_r(19 downto 16) when 4,
      fault_data_r(15 downto 12) when 3,
      fault_data_r(11 downto 8)  when 2,
      fault_data_r(7 downto 4)   when 1,
      fault_data_r(3 downto 0)   when others;

  u_utf8_hex: entity work.utf8_hex
    port map(
      ctl_writelf_i => '0',
      data_i        => nibble_data_w,
      utf_data_o    => hex_char_o
    );

  process(label_sel_i, label_index_i)
  begin
    label_char_o <= x"3F"; -- '?'
    case label_sel_i is
      when "000" =>
        if label_index_i <= C_LABEL_TS'length then
          label_char_o <= f_char_to_slv8(C_LABEL_TS(label_index_i));
        end if;
      when "001" =>
        if label_index_i <= C_LABEL_TM'length then
          label_char_o <= f_char_to_slv8(C_LABEL_TM(label_index_i));
        end if;
      when "010" =>
        if label_index_i <= C_LABEL_FLAGS'length then
          label_char_o <= f_char_to_slv8(C_LABEL_FLAGS(label_index_i));
        end if;
      when "011" =>
        if label_index_i <= C_LABEL_ENC'length then
          label_char_o <= f_char_to_slv8(C_LABEL_ENC(label_index_i));
        end if;
      when "100" =>
        if label_index_i <= C_LABEL_DATA'length then
          label_char_o <= f_char_to_slv8(C_LABEL_DATA(label_index_i));
        end if;
      when others =>
        null;
    end case;
  end process;
end architecture;
