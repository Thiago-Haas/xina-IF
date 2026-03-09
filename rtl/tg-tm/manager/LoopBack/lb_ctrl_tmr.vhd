library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_ctrl_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_lin_ctrl : in  std_logic;
    i_lin_val  : in  std_logic;
    o_lin_ack  : out std_logic;

    o_lout_val  : out std_logic;
    i_lout_ack  : in  std_logic;
    o_tx_next_is_read : out std_logic;
    o_tx_has_payload  : out std_logic;

    o_cap_en   : out std_logic;
    o_cap_flit_ctrl : out std_logic;

    i_hold_valid : in  std_logic;
    o_hold_clr   : out std_logic;

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

  type tmr_sl is array (0 to 2) of std_logic;
  type tmr_u6  is array (0 to 2) of unsigned(5 downto 0);

  signal lin_ack_w  : tmr_sl;
  signal lout_val_w : tmr_sl;
  signal tx_next_is_read_w : tmr_sl;
  signal tx_has_payload_w : tmr_sl;
  signal cap_en_w   : tmr_sl;
  signal hold_clr_w : tmr_sl;

  signal cap_flit_ctrl_w : tmr_sl;

  signal corr_lin_ack  : std_logic;
  signal corr_lout_val : std_logic;
  signal corr_tx_next_is_read : std_logic;
  signal corr_tx_has_payload : std_logic;
  signal corr_cap_en   : std_logic;
  signal corr_hold_clr : std_logic;

  signal corr_cap_flit_ctrl  : std_logic;

  signal err_any : std_logic;

begin

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
        o_tx_has_payload  => tx_has_payload_w(i),

        o_cap_en   => cap_en_w(i),
        o_cap_flit_ctrl => cap_flit_ctrl_w(i),

        i_hold_valid => i_hold_valid,
        o_hold_clr   => hold_clr_w(i)
      );
  end generate;

  -- votes
  corr_lin_ack  <= maj3(lin_ack_w(2),  lin_ack_w(1),  lin_ack_w(0));
  corr_lout_val <= maj3(lout_val_w(2), lout_val_w(1), lout_val_w(0));
  corr_tx_next_is_read <= maj3(tx_next_is_read_w(2), tx_next_is_read_w(1), tx_next_is_read_w(0));
  corr_tx_has_payload  <= maj3(tx_has_payload_w(2), tx_has_payload_w(1), tx_has_payload_w(0));
  corr_cap_en   <= maj3(cap_en_w(2),   cap_en_w(1),   cap_en_w(0));
  corr_hold_clr <= maj3(hold_clr_w(2), hold_clr_w(1), hold_clr_w(0));
  corr_cap_flit_ctrl <= maj3(cap_flit_ctrl_w(2), cap_flit_ctrl_w(1), cap_flit_ctrl_w(0));

  -- disagreement detection
  err_any <= dis3(lin_ack_w(2),  lin_ack_w(1),  lin_ack_w(0)) or
             dis3(lout_val_w(2), lout_val_w(1), lout_val_w(0)) or
             dis3(tx_next_is_read_w(2), tx_next_is_read_w(1), tx_next_is_read_w(0)) or
             dis3(tx_has_payload_w(2), tx_has_payload_w(1), tx_has_payload_w(0)) or
             dis3(cap_en_w(2),   cap_en_w(1),   cap_en_w(0)) or
             dis3(cap_flit_ctrl_w(2), cap_flit_ctrl_w(1), cap_flit_ctrl_w(0)) or
             dis3(hold_clr_w(2), hold_clr_w(1), hold_clr_w(0)) or
             '0';

  error_o <= err_any;

  -- selection (same as TG controller_tmr style)
  o_lin_ack  <= corr_lin_ack  when i_correct_enable='1' else lin_ack_w(0);
  o_lout_val <= corr_lout_val when i_correct_enable='1' else lout_val_w(0);
  o_tx_next_is_read <= corr_tx_next_is_read when i_correct_enable='1' else tx_next_is_read_w(0);
  o_tx_has_payload <= corr_tx_has_payload when i_correct_enable='1' else tx_has_payload_w(0);
  o_cap_en   <= corr_cap_en   when i_correct_enable='1' else cap_en_w(0);
  o_cap_flit_ctrl <= corr_cap_flit_ctrl when i_correct_enable='1' else cap_flit_ctrl_w(0);
  o_hold_clr <= corr_hold_clr when i_correct_enable='1' else hold_clr_w(0);

end architecture;
