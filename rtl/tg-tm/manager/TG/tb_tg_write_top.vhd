library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Simple TB for tg_write_top only (AXI write channels).
-- Generates 5 write transactions and prints the observed WDATA (LFSR progression).
--
-- This TB implements a minimal AXI-lite-ish slave behavior:
--  - Always-ready for AW/W (with optional small stalls).
--  - Responds with BVALID after seeing the W beat.
--
entity tb_tg_write_top is
end entity;

architecture tb of tb_tg_write_top is
  -- Clocking
  constant c_CLK_PERIOD : time := 10 ns;

  signal ACLK    : std_logic := '0';
  signal ARESETn : std_logic := '0';

  -- TG control
  signal i_start : std_logic := '0';
  signal o_done  : std_logic;

  signal INPUT_ADDRESS : std_logic_vector(63 downto 0) := (others => '0');
  signal STARTING_SEED : std_logic_vector(31 downto 0) := (others => '0');

  signal i_ext_update_en : std_logic := '0';
  signal i_ext_data_in   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  -- AXI write address channel
  signal AWID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal AWADDR  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal AWLEN   : std_logic_vector(7 downto 0);
  signal AWBURST : std_logic_vector(1 downto 0);
  signal AWVALID : std_logic;
  signal AWREADY : std_logic := '0';

  -- AXI write data channel
  signal WVALID : std_logic;
  signal WREADY : std_logic := '0';
  signal WDATA  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal WLAST  : std_logic;

  -- AXI write response channel
  signal BID    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal BRESP  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
  signal BVALID : std_logic := '0';
  signal BREADY : std_logic;

  -- debug
  signal o_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  -- Slave-side bookkeeping
  signal saw_aw : std_logic := '0';
  signal saw_w  : std_logic := '0';
  signal lat_awid : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal lat_wdata: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  -- transaction counter for printing
  signal txn_idx : integer := 0;

  procedure p_wait_cycles(n : natural) is
  begin
    for i in 1 to n loop
      wait until rising_edge(ACLK);
    end loop;
  end procedure;

begin
  -- Pull in packages for widths
  -- (TG already depends on them; TB uses them for signal sizes.)
  -- Note: refer via "work.xina_ft_pkg.c_AXI_*" above.

  -- Clock generator
  p_clk : process
  begin
    while true loop
      ACLK <= '0'; wait for c_CLK_PERIOD/2;
      ACLK <= '1'; wait for c_CLK_PERIOD/2;
    end loop;
  end process;

  -- DUT
  dut : entity work.tg_write_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start,
      o_done  => o_done,

      INPUT_ADDRESS => INPUT_ADDRESS,
      STARTING_SEED => STARTING_SEED,

      i_ext_update_en => i_ext_update_en,
      i_ext_data_in   => i_ext_data_in,

      AWID    => AWID,
      AWADDR  => AWADDR,
      AWLEN   => AWLEN,
      AWBURST => AWBURST,
      AWVALID => AWVALID,
      AWREADY => AWREADY,

      WVALID  => WVALID,
      WREADY  => WREADY,
      WDATA   => WDATA,
      WLAST   => WLAST,

      BID    => BID,
      BRESP  => BRESP,
      BVALID => BVALID,
      BREADY => BREADY,

      o_lfsr_value => o_lfsr_value
    );

  ---------------------------------------------------------------------------
  -- Minimal AXI slave model (write-only)
  ---------------------------------------------------------------------------
  p_axi_slave : process(ACLK)
    variable l : line;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        AWREADY <= '0';
        WREADY  <= '0';
        BVALID  <= '0';
        BID     <= (others => '0');
        BRESP   <= (others => '0');
        saw_aw  <= '0';
        saw_w   <= '0';
      else
        -- Keep ready high (simple). You can add small stalls if desired.
        AWREADY <= '1';
        WREADY  <= '1';

        -- Address handshake
        if (AWVALID = '1' and AWREADY = '1') then
          saw_aw  <= '1';
          lat_awid <= AWID;
          -- (Optional) could check AWLEN/AWBURST here
        end if;

        -- Data handshake
        if (WVALID = '1' and WREADY = '1') then
          saw_w    <= '1';
          lat_wdata <= WDATA;

          -- Simple assertion: single beat
          assert WLAST = '1'
            report "Expected single-beat write (WLAST='1') but got WLAST='0'"
            severity warning;
        end if;

        -- Generate response once we saw the data beat (TG FSM is AW->W->B so this is enough)
        if (BVALID = '0') then
          if (saw_aw = '1' and saw_w = '1') then
            BVALID <= '1';
            BID    <= lat_awid;
            BRESP  <= (others => '0'); -- OKAY
          end if;
        else
          -- Complete response when TG accepts it
          if (BREADY = '1') then
            BVALID <= '0';
            saw_aw <= '0';
            saw_w  <= '0';

            -- Print what was written (this is the LFSR/WDATA interaction you care about)
            write(l, string'("AXI WRITE tx="));
            write(l, txn_idx);
            write(l, string'("  AWADDR=0x"));
            hwrite(l, AWADDR);
            write(l, string'("  WDATA=0x"));
            hwrite(l, lat_wdata);
            write(l, string'("  dbg(o_lfsr_value)=0x"));
            hwrite(l, o_lfsr_value);
            writeline(output, l);

            txn_idx <= txn_idx + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Test sequence: 5 transactions
  ---------------------------------------------------------------------------
  p_stim : process
  begin
    -- defaults
    INPUT_ADDRESS <= x"0000000000001000";
    STARTING_SEED <= "01010101010101010101010101010101";

    -- optional external injection for FIRST transaction only
    i_ext_data_in   <= (others => '0');
    i_ext_data_in(31 downto 0) <= x"A5A5_1234";

    -- Reset
    ARESETn <= '0';
    i_start <= '0';
    p_wait_cycles(5);
    ARESETn <= '1';
    p_wait_cycles(2);

    -- Run 5 single write transactions
    for k in 0 to 4 loop
      -- Apply external override only for first transaction (1-cycle pulse)
      if k = 0 then
        i_ext_update_en <= '1';
      else
        i_ext_update_en <= '0';
      end if;

      -- Start pulse (1 cycle)
      i_start <= '1';
      wait until rising_edge(ACLK);
      i_start <= '0';
      i_ext_update_en <= '0'; -- ensure one-shot from TB side

      -- Wait for done pulse (should occur after B handshake)
      wait until rising_edge(ACLK);
      while o_done /= '1' loop
        wait until rising_edge(ACLK);
      end loop;

      -- Small gap between packets (you can increase)
      p_wait_cycles(3);
    end loop;

    report "TB finished after 5 transactions." severity note;
    wait;
  end process;

end architecture;
