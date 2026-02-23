library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

entity tb_tg_tm_ni_hwloopback_flat_dbg is
end entity;

architecture tb of tb_tg_tm_ni_hwloopback_flat_dbg is

  constant c_CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;

  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;

  signal tg_addr  : std_logic_vector(63 downto 0) := x"00000000_00000100";
  signal tm_addr  : std_logic_vector(63 downto 0) := x"00000000_00000100";

  signal tg_seed  : std_logic_vector(31 downto 0) := x"1ACEB00C";
  signal tm_seed  : std_logic_vector(31 downto 0) := x"1ACEB00C";

  signal tm_mismatch : std_logic;
  signal tm_expected : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- debug signals from top
  signal dbg_lin_val, dbg_lin_ack : std_logic;
  signal dbg_lin_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);

  signal dbg_lout_val, dbg_lout_ack : std_logic;
  signal dbg_lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);

  signal dbg_ctrl_state         : std_logic_vector(2 downto 0);
  signal dbg_ctrl_cap_idx       : unsigned(5 downto 0);
  signal dbg_ctrl_seen_last     : std_logic;
  signal dbg_ctrl_payload_idx   : unsigned(7 downto 0);
  signal dbg_ctrl_payload_words : unsigned(8 downto 0);
  signal dbg_ctrl_resp_is_read  : std_logic;

  signal dbg_dp_hdr0, dbg_dp_hdr1, dbg_dp_hdr2 : std_logic_vector(31 downto 0);
  signal dbg_dp_addr : std_logic_vector(31 downto 0);
  signal dbg_dp_opc  : std_logic;
  signal dbg_dp_ready: std_logic;

  signal dbg_req_ready, dbg_req_is_write, dbg_req_is_read : std_logic;
  signal dbg_req_len : unsigned(7 downto 0);
  signal dbg_hold_valid : std_logic;

  function hex_nibble(n : std_logic_vector(3 downto 0)) return character is
  begin
    case n is
      when "0000" => return '0';
      when "0001" => return '1';
      when "0010" => return '2';
      when "0011" => return '3';
      when "0100" => return '4';
      when "0101" => return '5';
      when "0110" => return '6';
      when "0111" => return '7';
      when "1000" => return '8';
      when "1001" => return '9';
      when "1010" => return 'A';
      when "1011" => return 'B';
      when "1100" => return 'C';
      when "1101" => return 'D';
      when "1110" => return 'E';
      when others => return 'F';
    end case;
  end function;

  function hex32(x : std_logic_vector(31 downto 0)) return string is
    variable s : string(1 to 8);
    variable nib : std_logic_vector(3 downto 0);
  begin
    for i in 0 to 7 loop
      nib := x(31 - i*4 downto 28 - i*4);
      s(i+1) := hex_nibble(nib);
    end loop;
    return s;
  end function;

  function st_name(st : std_logic_vector(2 downto 0)) return string is
  begin
    case st is
      when "000" => return "CAP";
      when "001" => return "HDR0";
      when "010" => return "HDR1";
      when "011" => return "HDR2";
      when "100" => return "PAYL";
      -- In the debug loopback we use a single checksum flit (ctrl='1') like the reference TBs.
      when "101" => return "CHK";
      when "110" => return "(unused)";
      when others => return "UNK";
    end case;
  end function;

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  dut: entity work.tg_tm_ni_hwloopback_flat_top_dbg
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_tg_start => tg_start,
      o_tg_done  => tg_done,
      TG_INPUT_ADDRESS => tg_addr,
      TG_STARTING_SEED => tg_seed,

      i_tm_start => tm_start,
      o_tm_done  => tm_done,
      TM_INPUT_ADDRESS => tm_addr,
      TM_STARTING_SEED => tm_seed,

      o_tm_mismatch       => tm_mismatch,
      o_tm_expected_value => tm_expected,

      dbg_lin_val  => dbg_lin_val,
      dbg_lin_ack  => dbg_lin_ack,
      dbg_lin_data => dbg_lin_data,

      dbg_lout_val  => dbg_lout_val,
      dbg_lout_ack  => dbg_lout_ack,
      dbg_lout_data => dbg_lout_data,

      dbg_ctrl_state         => dbg_ctrl_state,
      dbg_ctrl_cap_idx       => dbg_ctrl_cap_idx,
      dbg_ctrl_seen_last     => dbg_ctrl_seen_last,
      dbg_ctrl_payload_idx   => dbg_ctrl_payload_idx,
      dbg_ctrl_payload_words => dbg_ctrl_payload_words,
      dbg_ctrl_resp_is_read  => dbg_ctrl_resp_is_read,

      dbg_dp_hdr0  => dbg_dp_hdr0,
      dbg_dp_hdr1  => dbg_dp_hdr1,
      dbg_dp_hdr2  => dbg_dp_hdr2,
      dbg_dp_addr  => dbg_dp_addr,
      dbg_dp_opc   => dbg_dp_opc,
      dbg_dp_ready => dbg_dp_ready,

      dbg_req_ready    => dbg_req_ready,
      dbg_req_is_write => dbg_req_is_write,
      dbg_req_is_read  => dbg_req_is_read,
      dbg_req_len      => dbg_req_len,
      dbg_hold_valid   => dbg_hold_valid
    );

  -- reset + stimulus
  stim: process
  begin
    ARESETn <= '0';
    tg_start <= '0';
    tm_start <= '0';
    wait for 50 ns;
    ARESETn <= '1';
    wait for 50 ns;

    report "=== DBG: starting TG ===" severity note;
    tg_start <= '1';
    wait until rising_edge(ACLK);
    tg_start <= '0';
    wait until tg_done = '1';
    report "=== DBG: TG done, starting TM ===" severity note;

    tm_start <= '1';
    wait until rising_edge(ACLK);
    tm_start <= '0';

    wait until tm_done = '1';
    report "=== DBG: TM done. mismatch=" & std_logic'image(tm_mismatch) severity note;

    if tm_mismatch = '1' then
      report "TM expected=" & hex32(tm_expected(31 downto 0)) severity error;
    end if;

    std.env.stop;
    wait;
  end process;

  -- Console logger: prints on key events
  logger: process(ACLK)
    variable prev_state : std_logic_vector(2 downto 0) := (others => '0');
  begin
    if rising_edge(ACLK) then
      if ARESETn = '1' then
        if dbg_ctrl_state /= prev_state then
          report "LB FSM " & st_name(prev_state) & " -> " & st_name(dbg_ctrl_state) &
                 " cap_idx=" & integer'image(to_integer(dbg_ctrl_cap_idx)) &
                 " seen_last=" & std_logic'image(dbg_ctrl_seen_last) &
                 " req_ready=" & std_logic'image(dbg_req_ready) &
                 " opc=" & std_logic'image(dbg_dp_opc) &
                 " len=" & integer'image(to_integer(dbg_req_len)) &
                 " addr=0x" & hex32(dbg_dp_addr)
                 severity note;
          prev_state := dbg_ctrl_state;
        end if;

        -- request flit accepted
        if dbg_lin_val='1' and dbg_lin_ack='1' then
          report "LB RX flit: ctrl=" & std_logic'image(dbg_lin_data(dbg_lin_data'left)) &
                 " data=0x" & hex32(dbg_lin_data(31 downto 0)) &
                 " cap_idx=" & integer'image(to_integer(dbg_ctrl_cap_idx))
                 severity note;
        end if;

        -- response flit accepted by NI
        if dbg_lout_val='1' and dbg_lout_ack='1' then
          report "LB TX flit: ctrl=" & std_logic'image(dbg_lout_data(dbg_lout_data'left)) &
                 " data=0x" & hex32(dbg_lout_data(31 downto 0)) &
                 " payload_idx=" & integer'image(to_integer(dbg_ctrl_payload_idx))
                 severity note;
        end if;
      end if;
    end if;
  end process;

end architecture;
