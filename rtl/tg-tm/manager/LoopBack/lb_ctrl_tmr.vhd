library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_ctrl_tmr is
  generic(
    p_USE_TMR_INJECT_ERROR : boolean := c_ENABLE_LB_CTRL_TMR_INJECT_ERROR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_lin_ctrl : in  std_logic;
    i_lin_val  : in  std_logic;
    o_lin_ack  : out std_logic;

    o_lout_val  : out std_logic;
    i_lout_ack  : in  std_logic;
    o_tx_next_is_read : out std_logic;
    o_tx_flit_sel     : out std_logic_vector(2 downto 0);

    o_cap_en   : out std_logic;
    o_cap_flit_ctrl : out std_logic;
    o_cap_idx  : out unsigned(5 downto 0);

    i_hold_valid : in  std_logic;

    i_correct_enable : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of lb_ctrl_tmr is

  function maj3(a,b,c : std_logic) return std_logic is
  begin
    return (a and b) or (a and c) or (b and c);
  end function;

  function dis3(a,b,c : std_logic) return std_logic is
  begin
    return (a xor b) or (a xor c) or (b xor c);
  end function;

  function maj3_vec(a,b,c : std_logic_vector) return std_logic_vector is
    variable v : std_logic_vector(a'range);
  begin
    for i in a'range loop
      v(i) := maj3(a(i), b(i), c(i));
    end loop;
    return v;
  end function;

  function dis3_vec(a,b,c : std_logic_vector) return std_logic is
    variable e : std_logic := '0';
  begin
    for i in a'range loop
      e := e or dis3(a(i), b(i), c(i));
    end loop;
    return e;
  end function;

  function maj3_uns(a,b,c : unsigned) return unsigned is
    variable v : unsigned(a'range);
  begin
    for i in a'range loop
      v(i) := maj3(a(i), b(i), c(i));
    end loop;
    return v;
  end function;

  function dis3_uns(a,b,c : unsigned) return std_logic is
    variable e : std_logic := '0';
  begin
    for i in a'range loop
      e := e or dis3(a(i), b(i), c(i));
    end loop;
    return e;
  end function;

  type tmr_sl  is array (0 to 2) of std_logic;
  type tmr_sel is array (0 to 2) of std_logic_vector(2 downto 0);
  type tmr_u6  is array (0 to 2) of unsigned(5 downto 0);

  signal lin_ack_w  : tmr_sl;
  signal lout_val_w : tmr_sl;
  signal tx_next_is_read_w : tmr_sl;
  signal tx_flit_sel_w : tmr_sel;
  signal cap_en_w   : tmr_sl;
  signal cap_idx_w  : tmr_u6;
  signal lin_ack_vote_w         : tmr_sl;
  signal lout_val_vote_w        : tmr_sl;
  signal tx_next_is_read_vote_w : tmr_sl;
  signal tx_flit_sel_vote_w     : tmr_sel;
  signal cap_en_vote_w          : tmr_sl;
  signal cap_idx_vote_w         : tmr_u6;

  signal cap_flit_ctrl_w : tmr_sl;
  signal cap_flit_ctrl_vote_w : tmr_sl;
  signal inj_fire_w : std_logic := '0';

  signal corr_lin_ack  : std_logic;
  signal corr_lout_val : std_logic;
  signal corr_tx_next_is_read : std_logic;
  signal corr_tx_flit_sel : std_logic_vector(2 downto 0);
  signal corr_cap_en   : std_logic;
  signal corr_cap_idx  : unsigned(5 downto 0);

  signal corr_cap_flit_ctrl  : std_logic;

  signal err_any : std_logic;

begin

  gen_no_inject : if (not p_USE_TMR_INJECT_ERROR) generate
  begin
    inj_fire_w <= '0';
    lin_ack_vote_w         <= lin_ack_w;
    lout_val_vote_w        <= lout_val_w;
    tx_next_is_read_vote_w <= tx_next_is_read_w;
    tx_flit_sel_vote_w     <= tx_flit_sel_w;
    cap_en_vote_w          <= cap_en_w;
    cap_idx_vote_w         <= cap_idx_w;
    cap_flit_ctrl_vote_w   <= cap_flit_ctrl_w;
  end generate;

  gen_inject : if p_USE_TMR_INJECT_ERROR generate
    signal inj_counter_r : std_logic_vector(15 downto 0) := (others => '0');
  begin
    p_inj_counter : process(ACLK, ARESETn)
    begin
      if ARESETn = '0' then
        inj_counter_r <= (others => '0');
      elsif rising_edge(ACLK) then
        if i_lin_val = '1' then
          if inj_counter_r(inj_counter_r'high) = '0' then
            inj_counter_r <= std_logic_vector(unsigned(inj_counter_r) + 1);
          end if;
        end if;
      end if;
    end process;

    inj_fire_w <= '1' when inj_counter_r = ("00" & (inj_counter_r'length-3 downto 0 => '1')) else '0';

    lin_ack_vote_w(2) <= lin_ack_w(2);
    lin_ack_vote_w(1) <= lin_ack_w(1);
    lin_ack_vote_w(0) <= not lin_ack_w(0) when inj_fire_w = '1' else lin_ack_w(0);
    lout_val_vote_w(2) <= lout_val_w(2);
    lout_val_vote_w(1) <= lout_val_w(1);
    lout_val_vote_w(0) <= not lout_val_w(0) when inj_fire_w = '1' else lout_val_w(0);
    tx_next_is_read_vote_w(2) <= tx_next_is_read_w(2);
    tx_next_is_read_vote_w(1) <= tx_next_is_read_w(1);
    tx_next_is_read_vote_w(0) <= not tx_next_is_read_w(0) when inj_fire_w = '1' else tx_next_is_read_w(0);
    tx_flit_sel_vote_w(2) <= tx_flit_sel_w(2);
    tx_flit_sel_vote_w(1) <= tx_flit_sel_w(1);
    tx_flit_sel_vote_w(0) <= not tx_flit_sel_w(0) when inj_fire_w = '1' else tx_flit_sel_w(0);
    cap_en_vote_w(2) <= cap_en_w(2);
    cap_en_vote_w(1) <= cap_en_w(1);
    cap_en_vote_w(0) <= not cap_en_w(0) when inj_fire_w = '1' else cap_en_w(0);
    cap_idx_vote_w(2) <= cap_idx_w(2);
    cap_idx_vote_w(1) <= cap_idx_w(1);
    cap_idx_vote_w(0) <= not cap_idx_w(0) when inj_fire_w = '1' else cap_idx_w(0);
    cap_flit_ctrl_vote_w(2) <= cap_flit_ctrl_w(2);
    cap_flit_ctrl_vote_w(1) <= cap_flit_ctrl_w(1);
    cap_flit_ctrl_vote_w(0) <= not cap_flit_ctrl_w(0) when inj_fire_w = '1' else cap_flit_ctrl_w(0);
  end generate;

  gen_rep : for i in 0 to 2 generate
  begin
    u_ctrl : entity work.lb_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_lin_ctrl => i_lin_ctrl,
        i_lin_val  => i_lin_val,
        o_lin_ack  => lin_ack_w(i),

        o_lout_val  => lout_val_w(i),
        i_lout_ack  => i_lout_ack,
        o_tx_next_is_read => tx_next_is_read_w(i),
        o_tx_flit_sel     => tx_flit_sel_w(i),

        o_cap_en   => cap_en_w(i),
        o_cap_flit_ctrl => cap_flit_ctrl_w(i),
        o_cap_idx  => cap_idx_w(i),

        i_hold_valid => i_hold_valid
      );
  end generate;

  -- votes
  corr_lin_ack  <= maj3(lin_ack_vote_w(2),  lin_ack_vote_w(1),  lin_ack_vote_w(0));
  corr_lout_val <= maj3(lout_val_vote_w(2), lout_val_vote_w(1), lout_val_vote_w(0));
  corr_tx_next_is_read <= maj3(tx_next_is_read_vote_w(2), tx_next_is_read_vote_w(1), tx_next_is_read_vote_w(0));
  corr_tx_flit_sel <= maj3_vec(tx_flit_sel_vote_w(2), tx_flit_sel_vote_w(1), tx_flit_sel_vote_w(0));
  corr_cap_en   <= maj3(cap_en_vote_w(2),   cap_en_vote_w(1),   cap_en_vote_w(0));
  corr_cap_idx  <= maj3_uns(cap_idx_vote_w(2), cap_idx_vote_w(1), cap_idx_vote_w(0));
  corr_cap_flit_ctrl <= maj3(cap_flit_ctrl_vote_w(2), cap_flit_ctrl_vote_w(1), cap_flit_ctrl_vote_w(0));

  -- disagreement detection
  err_any <= dis3(lin_ack_vote_w(2),  lin_ack_vote_w(1),  lin_ack_vote_w(0)) or
             dis3(lout_val_vote_w(2), lout_val_vote_w(1), lout_val_vote_w(0)) or
             dis3(tx_next_is_read_vote_w(2), tx_next_is_read_vote_w(1), tx_next_is_read_vote_w(0)) or
             dis3_vec(tx_flit_sel_vote_w(2), tx_flit_sel_vote_w(1), tx_flit_sel_vote_w(0)) or
             dis3(cap_en_vote_w(2),   cap_en_vote_w(1),   cap_en_vote_w(0)) or
             dis3_uns(cap_idx_vote_w(2), cap_idx_vote_w(1), cap_idx_vote_w(0)) or
             dis3(cap_flit_ctrl_vote_w(2), cap_flit_ctrl_vote_w(1), cap_flit_ctrl_vote_w(0)) or
             '0';

  error_o <= err_any;

  -- selection (same as TG controller_tmr style)
  o_lin_ack  <= corr_lin_ack  when i_correct_enable='1' else lin_ack_vote_w(0);
  o_lout_val <= corr_lout_val when i_correct_enable='1' else lout_val_vote_w(0);
  o_tx_next_is_read <= corr_tx_next_is_read when i_correct_enable='1' else tx_next_is_read_vote_w(0);
  o_tx_flit_sel <= corr_tx_flit_sel when i_correct_enable='1' else tx_flit_sel_vote_w(0);
  o_cap_en   <= corr_cap_en   when i_correct_enable='1' else cap_en_vote_w(0);
  o_cap_idx  <= corr_cap_idx  when i_correct_enable='1' else cap_idx_vote_w(0);
  o_cap_flit_ctrl <= corr_cap_flit_ctrl when i_correct_enable='1' else cap_flit_ctrl_vote_w(0);

end architecture;
