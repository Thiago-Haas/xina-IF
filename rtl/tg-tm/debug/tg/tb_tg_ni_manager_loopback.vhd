library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TB: connect TG (AXI master) directly to NI manager (top_manager)
-- and emulate a simple NoC loopback on the NI NoC-side ports.
--
-- Updated assumptions (per your latest note):
--   Request  (6 flits): hdr0, hdr1, hdr2, addr, payload[0], checksum
--   Response (5 flits): hdr0, hdr1, hdr2, payload[0], checksum
--
-- IMPORTANT (handshake):
-- Keeping lin_ack permanently at '1' can make debugging confusing (and may
-- trigger "missed hdr0" corner-cases on some implementations). This TB pulses
-- lin_ack for exactly one cycle per accepted flit, keeping each flit stable
-- while it is being sampled.
--
-- The TB captures each outgoing request packet into a variable array, then
-- constructs a response by swapping src/dest headers and forcing TYPE=1.

entity tb_tg_ni_manager_loopback is
end entity;

architecture tb of tb_tg_ni_manager_loopback is

  constant c_CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TG control
  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;
  signal input_address : std_logic_vector(63 downto 0) := (others => '0');
  signal starting_seed : std_logic_vector(31 downto 0) := (others => '0');
  signal tg_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- AXI interconnect TG->NI (write only)
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal awlen   : std_logic_vector(7 downto 0);
  signal awburst : std_logic_vector(1 downto 0);
  signal awvalid : std_logic;
  signal awready : std_logic;

  signal wvalid  : std_logic;
  signal wready  : std_logic;
  signal wdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal wlast   : std_logic;

  signal bid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal bvalid : std_logic;
  signal bready : std_logic;

  -- Unused read channels (tie off)
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal arlen   : std_logic_vector(7 downto 0) := (others => '0');
  signal arburst : std_logic_vector(1 downto 0) := "01";

  signal rvalid : std_logic;
  signal rready : std_logic := '0';
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  signal corrupt_packet : std_logic;

  -- NoC side
  signal lin_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic := '0'; -- TB pulses ACK per accepted flit

  signal lout_data : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  signal lout_val  : std_logic := '0';
  signal lout_ack  : std_logic;

  -- flit helpers
  function mk_flit(ctrl : std_logic; w : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH - 1 downto 0) := (others => '0');
  begin
    f(f'left) := ctrl;
    f(31 downto 0) := w;
    return f;
  end function;

  subtype t_flit is std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  constant c_MAX_FLITS : natural := 8;
  type t_pkt is array(0 to c_MAX_FLITS-1) of t_flit;

  -- ctrl bit is MSB (matches existing loopback TBs)
  function flit_ctrl(f : t_flit) return std_logic is
  begin
    return f(f'left);
  end function;

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- TG (AXI master)
    u_dut: entity work.tg_ni_write_only_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start       => tg_start,
      o_done        => tg_done,
      INPUT_ADDRESS => input_address,
      STARTING_SEED => starting_seed,

      l_in_data_o => lin_data,
      l_in_val_o  => lin_val,
      l_in_ack_i  => lin_ack,

      l_out_data_i => lout_data,
      l_out_val_i  => lout_val,
      l_out_ack_o  => lout_ack
    );

  ---------------------------------------------------------------------------
  -- NoC loopback emulator
  ---------------------------------------------------------------------------
  noc_loopback: process
    variable req  : t_pkt;
    variable resp : t_pkt;

    variable req_len  : integer := 0;
    variable resp_len : integer := 0;

    variable resp_word : std_logic_vector(31 downto 0);

    variable pkt_count_req  : integer := 0;
    variable pkt_count_resp : integer := 0;

    -- Accept exactly one outgoing request flit (NI->TB): sample, then pulse lin_ack
    procedure accept_one_req_flit(variable dst : out t_flit) is
    begin
      -- wait until NI presents a flit
      while lin_val /= '1' loop
        wait until rising_edge(ACLK);
      end loop;

      -- let data settle with ACK low (NI should hold stable)
      wait for 1 ns;
      dst := lin_data;

      -- pulse ACK for one cycle to advance the NI to next flit
      lin_ack <= '1';
      wait until rising_edge(ACLK);
      lin_ack <= '0';
      wait until rising_edge(ACLK);
    end procedure;

    -- Send one response flit (TB->NI): hold until NI asserts lout_ack
    procedure send_resp_flit(constant f : in t_flit) is
    begin
      lout_val  <= '1';
      lout_data <= f;
      loop
        wait until rising_edge(ACLK);
        exit when lout_ack = '1';
      end loop;
    end procedure;
  begin
    -- wait for reset deassert
    lout_val  <= '0';
    lout_data <= (others => '0');
    wait until ARESETn = '1';
    wait until rising_edge(ACLK);

    -- Expect 3 request packets from NI (AW/W/B side as generated by TG/NI)
    for pkt in 0 to 2 loop
      ---------------------------------------------------------------------
      -- Capture one full request packet, stopping on checksum flit.
      -- Packet delimiter convention: ctrl='1' on hdr0 and on checksum.
      ---------------------------------------------------------------------
      req_len := 0;

      -- hdr0 must be ctrl='1'
      accept_one_req_flit(req(0));
      assert flit_ctrl(req(0)) = '1'
        report "Expected ctrl=1 on hdr0" severity failure;
      req_len := 1;

      -- capture until checksum (ctrl='1')
      while req_len < integer(c_MAX_FLITS) loop
        accept_one_req_flit(req(req_len));
        req_len := req_len + 1;
        exit when flit_ctrl(req(req_len-1)) = '1';
      end loop;

      assert req_len = 6
        report "Expected 6-flit request (hdr0,hdr1,hdr2,addr,payload0,csum) but got " & integer'image(req_len)
        severity failure;
      pkt_count_req := pkt_count_req + 1;

      -- Build 5-flit response:
      --   resp hdr0 <= req hdr1 word (swap src/dest)
      --   resp hdr1 <= req hdr0 word
      --   resp hdr2 <= req hdr2 word with TYPE bit forced to '1'
      --   payload[0] <= echo request payload[0]
      --   checksum <= (for now) echo request checksum

      -- hdr0 (ctrl=1)
      resp_word := req(1)(31 downto 0);
      resp(0) := mk_flit('1', resp_word);

      -- hdr1
      resp_word := req(0)(31 downto 0);
      resp(1) := mk_flit('0', resp_word);

      -- hdr2 (force TYPE=1 at bit0; keep rest)
      resp_word := req(2)(31 downto 0);
      resp_word(0) := '1';
      resp(2) := mk_flit('0', resp_word);

      -- payload[0]
      resp_word := req(4)(31 downto 0);
      resp(3) := mk_flit('0', resp_word);

      -- checksum (ctrl=1)
      resp_word := req(5)(31 downto 0);
      resp(4) := mk_flit('1', resp_word);

      resp_len := 5;

      -- send response flits with handshake
      for k in 0 to resp_len-1 loop
        send_resp_flit(resp(k));
      end loop;
      lout_val  <= '0';
      lout_data <= (others => '0');
      wait until rising_edge(ACLK);

      pkt_count_resp := pkt_count_resp + 1;
    end loop;

    -- simple sanity checks (packet counts)
    assert pkt_count_req = 3
      report "Expected 3 request packets, got " & integer'image(pkt_count_req)
      severity failure;

    assert pkt_count_resp = 3
      report "Expected 3 response packets, got " & integer'image(pkt_count_resp)
      severity failure;

    wait;
  end process;

  ---------------------------------------------------------------------------
  -- Stimulus / end conditions
  ---------------------------------------------------------------------------
  stim: process
  begin
    -- defaults
    tg_start      <= '0';
    input_address <= x"0000_0000_0000_0100";
    starting_seed <= x"1ACE_B00C";

    -- reset
    ARESETn <= '0';
    wait for 100 ns;
    wait until rising_edge(ACLK);
    ARESETn <= '1';

    -- start TG
    wait until rising_edge(ACLK);
    tg_start <= '1';
    wait until rising_edge(ACLK);
    tg_start <= '0';

    -- wait for completion
    while tg_done /= '1' loop
      wait until rising_edge(ACLK);
    end loop;

    report "TB completed OK" severity note;
    wait for 50 ns;
    assert false report "End of simulation" severity failure;
  end process;

end architecture;
