library IEEE;
use IEEE.std_logic_1164.all;

entity tg_manager_controller is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- Handshake inputs (from AXI)
    AWREADY : in  std_logic;
    WREADY  : in  std_logic;
    BVALID  : in  std_logic;
    ARREADY : in  std_logic;
    RVALID  : in  std_logic;
    RLAST   : in  std_logic;

    -- AXI control outputs (to AXI)
    AWVALID : out std_logic;
    WVALID  : out std_logic;
    BREADY  : out std_logic;
    ARVALID : out std_logic;
    RREADY  : out std_logic;

    -- Enables to datapath/LFSR
    o_load_wdata     : out std_logic; -- pulse when moving AW->W
    o_capture_rdata  : out std_logic; -- pulse on read completion
    o_update_lfsr    : out std_logic  -- pulse on read completion (same as capture)
  );
end entity;

architecture rtl of tg_manager_controller is
  type t_state is (s0_AW, s1_W, s2_B, s3_AR, s4_R);
  signal r_state : t_state := s0_AW;

  signal awvalid_i, wvalid_i, bready_i, arvalid_i, rready_i : std_logic;

  signal aw_hs  : std_logic;
  signal w_hs   : std_logic;
  signal b_hs   : std_logic;
  signal ar_hs  : std_logic;
  signal r_hs   : std_logic;
  signal r_done : std_logic;
begin

  -- Control outputs from state
  awvalid_i <= '1' when (r_state = s0_AW) else '0';
  wvalid_i  <= '1' when (r_state = s1_W)  else '0';
  bready_i  <= '1' when (r_state = s2_B)  else '0';
  arvalid_i <= '1' when (r_state = s3_AR) else '0';
  rready_i  <= '1' when (r_state = s4_R)  else '0';

  AWVALID <= awvalid_i;
  WVALID  <= wvalid_i;
  BREADY  <= bready_i;
  ARVALID <= arvalid_i;
  RREADY  <= rready_i;

  -- Handshakes
  aw_hs  <= awvalid_i and AWREADY;
  w_hs   <= wvalid_i  and WREADY;
  b_hs   <= BVALID    and bready_i;
  ar_hs  <= arvalid_i and ARREADY;
  r_hs   <= RVALID    and rready_i;
  r_done <= r_hs and RLAST;

  -- Enables (pulses)
  o_load_wdata    <= aw_hs;    -- load payload when AW accepted
  o_capture_rdata <= r_done;   -- capture on final read beat
  o_update_lfsr   <= r_done;   -- advance LFSR on final read beat

  -- FSM transitions (exactly like the figure)
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_state <= s0_AW;
      else
        case r_state is
          when s0_AW =>
            if aw_hs = '1' then r_state <= s1_W; end if;

          when s1_W =>
            if w_hs = '1' then r_state <= s2_B; end if;

          when s2_B =>
            if b_hs = '1' then r_state <= s3_AR; end if;

          when s3_AR =>
            if ar_hs = '1' then r_state <= s4_R; end if;

          when s4_R =>
            if r_done = '1' then r_state <= s0_AW; end if;
        end case;
      end if;
    end if;
  end process;

end rtl;