library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity loopback_control_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    lin_ctrl_i : in  std_logic;
    lin_val_i  : in  std_logic;
    lin_ack_o  : out std_logic;

    lout_val_o  : out std_logic;
    lout_ack_i  : in  std_logic;
    tx_next_is_read_o : out std_logic;
    tx_flit_sel_o     : out std_logic_vector(2 downto 0);

    cap_en_o   : out std_logic;
    cap_flit_ctrl_o : out std_logic;
    cap_idx_o  : out unsigned(5 downto 0);

    hold_valid_i : in  std_logic;

    correct_enable_i : in  std_logic;
    error_o          : out std_logic
  );
end entity;

architecture rtl of loopback_control_tmr is
  attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
  attribute KEEP_HIERARCHY : string;

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

  signal cap_flit_ctrl_w : tmr_sl;

  signal corr_lin_ack  : std_logic;
  signal corr_lout_val : std_logic;
  signal corr_tx_next_is_read : std_logic;
  signal corr_tx_flit_sel : std_logic_vector(2 downto 0);
  signal corr_cap_en   : std_logic;
  signal corr_cap_idx  : unsigned(5 downto 0);

  signal corr_cap_flit_ctrl  : std_logic;

  signal err_any : std_logic;

begin

  gen_rep : for i in 0 to 2 generate
    attribute DONT_TOUCH of u_loopback_control : label is "TRUE";
        attribute syn_preserve of u_loopback_control : label is true;
    attribute KEEP_HIERARCHY of u_loopback_control : label is "TRUE";
  begin
    u_loopback_control: entity work.loopback_control
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        lin_ctrl_i => lin_ctrl_i,
        lin_val_i  => lin_val_i,
        lin_ack_o  => lin_ack_w(i),

        lout_val_o  => lout_val_w(i),
        lout_ack_i  => lout_ack_i,
        tx_next_is_read_o => tx_next_is_read_w(i),
        tx_flit_sel_o     => tx_flit_sel_w(i),

        cap_en_o   => cap_en_w(i),
        cap_flit_ctrl_o => cap_flit_ctrl_w(i),
        cap_idx_o  => cap_idx_w(i),

        hold_valid_i => hold_valid_i
      );
  end generate;

  -- votes
  corr_lin_ack  <= maj3(lin_ack_w(2),  lin_ack_w(1),  lin_ack_w(0));
  corr_lout_val <= maj3(lout_val_w(2), lout_val_w(1), lout_val_w(0));
  corr_tx_next_is_read <= maj3(tx_next_is_read_w(2), tx_next_is_read_w(1), tx_next_is_read_w(0));
  corr_tx_flit_sel <= maj3_vec(tx_flit_sel_w(2), tx_flit_sel_w(1), tx_flit_sel_w(0));
  corr_cap_en   <= maj3(cap_en_w(2),   cap_en_w(1),   cap_en_w(0));
  corr_cap_idx  <= maj3_uns(cap_idx_w(2), cap_idx_w(1), cap_idx_w(0));
  corr_cap_flit_ctrl <= maj3(cap_flit_ctrl_w(2), cap_flit_ctrl_w(1), cap_flit_ctrl_w(0));

  -- disagreement detection
  err_any <= dis3(lin_ack_w(2),  lin_ack_w(1),  lin_ack_w(0)) or
             dis3(lout_val_w(2), lout_val_w(1), lout_val_w(0)) or
             dis3(tx_next_is_read_w(2), tx_next_is_read_w(1), tx_next_is_read_w(0)) or
             dis3_vec(tx_flit_sel_w(2), tx_flit_sel_w(1), tx_flit_sel_w(0)) or
             dis3(cap_en_w(2),   cap_en_w(1),   cap_en_w(0)) or
             dis3_uns(cap_idx_w(2), cap_idx_w(1), cap_idx_w(0)) or
             dis3(cap_flit_ctrl_w(2), cap_flit_ctrl_w(1), cap_flit_ctrl_w(0)) or
             '0';

  error_o <= err_any;

  -- selection (same as TG controller_tmr style)
  lin_ack_o  <= corr_lin_ack  when correct_enable_i='1' else lin_ack_w(0);
  lout_val_o <= corr_lout_val when correct_enable_i='1' else lout_val_w(0);
  tx_next_is_read_o <= corr_tx_next_is_read when correct_enable_i='1' else tx_next_is_read_w(0);
  tx_flit_sel_o <= corr_tx_flit_sel when correct_enable_i='1' else tx_flit_sel_w(0);
  cap_en_o   <= corr_cap_en   when correct_enable_i='1' else cap_en_w(0);
  cap_idx_o  <= corr_cap_idx  when correct_enable_i='1' else cap_idx_w(0);
  cap_flit_ctrl_o <= corr_cap_flit_ctrl when correct_enable_i='1' else cap_flit_ctrl_w(0);

end architecture;
