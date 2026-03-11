library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

-- TMR wrapper for tm_read_controller.
--
-- Same philosophy as control_tmr.vhd / tg_write_controller_tmr.vhd:
--   * 3 replicated controllers
--   * majority vote on every output
--   * error_o asserts when any replica disagrees
--   * when i_correct_enable='1', output is the voted value; otherwise replica 0 is passed through

entity tm_read_controller_tmr is
  generic(
    p_USE_TMR_INJECT_ERROR : boolean := c_ENABLE_TM_CTRL_TMR_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic := '1';

    -- sequencing
    i_start : in  std_logic := '1';
    o_done  : out std_logic;

    -- Handshake inputs (from AXI slave)
    ARREADY : in  std_logic;
    RVALID  : in  std_logic;
    RLAST   : in  std_logic;

    -- AXI control outputs (to AXI slave)
    ARVALID : out std_logic;
    RREADY  : out std_logic;

    -- datapath control
    o_rbeat_hs_comb   : out std_logic;
    o_seed_pulse      : out std_logic;

    -- hardening
    i_correct_enable : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of tm_read_controller_tmr is

  type tmr_sl_t is array (2 downto 0) of std_logic;

  signal done_w            : tmr_sl_t;
  signal arvalid_w         : tmr_sl_t;
  signal rready_w          : tmr_sl_t;
  signal rbeat_hs_comb_w   : tmr_sl_t;
  signal seed_pulse_w      : tmr_sl_t;
  signal done_vote_w          : tmr_sl_t;
  signal arvalid_vote_w       : tmr_sl_t;
  signal rready_vote_w        : tmr_sl_t;
  signal rbeat_hs_comb_vote_w : tmr_sl_t;
  signal seed_pulse_vote_w    : tmr_sl_t;
  signal inj_fire_w           : std_logic := '0';

  signal corr_done_w            : std_logic;
  signal corr_arvalid_w         : std_logic;
  signal corr_rready_w          : std_logic;
  signal corr_rbeat_hs_comb_w   : std_logic;
  signal corr_seed_pulse_w      : std_logic;

  signal err_done_w            : std_logic;
  signal err_arvalid_w         : std_logic;
  signal err_rready_w          : std_logic;
  signal err_rbeat_hs_comb_w   : std_logic;
  signal err_seed_pulse_w      : std_logic;

  function maj3(a, b, c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  function dis3(a, b, c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;

begin

  gen_no_inject : if (not p_USE_TMR_INJECT_ERROR) generate
  begin
    inj_fire_w <= '0';
    done_vote_w          <= done_w;
    arvalid_vote_w       <= arvalid_w;
    rready_vote_w        <= rready_w;
    rbeat_hs_comb_vote_w <= rbeat_hs_comb_w;
    seed_pulse_vote_w    <= seed_pulse_w;
  end generate;

  gen_inject : if p_USE_TMR_INJECT_ERROR generate
    signal inj_counter_r : std_logic_vector(15 downto 0) := (others => '0');
  begin
    p_inj_counter : process(ACLK, ARESETn)
    begin
      if ARESETn = '0' then
        inj_counter_r <= (others => '0');
      elsif rising_edge(ACLK) then
        if i_start = '1' then
          if inj_counter_r(inj_counter_r'high) = '0' then
            inj_counter_r <= std_logic_vector(unsigned(inj_counter_r) + 1);
          end if;
        end if;
      end if;
    end process;

    inj_fire_w <= '1' when inj_counter_r = ("00" & (inj_counter_r'length-3 downto 0 => '1')) else '0';

    done_vote_w(2)          <= done_w(2);
    done_vote_w(1)          <= done_w(1);
    done_vote_w(0)          <= not done_w(0) when inj_fire_w = '1' else done_w(0);
    arvalid_vote_w(2)       <= arvalid_w(2);
    arvalid_vote_w(1)       <= arvalid_w(1);
    arvalid_vote_w(0)       <= not arvalid_w(0) when inj_fire_w = '1' else arvalid_w(0);
    rready_vote_w(2)        <= rready_w(2);
    rready_vote_w(1)        <= rready_w(1);
    rready_vote_w(0)        <= not rready_w(0) when inj_fire_w = '1' else rready_w(0);
    rbeat_hs_comb_vote_w(2) <= rbeat_hs_comb_w(2);
    rbeat_hs_comb_vote_w(1) <= rbeat_hs_comb_w(1);
    rbeat_hs_comb_vote_w(0) <= not rbeat_hs_comb_w(0) when inj_fire_w = '1' else rbeat_hs_comb_w(0);
    seed_pulse_vote_w(2)    <= seed_pulse_w(2);
    seed_pulse_vote_w(1)    <= seed_pulse_w(1);
    seed_pulse_vote_w(0)    <= not seed_pulse_w(0) when inj_fire_w = '1' else seed_pulse_w(0);
  end generate;

  gen_ctrl : for i in 0 to 2 generate
    u_CTRL : entity work.tm_read_controller
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_start => i_start,
        o_done  => done_w(i),

        ARREADY => ARREADY,
        RVALID  => RVALID,
        RLAST   => RLAST,

        ARVALID => arvalid_w(i),
        RREADY  => rready_w(i),

        o_rbeat_hs_comb   => rbeat_hs_comb_w(i),
        o_seed_pulse      => seed_pulse_w(i)
      );
  end generate;

  -- majority vote
  corr_done_w            <= maj3(done_vote_w(2),            done_vote_w(1),            done_vote_w(0));
  corr_arvalid_w         <= maj3(arvalid_vote_w(2),         arvalid_vote_w(1),         arvalid_vote_w(0));
  corr_rready_w          <= maj3(rready_vote_w(2),          rready_vote_w(1),          rready_vote_w(0));
  corr_rbeat_hs_comb_w   <= maj3(rbeat_hs_comb_vote_w(2),   rbeat_hs_comb_vote_w(1),   rbeat_hs_comb_vote_w(0));
  corr_seed_pulse_w      <= maj3(seed_pulse_vote_w(2),      seed_pulse_vote_w(1),      seed_pulse_vote_w(0));

  -- disagreement detect
  err_done_w            <= dis3(done_vote_w(2),            done_vote_w(1),            done_vote_w(0));
  err_arvalid_w         <= dis3(arvalid_vote_w(2),         arvalid_vote_w(1),         arvalid_vote_w(0));
  err_rready_w          <= dis3(rready_vote_w(2),          rready_vote_w(1),          rready_vote_w(0));
  err_rbeat_hs_comb_w   <= dis3(rbeat_hs_comb_vote_w(2),   rbeat_hs_comb_vote_w(1),   rbeat_hs_comb_vote_w(0));
  err_seed_pulse_w      <= dis3(seed_pulse_vote_w(2),      seed_pulse_vote_w(1),      seed_pulse_vote_w(0));

  error_o <= err_done_w or err_arvalid_w or err_rready_w or err_rbeat_hs_comb_w or err_seed_pulse_w;

  -- output selection
  o_done            <= corr_done_w            when i_correct_enable = '1' else done_vote_w(0);
  ARVALID           <= corr_arvalid_w         when i_correct_enable = '1' else arvalid_vote_w(0);
  RREADY            <= corr_rready_w          when i_correct_enable = '1' else rready_vote_w(0);
  o_rbeat_hs_comb   <= corr_rbeat_hs_comb_w   when i_correct_enable = '1' else rbeat_hs_comb_vote_w(0);
  o_seed_pulse      <= corr_seed_pulse_w      when i_correct_enable = '1' else seed_pulse_vote_w(0);

end architecture;
