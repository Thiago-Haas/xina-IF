library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library std;
use std.env.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

entity tb_tg_tm_lb_top is
end entity;

architecture tb of tb_tg_tm_lb_top is

  constant c_CLK_PERIOD : time := 10 ns;

  -- number of iterations
  constant c_NUM_ITERS : natural := 200;

  -- step between base addresses (bytes) each iter
  constant c_ADDR_STEP : unsigned(63 downto 0) := to_unsigned(16, 64); -- 0x10

  constant c_BASE_ADDR_INIT : std_logic_vector(63 downto 0) := x"00000000_00000100";
  constant c_SEED_INIT      : std_logic_vector(31 downto 0) := x"1ACEB00C";

  -- ==========================
  -- MISMATCH INJECTION SETTINGS
  -- ==========================
  constant c_ENABLE_MISMATCH_INJECT : boolean  := true;
  constant c_MISMATCH_EVERY         : positive := 5;   -- inject every N iterations (1 R beat each)
  constant c_INJECT_BIT             : natural  := 0;   -- flip this bit of RDATA

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  signal tg_start : std_logic := '0';
  signal tg_done  : std_logic;

  signal tm_start : std_logic := '0';
  signal tm_done  : std_logic;

  signal tg_addr  : std_logic_vector(63 downto 0) := c_BASE_ADDR_INIT;
  signal tm_addr  : std_logic_vector(63 downto 0) := c_BASE_ADDR_INIT;

  signal tg_seed  : std_logic_vector(31 downto 0) := c_SEED_INIT;
  signal tm_seed  : std_logic_vector(31 downto 0) := c_SEED_INIT;

  signal tm_mismatch : std_logic;
  signal tm_expected : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

  -- ===================
  -- AXI write (TG -> NI)
  -- ===================
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

  -- ==================
  -- AXI read (NI -> TM)
  -- ==================
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen   : std_logic_vector(7 downto 0);
  signal arburst : std_logic_vector(1 downto 0);
  signal arvalid : std_logic;
  signal arready : std_logic;

  signal rvalid     : std_logic;
  signal rready     : std_logic;
  signal rdata_raw  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rdata_inj  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast      : std_logic;
  signal rid        : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp      : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- ==========================
  -- NI <-> Loopback NoC signals
  -- ==========================
  signal lin_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic;

  signal lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lout_val  : std_logic;
  signal lout_ack  : std_logic;

  -- ==========================
  -- Fault-injection control
  -- ==========================
  signal inj_enable_iter : std_logic := '0';
  signal inject_now      : std_logic := '0';

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

