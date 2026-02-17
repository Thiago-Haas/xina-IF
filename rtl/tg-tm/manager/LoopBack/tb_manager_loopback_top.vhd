library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Simple NoC-side TB for manager_loopback_top
-- Sends 5 request packets:
--   3x WRITE (TG phase): hdr0,hdr1,hdr2,addr,payload,checksum
--   2x READ  (TM phase): hdr0,hdr1,hdr2,addr,checksum
-- Expects corresponding responses and checks that READ returns last stored payload.
--
-- NOTE: hdr2 field packing is assumed as used in your datapath:
--   bit0 TYPE, bit1 OP, bits[3:2] STATUS, bits[13:6] LENGTH (8 bits)
entity tb_manager_loopback_top is
end entity;

architecture tb of tb_manager_loopback_top is
  constant c_CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lin_val  : std_logic := '0';
  signal lin_ack  : std_logic;

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lout_val  : std_logic;
  signal lout_ack  : std_logic := '1';  -- always ready

  -- helper: LFSR next (same taps as tg_write_lfsr: 31,30,28,27)
  function lfsr_next(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v  : std_logic_vector(31 downto 0) := x;
    variable fb : std_logic;
  begin
    fb := v(31) xor v(30) xor v(28) xor v(27);
    v  := v(30 downto 0) & fb;
    return v;
  end function;

  function build_hdr2(i_type : std_logic; i_op : std_logic; i_len : natural) return std_logic_vector is
    variable h : std_logic_vector(31 downto 0) := (others => '0');
  begin
    h(0) := i_type;          -- TYPE
    h(1) := i_op;            -- OP
    h(3 downto 2) := "00";   -- STATUS
    h(13 downto 6) := std_logic_vector(to_unsigned(i_len, 8)); -- LENGTH
    return h;
  end function;

  function mk_flit(ctrl : std_logic; w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  begin
    f(c_FLIT_WIDTH-1) := ctrl;
    f(31 downto 0)    := w;
    return f;
  end function;

  -- Wait and check one outgoing flit (samples safely after rising edge)
  procedure expect_flit(
    signal ACLK      : in std_logic;
    signal lout_val  : in std_logic;
    signal lout_data : in std_logic_vector;
    exp_ctrl         : in std_logic;
    exp_word         : in std_logic_vector(31 downto 0);
    tag              : in string
  ) is
    variable got_ctrl : std_logic;
    variable got_word : std_logic_vector(31 downto 0);
  begin
    -- wait for a cycle with valid
    loop
      wait until rising_edge(ACLK);
      exit when lout_val = '1';
    end loop;

    -- allow comb settle (simple + robust with Vivado sim)
    wait for 1 ns;

    got_ctrl := lout_data(lout_data'left);
    got_word := lout_data(31 downto 0);

    assert got_ctrl = exp_ctrl
      report tag & " ctrl mismatch" severity failure;

    assert got_word = exp_word
      report tag & " word mismatch. exp=" &
             to_hstring(exp_word) & " got=" & to_hstring(got_word)
      severity failure;
  end procedure;

  -- Send WRITE request packet: hdr0,hdr1,hdr2,addr,payload,checksum
  procedure send_write_req(
    signal ACLK     : in std_logic;
    signal lin_val  : out std_logic;
    signal lin_data : out std_logic_vector;
    signal lin_ack  : in std_logic;
    hdr0, hdr1, hdr2, addr, payload, csum : in std_logic_vector(31 downto 0)
  ) is
  begin
    lin_val  <= '1';
    lin_data <= mk_flit('1', hdr0);
    wait until lin_ack = '1';
    wait until rising_edge(ACLK);

    lin_data <= mk_flit('0', hdr1);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', hdr2);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', addr);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', payload); wait until rising_edge(ACLK);
    lin_data <= mk_flit('1', csum);  wait until rising_edge(ACLK);

    lin_val  <= '0';
    lin_data <= (others => '0');
    wait until rising_edge(ACLK);
  end procedure;

  -- Send READ request packet: hdr0,hdr1,hdr2,addr,checksum
  procedure send_read_req(
    signal ACLK     : in std_logic;
    signal lin_val  : out std_logic;
    signal lin_data : out std_logic_vector;
    signal lin_ack  : in std_logic;
    hdr0, hdr1, hdr2, addr, csum : in std_logic_vector(31 downto 0)
  ) is
  begin
    lin_val  <= '1';
    lin_data <= mk_flit('1', hdr0);
    wait until lin_ack = '1';
    wait until rising_edge(ACLK);

    lin_data <= mk_flit('0', hdr1);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', hdr2);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', addr);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('1', csum);  wait until rising_edge(ACLK);

    lin_val  <= '0';
    lin_data <= (others => '0');
    wait until rising_edge(ACLK);
  end procedure;

begin
  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- DUT
  dut: entity work.manager_loopback_top
    port map(
      ACLK      => ACLK,
      ARESETn   => ARESETn,
      lin_data  => lin_data,
      lin_val   => lin_val,
      lin_ack   => lin_ack,
      lout_data => lout_data,
      lout_val  => lout_val,
      lout_ack  => lout_ack
    );

  stim: process
    variable addr : std_logic_vector(31 downto 0);
    variable csum : std_logic_vector(31 downto 0);

    variable hdr0, hdr1 : std_logic_vector(31 downto 0);
    variable hdr2_w, hdr2_r : std_logic_vector(31 downto 0);

    variable resp_hdr2_w : std_logic_vector(31 downto 0);
    variable resp_hdr2_r : std_logic_vector(31 downto 0);

    variable p0, p1, p2 : std_logic_vector(31 downto 0);
    variable payload : std_logic_vector(31 downto 0);
  begin
    -- reset
    ARESETn <= '0';
    lin_val <= '0';
    lin_data <= (others => '0');
    wait for 100 ns;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    addr := x"0000_0100";
    csum := x"0000_0000";

    -- 3 LFSR values (payloads for the 3 TG write packets)
    p0 := x"1ACE_B00C";
    p1 := lfsr_next(p0);
    p2 := lfsr_next(p1);

    ----------------------------------------------------------------------
    -- TG phase: 3 WRITE requests (LEN=0 => 1 payload word)
    ----------------------------------------------------------------------
    hdr2_w := build_hdr2('0','1',0);        -- request, write, len=0
    resp_hdr2_w := build_hdr2('1','1',0);   -- response, write, len=0

    for k in 0 to 2 loop
      hdr0 := std_logic_vector(to_unsigned(16#11110000# + k, 32));
      hdr1 := std_logic_vector(to_unsigned(16#22220000# + k, 32));

      if k = 0 then payload := p0;
      elsif k = 1 then payload := p1;
      else payload := p2;
      end if;

      send_write_req(ACLK, lin_val, lin_data, lin_ack, hdr0, hdr1, hdr2_w, addr, payload, csum);

      -- Expect WRITE response: hdr1, hdr0, resp_hdr2_w, checksum
      expect_flit(ACLK, lout_val, lout_data, '1', hdr1, "WRESP hdr0'");
      expect_flit(ACLK, lout_val, lout_data, '0', hdr0, "WRESP hdr1'");
      expect_flit(ACLK, lout_val, lout_data, '0', resp_hdr2_w, "WRESP hdr2'");
      expect_flit(ACLK, lout_val, lout_data, '1', csum, "WRESP csum");
    end loop;

    ----------------------------------------------------------------------
    -- TM phase: 2 READ requests (expect last stored payload = p2)
    ----------------------------------------------------------------------
    hdr2_r := build_hdr2('0','0',0);        -- request, read, len=0
    resp_hdr2_r := build_hdr2('1','0',0);   -- response, read, len=0

    for k in 0 to 1 loop
      hdr0 := std_logic_vector(to_unsigned(16#33330000# + k, 32));
      hdr1 := std_logic_vector(to_unsigned(16#44440000# + k, 32));

      send_read_req(ACLK, lin_val, lin_data, lin_ack, hdr0, hdr1, hdr2_r, addr, csum);

      -- Expect READ response: hdr1, hdr0, resp_hdr2_r, payload(p2), checksum
      expect_flit(ACLK, lout_val, lout_data, '1', hdr1, "RRESP hdr0'");
      expect_flit(ACLK, lout_val, lout_data, '0', hdr0, "RRESP hdr1'");
      expect_flit(ACLK, lout_val, lout_data, '0', resp_hdr2_r, "RRESP hdr2'");
      expect_flit(ACLK, lout_val, lout_data, '0', p2,  "RRESP payload");
      expect_flit(ACLK, lout_val, lout_data, '1', csum, "RRESP csum");
    end loop;

    report "TB completed OK" severity note;
    wait for 50 ns;
    assert false report "End of simulation" severity failure;
  end process;

end architecture;
