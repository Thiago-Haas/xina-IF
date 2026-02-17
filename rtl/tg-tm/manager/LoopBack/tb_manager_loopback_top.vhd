library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Simple NoC-side TB for manager_loopback_top
--
-- Key trick: we DON'T keep lout_ack high all the time.
-- We hold lout_ack='0' so the DUT keeps the current flit stable,
-- then we sample it and pulse lout_ack='1' for one cycle to advance.
--
-- This avoids the "off-by-one" that happens when lout_ack='1' continuously
-- (the DUT advances on the same rising edge where you try to sample).

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
  signal lout_ack  : std_logic := '0'; -- TB controls this

  -- LFSR helper (taps: 31,30,28,27)
  function lfsr_next(x : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v  : std_logic_vector(31 downto 0) := x;
    variable fb : std_logic;
  begin
    fb := v(31) xor v(30) xor v(28) xor v(27);
    v  := v(30 downto 0) & fb;
    return v;
  end function;

  -- hdr2 packing assumption (matches datapath constants)
  function build_hdr2(i_type : std_logic; i_op : std_logic; i_len : natural) return std_logic_vector is
    variable h : std_logic_vector(31 downto 0) := (others => '0');
  begin
    h(0) := i_type;        -- TYPE
    h(1) := i_op;          -- OP
    h(3 downto 2) := "00"; -- STATUS
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

  -- Accept exactly one outgoing flit: sample, check, then pulse lout_ack to advance
  procedure expect_and_accept_flit(
    signal ACLK      : in std_logic;
    signal lout_val  : in std_logic;
    signal lout_data : in std_logic_vector;
    signal lout_ack  : out std_logic;
    exp_ctrl         : in std_logic;
    exp_word         : in std_logic_vector(31 downto 0);
    tag              : in string
  ) is
    variable got_ctrl : std_logic;
    variable got_word : std_logic_vector(31 downto 0);
  begin
    -- wait until DUT presents a flit
    while lout_val /= '1' loop
      wait until rising_edge(ACLK);
    end loop;

    -- settle time (combinational)
    wait for 1 ns;

    got_ctrl := lout_data(lout_data'left);
    got_word := lout_data(31 downto 0);

    assert got_ctrl = exp_ctrl
      report tag & " ctrl mismatch. exp=" & std_logic'image(exp_ctrl) &
             " got=" & std_logic'image(got_ctrl)
      severity failure;

    assert got_word = exp_word
      report tag & " word mismatch. exp=" & to_hstring(exp_word) &
             " got=" & to_hstring(got_word)
      severity failure;

    -- advance DUT by handshaking this flit for one cycle
    lout_ack <= '1';
    wait until rising_edge(ACLK);
    lout_ack <= '0';
    wait until rising_edge(ACLK);
  end procedure;

  -- Send WRITE request (6 flits): hdr0 hdr1 hdr2 addr payload checksum
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

    -- wait until DUT exits idle and is ready
    wait until lin_ack = '1';
    wait until rising_edge(ACLK);

    lin_data <= mk_flit('0', hdr1);     wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', hdr2);     wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', addr);     wait until rising_edge(ACLK);
    lin_data <= mk_flit('0', payload);  wait until rising_edge(ACLK);
    lin_data <= mk_flit('1', csum);     wait until rising_edge(ACLK);

    lin_val  <= '0';
    lin_data <= (others => '0');
    wait until rising_edge(ACLK);
  end procedure;

  -- Send READ request (5 flits): hdr0 hdr1 hdr2 addr checksum
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
    variable addr : std_logic_vector(31 downto 0) := x"0000_0100";
    variable csum : std_logic_vector(31 downto 0) := x"0000_0000";

    variable hdr0, hdr1 : std_logic_vector(31 downto 0);
    variable hdr2_w, hdr2_r : std_logic_vector(31 downto 0);
    variable resp_hdr2_w, resp_hdr2_r : std_logic_vector(31 downto 0);

    variable p0, p1, p2 : std_logic_vector(31 downto 0);
    variable payload    : std_logic_vector(31 downto 0);
  begin
    -- reset
    ARESETn <= '0';
    lin_val <= '0';
    lin_data <= (others => '0');
    lout_ack <= '0';
    wait for 100 ns;
    wait until rising_edge(ACLK);
    ARESETn <= '1';
    wait until rising_edge(ACLK);

    -- 3 payload words (LFSR progression)
    p0 := x"1ACE_B00C";
    p1 := lfsr_next(p0);
    p2 := lfsr_next(p1);

    -- hdr2 constants (LEN=0 => 1 payload word)
    hdr2_w := build_hdr2('0','1',0);
    hdr2_r := build_hdr2('0','0',0);

    resp_hdr2_w := build_hdr2('1','1',0);
    resp_hdr2_r := build_hdr2('1','0',0);

    ----------------------------------------------------------------------
    -- TG phase: 3 WRITE requests
    ----------------------------------------------------------------------
    for k in 0 to 2 loop
      hdr0 := std_logic_vector(to_unsigned(16#11110000# + k, 32));
      hdr1 := std_logic_vector(to_unsigned(16#22220000# + k, 32));

      if k=0 then payload := p0;
      elsif k=1 then payload := p1;
      else payload := p2;
      end if;

      send_write_req(ACLK, lin_val, lin_data, lin_ack, hdr0, hdr1, hdr2_w, addr, payload, csum);

      -- Expect WRITE response (datapath swaps hdr0/hdr1):
      -- tx_sel="000" => resp_hdr0=req_hdr1, ctrl=1
      -- tx_sel="001" => resp_hdr1=req_hdr0, ctrl=0
      -- tx_sel="010" => resp_hdr2,        ctrl=0
      -- tx_sel="100" => checksum,         ctrl=1
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '1', hdr1,        "WRESP hdr0");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '0', hdr0,        "WRESP hdr1");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '0', resp_hdr2_w, "WRESP hdr2");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '1', csum,        "WRESP csum");
    end loop;

    ----------------------------------------------------------------------
    -- TM phase: 2 READ requests, expect payload == last stored == p2
    ----------------------------------------------------------------------
    for k in 0 to 1 loop
      hdr0 := std_logic_vector(to_unsigned(16#33330000# + k, 32));
      hdr1 := std_logic_vector(to_unsigned(16#44440000# + k, 32));

      send_read_req(ACLK, lin_val, lin_data, lin_ack, hdr0, hdr1, hdr2_r, addr, csum);

      -- Expect READ response: hdr0 hdr1 hdr2 payload checksum
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '1', hdr1,        "RRESP hdr0");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '0', hdr0,        "RRESP hdr1");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '0', resp_hdr2_r, "RRESP hdr2");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '0', p2,          "RRESP payload");
      expect_and_accept_flit(ACLK, lout_val, lout_data, lout_ack, '1', csum,        "RRESP csum");
    end loop;

    report "TB completed OK" severity note;
    wait for 50 ns;
    assert false report "End of simulation" severity failure;
  end process;

end architecture;
