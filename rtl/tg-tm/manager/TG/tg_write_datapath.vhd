library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Write-phase datapath (resource-minimized, lock-step with TM):
--  * ONE register AFTER the LFSR (r_wdata) => WDATA output AND LFSR state
--  * Optional 1-bit r_seeded to match TM behaviour (seed only once after reset)
--  * First word after init is precomputed as next_lfsr(init_value)
--  * Each accepted W beat advances: r_wdata <= next_lfsr(r_wdata)
--
-- This matches TM behaviour where the first expected RDATA beat is next_lfsr(init_value)
-- and subsequent beats advance from the previous expected value.
entity tg_write_datapath is
  generic(
    p_AWID      : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
    p_LEN       : std_logic_vector(7 downto 0) := x"00";
    p_BURST     : std_logic_vector(1 downto 0) := "01";
    p_INIT_VALUE: std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0')
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- from controller
    i_txn_start_pulse : in std_logic;
    i_wbeat_pulse     : in std_logic;

    -- optional external override (CONTROL only; default off)
    -- When enabled, feedback uses i_ext_data_in instead of WDATA.
    i_ext_update_en : in std_logic := '0';
    i_ext_data_in   : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

    -- AXI constant fields (write address)
    AWID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : out std_logic_vector(7 downto 0);
    AWBURST : out std_logic_vector(1 downto 0);

    -- write data
    WDATA   : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST   : out std_logic;

    -- debug (exposes ONLY the post-LFSR reg = WDATA)
    o_lfsr_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end tg_write_datapath;

architecture rtl of tg_write_datapath is
  signal r_wdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal r_seeded : std_logic := '0';

  signal w_init_value   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_feedback_val : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_input   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal w_lfsr_next    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal w_do_init : std_logic;
  signal w_do_step : std_logic;

  function apply_seed(base : std_logic_vector; seed : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable v : std_logic_vector(base'range) := base;
    constant W : integer := base'length;
    variable N : integer;
  begin
    if W >= 32 then
      N := 32;
    else
      N := W;
    end if;

    -- overwrite the least-significant bits with the seed
    for i in 0 to N-1 loop
      v(i) := seed(i);
    end loop;
    return v;
  end function;

begin
  -- Constant fields
  AWADDR  <= INPUT_ADDRESS(c_AXI_ADDR_WIDTH - 1 downto 0);
  AWID    <= p_AWID;
  AWLEN   <= p_LEN;
  AWBURST <= p_BURST;

  -- Single beat
  WLAST <= '1';

  -- Payload comes from the post-LFSR register
  WDATA        <= r_wdata;
  o_lfsr_value <= r_wdata;

  -- Build init value = base/random generic + seed in lower bits
  w_init_value <= apply_seed(p_INIT_VALUE, STARTING_SEED);

  -- Feedback value (CONTROL override optional)
  w_feedback_val <= i_ext_data_in when (i_ext_update_en = '1') else r_wdata;

  -- Match TM: seed only once after reset, on first transaction start
  w_do_init <= i_txn_start_pulse and (not r_seeded);
  w_do_step <= i_wbeat_pulse;

  -- LFSR input:
  --  * init: feed init value, compute first WDATA = next(init)
  --  * step: feed previous sent/expected value (r_wdata) and advance
  w_lfsr_input <= w_init_value   when (w_do_init = '1') else
                  w_feedback_val when (w_do_step = '1') else
                  r_wdata;

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
          r_wdata  <= w_lfsr_next;  -- precompute first WDATA = next(init)
        elsif w_do_step = '1' then
          r_wdata  <= w_lfsr_next;  -- advance once per accepted beat
        end if;
      end if;
    end if;
  end process;

end rtl;
