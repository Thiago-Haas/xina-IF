library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Aggressive resource-minimized write datapath:
--  * NO external override ports
--  * NO init-value generic / no helper functions
--  * AW fields are constants (single-beat INCR burst)
--  * ONE data register (r_wdata) acts as both WDATA output and LFSR state
--  * Seed is inserted into LSBs of an all-zero init word
entity tg_write_datapath is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- from controller
    i_txn_start_pulse : in std_logic;
    i_wbeat_pulse     : in std_logic;

    -- AXI constant fields (write address)
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);

    -- write data
    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic
  );
end tg_write_datapath;

architecture rtl of tg_write_datapath is
  signal r_wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal r_seeded : std_logic := '0';

  signal w_init_value : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_input : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_next  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal w_do_init : std_logic;
  signal w_do_step : std_logic;
begin
  -- Constant fields
  AWADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  AWID    <= (others => '0');
  AWLEN   <= x"00";      -- 1 beat
  AWBURST <= "01";      -- INCR

  -- Single beat
  WLAST <= '1';

  -- Payload comes from the state register
  WDATA <= r_wdata;

  -- Seed only once after reset, on first transaction start
  w_do_init <= i_txn_start_pulse and (not r_seeded);
  w_do_step <= i_wbeat_pulse;

  -- Init value = all zeros, with seed in low bits
  process(all)
    variable v : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  begin
    v := (others => '0');
    if c_AXI_DATA_WIDTH >= 32 then
      v(31 downto 0) := STARTING_SEED;
    else
      v(c_AXI_DATA_WIDTH-1 downto 0) := STARTING_SEED(c_AXI_DATA_WIDTH-1 downto 0);
    end if;
    w_init_value <= v;
  end process;

  -- Feed init value only when initializing; otherwise feed the current state.
  w_lfsr_input <= w_init_value when (w_do_init = '1') else r_wdata;

  u_LFSR: entity work.tg_write_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      i_data => w_lfsr_input,
      o_next => w_lfsr_next
    );

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_seeded <= '0';
        r_wdata  <= (others => '0');
      else
        if w_do_init = '1' then
          r_seeded <= '1';
          r_wdata  <= w_lfsr_next;  -- first WDATA = next(init)
        elsif w_do_step = '1' then
          r_wdata  <= w_lfsr_next;  -- advance once per accepted beat
        end if;
      end if;
    end if;
  end process;

end rtl;