begin

  -- clock
  ACLK <= not ACLK after c_CLK_PERIOD/2;

  -- TG
  u_tg: entity work.tg_write_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => tg_start,
      o_done  => tg_done,

      INPUT_ADDRESS => tg_addr,
      STARTING_SEED => tg_seed,

      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,
      AWVALID => awvalid,
      AWREADY => awready,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BID     => bid,
      BRESP   => bresp,
      BVALID  => bvalid,
      BREADY  => bready
    );

  -- TM (consume injected RDATA)
  u_tm: entity work.tm_read_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => tm_start,
      o_done  => tm_done,

      INPUT_ADDRESS => tm_addr,
      STARTING_SEED => tm_seed,

      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,
      ARVALID => arvalid,
      ARREADY => arready,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata_inj,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      o_mismatch       => tm_mismatch,
      o_expected_value => tm_expected
    );

  -- NI manager
  u_ni: entity work.top_manager
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write
      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BVALID  => bvalid,
      BREADY  => bready,
      BID     => bid,
      BRESP   => bresp,

      -- Read
      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata_raw,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      -- NoC-side ports
      l_in_data_i  => lin_data,
      l_in_val_i   => lin_val,
      l_in_ack_o   => lin_ack,

      l_out_data_o => lout_data,
      l_out_val_o  => lout_val,
      l_out_ack_i  => lout_ack,

      corrupt_packet => open
    );

  -- Loopback
  u_lb: entity work.lb_top
    generic map(
      p_MEM_ADDR_BITS => 10
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_data_i => lin_data,
      lin_val_i  => lin_val,
      lin_ack_o  => lin_ack,

      lout_data_o => lout_data,
      lout_val_o  => lout_val,
      lout_ack_i  => lout_ack
    );

  -- Fault injection (every N iterations): inject on accepted R beat
  inject_now <= '1' when (c_ENABLE_MISMATCH_INJECT and (inj_enable_iter = '1') and (rvalid = '1') and (rready = '1'))
               else '0';

  p_rdata_inject : process(rdata_raw, inject_now)
    variable v : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  begin
    v := rdata_raw;
    if inject_now = '1' then
      if c_INJECT_BIT < c_AXI_DATA_WIDTH then
        v(c_INJECT_BIT) := not v(c_INJECT_BIT);
      end if;
    end if;
    rdata_inj <= v;
  end process;

  -- reset + stimulus
  stim: process
    variable base_addr : unsigned(63 downto 0);
    variable seed      : unsigned(31 downto 0);
    variable exp_fault : boolean;
    variable inj_chr   : string(1 to 1);
    variable mism_cnt  : natural := 0;
    variable unexp_cnt : natural := 0;
  begin
    ARESETn <= '0';
    tg_start <= '0';
    tm_start <= '0';
    inj_enable_iter <= '0';
    wait for 50 ns;
    ARESETn <= '1';
    wait for 50 ns;

    base_addr := unsigned(c_BASE_ADDR_INIT);
    seed      := unsigned(c_SEED_INIT);

    for it in 0 to integer(c_NUM_ITERS-1) loop
      tg_addr <= std_logic_vector(base_addr);
      tm_addr <= std_logic_vector(base_addr);

      tg_seed <= std_logic_vector(seed);
      tm_seed <= std_logic_vector(seed);

      -- decide if this iteration should inject (it=4,9,14,...)
      exp_fault := (c_ENABLE_MISMATCH_INJECT and ((it mod integer(c_MISMATCH_EVERY)) = integer(c_MISMATCH_EVERY-1)));
      if exp_fault then
        inj_enable_iter <= '1';
        inj_chr := "1";
      else
        inj_enable_iter <= '0';
        inj_chr := "0";
      end if;

      report "=== ITER " & integer'image(it) &
             " START: addr=0x" & hex32(std_logic_vector(base_addr(31 downto 0))) &
             " seed=0x" & hex32(std_logic_vector(seed)) &
             " inj=" & inj_chr & " ==="
             severity note;

      -- TG
      tg_start <= '1';
      wait until rising_edge(ACLK);
      tg_start <= '0';
      wait until tg_done = '1';

      -- TM
      tm_start <= '1';
      wait until rising_edge(ACLK);
      tm_start <= '0';
      wait until tm_done = '1';

      report "=== ITER " & integer'image(it) &
             " DONE. mismatch=" & std_logic'image(tm_mismatch) severity note;

      if tm_mismatch = '1' then
        mism_cnt := mism_cnt + 1;
        if exp_fault then
          report "ITER " & integer'image(it) &
                 " mismatch observed (expected). expected=" & hex32(tm_expected(31 downto 0)) severity warning;
        else
          unexp_cnt := unexp_cnt + 1;
          report "ITER " & integer'image(it) &
                 " mismatch observed (UNEXPECTED!). expected=" & hex32(tm_expected(31 downto 0)) severity error;
        end if;
      else
        if exp_fault then
          unexp_cnt := unexp_cnt + 1;
          report "ITER " & integer'image(it) &
                 " NO mismatch but injection was enabled (UNEXPECTED!)" severity error;
        end if;
      end if;

      base_addr := base_addr + c_ADDR_STEP;
      seed      := seed + 1;
      wait for 20 ns;
    end loop;

    report "=== DONE. iters=" & integer'image(integer(c_NUM_ITERS)) &
           " mismatches=" & integer'image(integer(mism_cnt)) &
           " unexpected=" & integer'image(integer(unexp_cnt)) & " ==="
           severity note;

    std.env.stop;
    wait;
  end process;

end architecture;