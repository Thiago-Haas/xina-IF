library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;
use work.xina_ni_ft_pkg.all;

library std;
use std.env.all;

-- Minimal testbench: drives only clock + reset into a closed-box DUT.
-- The DUT runs self-test internally; inspect waves for internal signals.

entity tb_tg_tm_lb_selftest_top is
end entity;

architecture tb of tb_tg_tm_lb_selftest_top is

  constant c_CLK_PERIOD : time := 10 ns;
  constant C_TM_PAYLOAD_STOP_COUNT : natural := 262144; -- 1 MiB / 4 B
  constant C_TM_PAYLOAD_BYTES      : natural := c_AXI_DATA_WIDTH / 8;
  constant C_TM_STOP_TOTAL_BYTES   : natural := C_TM_PAYLOAD_STOP_COUNT * C_TM_PAYLOAD_BYTES;
  constant C_TM_HEX_DIGITS      : natural := (c_TM_TRANSACTION_COUNTER_WIDTH + 3) / 4;
  constant C_FLAGS_HEX_DIGITS   : natural := 7;
  constant C_LABEL_TM_LEN       : natural := 3; -- "TM="
  constant C_LABEL_FLAGS_LEN    : natural := 7; -- " FLAGS="
  constant C_TM_ONLY_LINE_LEN   : natural := C_LABEL_TM_LEN + C_TM_HEX_DIGITS;
  constant C_TM_FLAGS_LINE_LEN  : natural := C_LABEL_TM_LEN + C_TM_HEX_DIGITS + C_LABEL_FLAGS_LEN + C_FLAGS_HEX_DIGITS;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';
  signal uart_rx_i  : std_logic;
  signal uart_tx_o  : std_logic;
  signal uart_cts_i : std_logic := '0';
  signal uart_rts_o : std_logic;

  -- Host UART instance (testbench side)
  signal host_tready : std_logic;
  signal host_tstart : std_logic := '0';
  signal host_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal host_tdone  : std_logic;
  signal host_rdone  : std_logic;
  signal host_rdata  : std_logic_vector(7 downto 0);
  signal host_rerr   : std_logic;
  signal host_uart_tx : std_logic;
  signal stop_issued : std_logic := '0';

  signal rx_count : integer := 0;
  signal tx_toggle_count : integer := 0;
  file f_tb_uart_log : text open write_mode is "tb_uart_console.log";

  alias mon_tm_transaction_count is
    << signal .tb_tg_tm_lb_selftest_top.dut.w_tm_transaction_count : std_logic_vector(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0) >>;

  function f_byte_to_char(b : std_logic_vector(7 downto 0)) return character is
    variable n : integer := to_integer(unsigned(b));
  begin
    if (n >= 32) and (n <= 126) then
      return character'val(n);
    elsif n = 9 then
      return character'val(n); -- tab
    else
      return '.';
    end if;
  end function;

  function f_hex_char_to_int(c : character) return integer is
  begin
    if (c >= '0') and (c <= '9') then
      return character'pos(c) - character'pos('0');
    elsif (c >= 'a') and (c <= 'f') then
      return 10 + character'pos(c) - character'pos('a');
    elsif (c >= 'A') and (c <= 'F') then
      return 10 + character'pos(c) - character'pos('A');
    else
      return -1;
    end if;
  end function;

  function f_hex_to_integer(s : string) return integer is
    variable v : integer := 0;
    variable d : integer;
  begin
    for i in s'range loop
      d := f_hex_char_to_int(s(i));
      if d < 0 then
        return 0;
      end if;
      if v > (integer'high - d) / 16 then
        return integer'high;
      end if;
      v := (v * 16) + d;
    end loop;
    return v;
  end function;

  function f_is_hex_string(s : string) return boolean is
  begin
    for i in s'range loop
      if f_hex_char_to_int(s(i)) < 0 then
        return false;
      end if;
    end loop;
    return true;
  end function;

  function f_hex_to_bin_string(s : string) return string is
    variable v : string(1 to s'length * 4);
    variable p : integer := 1;
    variable d : integer;
  begin
    for i in s'range loop
      d := f_hex_char_to_int(s(i));
      if d < 0 then
        d := 0;
      end if;
      if (d / 8) = 1 then v(p) := '1'; else v(p) := '0'; end if; p := p + 1;
      d := d mod 8;
      if (d / 4) = 1 then v(p) := '1'; else v(p) := '0'; end if; p := p + 1;
      d := d mod 4;
      if (d / 2) = 1 then v(p) := '1'; else v(p) := '0'; end if; p := p + 1;
      d := d mod 2;
      if d = 1 then v(p) := '1'; else v(p) := '0'; end if; p := p + 1;
    end loop;
    return v;
  end function;

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- Connect host UART TX into DUT UART RX
  uart_rx_i <= host_uart_tx;

  -- DUT
  dut: entity work.tg_tm_lb_selftest_top
    port map (
      ACLK    => ACLK,
      ARESETn => ARESETn,
      uart_rx_i  => uart_rx_i,
      uart_tx_o  => uart_tx_o,
      uart_cts_i => uart_cts_i,
      uart_rts_o => uart_rts_o
    );

  -- Host UART: drives commands into DUT and decodes DUT TX stream.
  u_host_uart: entity work.uart
    port map(
      baud_div_i => x"0001",
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => host_tready,
      tstart_i   => host_tstart,
      tdata_i    => host_tdata,
      tdone_o    => host_tdone,
      rready_i   => '1',
      rdone_o    => host_rdone,
      rdata_o    => host_rdata,
      rerr_o     => host_rerr,
      rstn_i     => ARESETn,
      clk_i      => ACLK,
      uart_rx_i  => uart_tx_o,
      uart_tx_o  => host_uart_tx,
      uart_cts_i => '0',
      uart_rts_o => open
    );

  -- Monitor bytes transmitted by DUT UART.
  p_uart_rx_monitor: process(ACLK)
    variable v_line : string(1 to 256);
    variable v_len  : integer range 0 to 256 := 0;
    variable v_byte : integer;
    variable v_log  : line;
    variable v_tm_dec : integer;
    variable v_flags_bin : string(1 to 28);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        rx_count <= 0;
        v_len := 0;
      else
        if (host_rdone = '1') and (host_rerr = '0') then
          rx_count <= rx_count + 1;
          v_byte := to_integer(unsigned(host_rdata));

          if v_byte = 10 then -- LF: flush one terminal-like line
            if v_len > 0 then
              report "UART RX: " & v_line(1 to v_len) severity warning;
              write(v_log, string'("UART RX: "));
              write(v_log, v_line(1 to v_len));
              writeline(f_tb_uart_log, v_log);

              -- Decode base line format from DUT:
              -- TM=<N hex> FLAGS=<7 hex>, where N follows c_TM_TRANSACTION_COUNTER_WIDTH.
              if (v_len = C_TM_FLAGS_LINE_LEN) and
                 (v_line(1 to 3) = "TM=") and
                 (v_line(4 + C_TM_HEX_DIGITS to 3 + C_TM_HEX_DIGITS + C_LABEL_FLAGS_LEN) = " FLAGS=") and
                 f_is_hex_string(v_line(4 to 3 + C_TM_HEX_DIGITS)) and
                 f_is_hex_string(v_line(4 + C_TM_HEX_DIGITS + C_LABEL_FLAGS_LEN to C_TM_FLAGS_LINE_LEN)) then
                v_tm_dec := f_hex_to_integer(v_line(4 to 3 + C_TM_HEX_DIGITS));
                v_flags_bin := f_hex_to_bin_string(v_line(4 + C_TM_HEX_DIGITS + C_LABEL_FLAGS_LEN to C_TM_FLAGS_LINE_LEN));
                report "UART RX DECODED: TM_DEC=" & integer'image(v_tm_dec) &
                       " FLAGS_BIN=" & v_flags_bin severity warning;
                write(v_log, string'("UART RX DECODED: TM_DEC="));
                write(v_log, integer'image(v_tm_dec));
                write(v_log, string'(" FLAGS_BIN="));
                write(v_log, v_flags_bin);
                writeline(f_tb_uart_log, v_log);
              elsif (v_len = C_TM_ONLY_LINE_LEN) and
                    (v_line(1 to 3) = "TM=") and
                    f_is_hex_string(v_line(4 to 3 + C_TM_HEX_DIGITS)) then
                v_tm_dec := f_hex_to_integer(v_line(4 to 3 + C_TM_HEX_DIGITS));
                report "UART RX DECODED: TM_DEC=" & integer'image(v_tm_dec) severity warning;
                write(v_log, string'("UART RX DECODED: TM_DEC="));
                write(v_log, integer'image(v_tm_dec));
                writeline(f_tb_uart_log, v_log);
              end if;
            else
              report "UART RX: <LF>" severity warning;
              write(v_log, string'("UART RX: <LF>"));
              writeline(f_tb_uart_log, v_log);
            end if;
            v_len := 0;
          elsif v_byte = 13 then
            null; -- ignore CR
          else
            if v_len < 256 then
              v_len := v_len + 1;
              v_line(v_len) := f_byte_to_char(host_rdata);
            end if;
          end if;
        elsif (host_rdone = '1') and (host_rerr = '1') then
          -- Still report raw traffic even with RX error to help debug UART framing.
          rx_count <= rx_count + 1;
          report "UART RX framing/parity error, raw byte=" & integer'image(to_integer(unsigned(host_rdata))) severity warning;
          write(v_log, string'("UART RX framing/parity error, raw byte="));
          write(v_log, integer'image(to_integer(unsigned(host_rdata))));
          writeline(f_tb_uart_log, v_log);
        end if;
      end if;
    end if;
  end process;

  -- Raw UART TX activity monitor from DUT.
  p_uart_tx_activity: process(ACLK)
    variable v_last_tx : std_logic := '1';
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        v_last_tx := '1';
        tx_toggle_count <= 0;
      else
        if uart_tx_o /= v_last_tx then
          tx_toggle_count <= tx_toggle_count + 1;
          v_last_tx := uart_tx_o;
        end if;
      end if;
    end if;
  end process;

  -- Stop simulation exactly when TM payload count reaches 262,144 (1 MiB for 32-bit payloads).
  p_stop_at_target_payload_count: process(ACLK)
    constant C_TARGET_TM_COUNT_U : unsigned(c_TM_TRANSACTION_COUNTER_WIDTH - 1 downto 0) :=
      to_unsigned(C_TM_PAYLOAD_STOP_COUNT, c_TM_TRANSACTION_COUNTER_WIDTH);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        stop_issued <= '0';
      elsif stop_issued = '0' then
        if unsigned(mon_tm_transaction_count) >= C_TARGET_TM_COUNT_U then
          stop_issued <= '1';
          report "TB stop condition reached: TM payload count=" &
                 integer'image(C_TM_PAYLOAD_STOP_COUNT) &
                 " (" & integer'image(C_TM_STOP_TOTAL_BYTES) & " bytes, 1 MiB)." severity warning;
          std.env.stop;
        end if;
      end if;
    end if;
  end process;

  -- reset + run
  process
    procedure uart_send(constant b : std_logic_vector(7 downto 0)) is
    begin
      loop
        wait until rising_edge(ACLK);
        exit when host_tready = '1';
      end loop;
      host_tdata  <= b;
      host_tstart <= '1';
      wait until rising_edge(ACLK);
      host_tstart <= '0';
    end procedure;
  begin
    ARESETn <= '0';
    wait for 50 ns;
    ARESETn <= '1';

    -- UART command test sequence:
    -- 'D' disable OBS enables
    -- 'E' enable OBS enables
    -- 'P' pause experiment
    -- 'S' start experiment
    -- 'R' reset experiment sequencing
    uart_send(x"44"); -- D
    wait for 20 us;
    uart_send(x"45"); -- E
    wait for 20 us;
    uart_send(x"50"); -- P
    wait for 20 us;
    uart_send(x"53"); -- S
    wait for 20 us;
    uart_send(x"52"); -- R

    -- Keep simulation running indefinitely for continuous UART monitoring.
    wait;
  end process;

end architecture;
