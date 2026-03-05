library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_ctrl_tmr is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_lin_data : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_lin_val  : in  std_logic;
    o_lin_ack  : out std_logic;

    o_lout_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_lout_val  : out std_logic;
    i_lout_ack  : in  std_logic;

    o_cap_en   : out std_logic;
    o_cap_flit : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_cap_idx  : out unsigned(5 downto 0);
    o_cap_last : out std_logic;

    i_req_ready    : in  std_logic;
    i_req_is_write : in  std_logic;
    i_req_is_read  : in  std_logic;
    i_req_len      : in  unsigned(7 downto 0);

    i_resp_hdr0 : in  std_logic_vector(31 downto 0);
    i_resp_hdr1 : in  std_logic_vector(31 downto 0);
    i_resp_hdr2 : in  std_logic_vector(31 downto 0);

    o_rd_payload_idx : out unsigned(7 downto 0);
    i_rd_payload     : in  std_logic_vector(31 downto 0);

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

  type tmr_sl is array (0 to 2) of std_logic;
  type tmr_flit is array (0 to 2) of std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  type tmr_u6  is array (0 to 2) of unsigned(5 downto 0);
  type tmr_u8  is array (0 to 2) of unsigned(7 downto 0);

  signal lin_ack_w  : tmr_sl;
  signal lout_val_w : tmr_sl;
  signal cap_en_w   : tmr_sl;
  signal cap_last_w : tmr_sl;
  signal hold_clr_w : tmr_sl;

  signal lout_data_w : tmr_flit;
  signal cap_flit_w  : tmr_flit;
  signal cap_idx_w   : tmr_u6;
  signal rd_idx_w    : tmr_u8;

  signal corr_lin_ack  : std_logic;
  signal corr_lout_val : std_logic;
  signal corr_cap_en   : std_logic;
  signal corr_cap_last : std_logic;
  signal corr_hold_clr : std_logic;

  signal corr_lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal corr_cap_flit  : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal corr_cap_idx   : unsigned(5 downto 0);
  signal corr_rd_idx    : unsigned(7 downto 0);

  signal err_any : std_logic;

begin

  gen_rep : for i in 0 to 2 generate
  begin
    u_ctrl : entity work.lb_ctrl
      port map(
        ACLK    => ACLK,
        ARESETn => ARESETn,

        i_lin_data => i_lin_data,
        i_lin_val  => i_lin_val,
        o_lin_ack  => lin_ack_w(i),

        o_lout_data => lout_data_w(i),
        o_lout_val  => lout_val_w(i),
        i_lout_ack  => i_lout_ack,

        o_cap_en   => cap_en_w(i),
        o_cap_flit => cap_flit_w(i),
        o_cap_idx  => cap_idx_w(i),
        o_cap_last => cap_last_w(i),

        i_req_ready    => i_req_ready,
        i_req_is_write => i_req_is_write,
        i_req_is_read  => i_req_is_read,
        i_req_len      => i_req_len,

        i_resp_hdr0 => i_resp_hdr0,
        i_resp_hdr1 => i_resp_hdr1,
        i_resp_hdr2 => i_resp_hdr2,

        o_rd_payload_idx => rd_idx_w(i),
        i_rd_payload     => i_rd_payload,

        i_hold_valid => i_hold_valid,
        o_hold_clr   => hold_clr_w(i)
      );
  end generate;

  -- votes
  corr_lin_ack  <= maj3(lin_ack_w(2),  lin_ack_w(1),  lin_ack_w(0));
  corr_lout_val <= maj3(lout_val_w(2), lout_val_w(1), lout_val_w(0));
  corr_cap_en   <= maj3(cap_en_w(2),   cap_en_w(1),   cap_en_w(0));
  corr_cap_last <= maj3(cap_last_w(2), cap_last_w(1), cap_last_w(0));
  corr_hold_clr <= maj3(hold_clr_w(2), hold_clr_w(1), hold_clr_w(0));

  corr_lout_data <= maj3_vec(lout_data_w(2), lout_data_w(1), lout_data_w(0));
  corr_cap_flit  <= maj3_vec(cap_flit_w(2),  cap_flit_w(1),  cap_flit_w(0));
  corr_cap_idx   <= maj3_uns(cap_idx_w(2),   cap_idx_w(1),   cap_idx_w(0));
  corr_rd_idx    <= maj3_uns(rd_idx_w(2),    rd_idx_w(1),    rd_idx_w(0));

  -- disagreement detection
  err_any <= dis3(lin_ack_w(2),  lin_ack_w(1),  lin_ack_w(0)) or
             dis3(lout_val_w(2), lout_val_w(1), lout_val_w(0)) or
             dis3(cap_en_w(2),   cap_en_w(1),   cap_en_w(0)) or
             dis3(cap_last_w(2), cap_last_w(1), cap_last_w(0)) or
             dis3(hold_clr_w(2), hold_clr_w(1), hold_clr_w(0)) or
             dis3_vec(lout_data_w(2), lout_data_w(1), lout_data_w(0)) or
             dis3_vec(cap_flit_w(2),  cap_flit_w(1),  cap_flit_w(0)) or
             dis3_uns(cap_idx_w(2),   cap_idx_w(1),   cap_idx_w(0)) or
             dis3_uns(rd_idx_w(2),    rd_idx_w(1),    rd_idx_w(0));

  error_o <= err_any;

  -- selection (same as TG controller_tmr style)
  o_lin_ack  <= corr_lin_ack  when i_correct_enable='1' else lin_ack_w(0);
  o_lout_val <= corr_lout_val when i_correct_enable='1' else lout_val_w(0);
  o_cap_en   <= corr_cap_en   when i_correct_enable='1' else cap_en_w(0);
  o_cap_last <= corr_cap_last when i_correct_enable='1' else cap_last_w(0);
  o_hold_clr <= corr_hold_clr when i_correct_enable='1' else hold_clr_w(0);

  o_lout_data <= corr_lout_data when i_correct_enable='1' else lout_data_w(0);
  o_cap_flit  <= corr_cap_flit  when i_correct_enable='1' else cap_flit_w(0);
  o_cap_idx   <= corr_cap_idx   when i_correct_enable='1' else cap_idx_w(0);
  o_rd_payload_idx <= corr_rd_idx when i_correct_enable='1' else rd_idx_w(0);

end architecture;
