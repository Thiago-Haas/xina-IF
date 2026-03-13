library IEEE;
use IEEE.std_logic_1164.all;

-- TMR wrapper for traffic_gen_control.
--
-- Follows the same philosophy used in control_tmr.vhd:
--   * 3 replicated controllers
--   * majority vote on every output
--   * error_o asserts when any replica disagrees
--   * when correct_error_i='1', output is the voted value; otherwise replica 0 is passed through

entity traffic_gen_control_tmr is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    start_i : in  std_logic := '1';
    done_o  : out std_logic;

    -- Handshake inputs (from AXI slave)
    AWREADY : in  std_logic;
    WREADY  : in  std_logic;
    BVALID  : in  std_logic;

    -- AXI control outputs (to AXI slave)
    AWVALID : out std_logic;
    WVALID  : out std_logic;
    BREADY  : out std_logic;

    -- datapath control
    seed_pulse_o      : out std_logic;
    wbeat_pulse_o     : out std_logic;

    -- hardening
    correct_enable_i: in  std_logic;
    error_o         : out std_logic
  );
end entity;

architecture rtl of traffic_gen_control_tmr is
  attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal done_w            : tmr_sl_t;
  signal awvalid_w         : tmr_sl_t;
  signal wvalid_w          : tmr_sl_t;
  signal bready_w          : tmr_sl_t;
  signal seed_pulse_w      : tmr_sl_t;
  signal wbeat_pulse_w     : tmr_sl_t;

  signal corr_done_w            : std_logic;
  signal corr_awvalid_w         : std_logic;
  signal corr_wvalid_w          : std_logic;
  signal corr_bready_w          : std_logic;
  signal corr_seed_pulse_w      : std_logic;
  signal corr_wbeat_pulse_w     : std_logic;

  signal err_done_w            : std_logic;
  signal err_awvalid_w         : std_logic;
  signal err_wvalid_w          : std_logic;
  signal err_bready_w          : std_logic;
  signal err_seed_pulse_w      : std_logic;
  signal err_wbeat_pulse_w     : std_logic;

  -- majority vote helper (for single-bit signals)
  function maj3(a, b, c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  -- disagreement detector helper
  function dis3(a, b, c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;

begin

  -- 3 replicated controllers
  gen_ctrl : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_CTRL : label is "TRUE";
        attribute syn_preserve of u_CTRL : label is true;
    attribute KEEP_HIERARCHY of u_CTRL : label is "TRUE";
  begin
    u_CTRL : entity work.traffic_gen_control
      port map (
        ACLK    => ACLK,
        ARESETn => ARESETn,

        start_i => start_i,
        done_o  => done_w(i),

        AWREADY => AWREADY,
        WREADY  => WREADY,
        BVALID  => BVALID,

        AWVALID => awvalid_w(i),
        WVALID  => wvalid_w(i),
        BREADY  => bready_w(i),

        seed_pulse_o      => seed_pulse_w(i),
        wbeat_pulse_o     => wbeat_pulse_w(i)
      );
  end generate;

  -- majority vote for each output
  corr_done_w            <= maj3(done_w(2),            done_w(1),            done_w(0));
  corr_awvalid_w         <= maj3(awvalid_w(2),         awvalid_w(1),         awvalid_w(0));
  corr_wvalid_w          <= maj3(wvalid_w(2),          wvalid_w(1),          wvalid_w(0));
  corr_bready_w          <= maj3(bready_w(2),          bready_w(1),          bready_w(0));
  corr_seed_pulse_w      <= maj3(seed_pulse_w(2),      seed_pulse_w(1),      seed_pulse_w(0));
  corr_wbeat_pulse_w     <= maj3(wbeat_pulse_w(2),     wbeat_pulse_w(1),     wbeat_pulse_w(0));

  -- disagreement detect
  err_done_w            <= dis3(done_w(2),            done_w(1),            done_w(0));
  err_awvalid_w         <= dis3(awvalid_w(2),         awvalid_w(1),         awvalid_w(0));
  err_wvalid_w          <= dis3(wvalid_w(2),          wvalid_w(1),          wvalid_w(0));
  err_bready_w          <= dis3(bready_w(2),          bready_w(1),          bready_w(0));
  err_seed_pulse_w      <= dis3(seed_pulse_w(2),      seed_pulse_w(1),      seed_pulse_w(0));
  err_wbeat_pulse_w     <= dis3(wbeat_pulse_w(2),     wbeat_pulse_w(1),     wbeat_pulse_w(0));

  error_o <= err_done_w or err_awvalid_w or err_wvalid_w or err_bready_w or
             err_seed_pulse_w or err_wbeat_pulse_w;

  -- output selection
  done_o            <= corr_done_w            when correct_enable_i = '1' else done_w(0);
  AWVALID           <= corr_awvalid_w         when correct_enable_i = '1' else awvalid_w(0);
  WVALID            <= corr_wvalid_w          when correct_enable_i = '1' else wvalid_w(0);
  BREADY            <= corr_bready_w          when correct_enable_i = '1' else bready_w(0);
  seed_pulse_o      <= corr_seed_pulse_w      when correct_enable_i = '1' else seed_pulse_w(0);
  wbeat_pulse_o     <= corr_wbeat_pulse_w     when correct_enable_i = '1' else wbeat_pulse_w(0);

end architecture;
