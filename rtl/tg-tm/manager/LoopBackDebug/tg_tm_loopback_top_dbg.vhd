library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Debuggable loopback top: exposes internal FSM/data regs to the TB.
entity tg_tm_loopback_top_dbg is
  generic (
    p_MEM_ADDR_BITS : natural := 10
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- NoC ports (connect to NI)
    lin_data_i : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lin_val_i  : in  std_logic;
    lin_ack_o  : out std_logic;

    lout_data_o : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lout_val_o  : out std_logic;
    lout_ack_i  : in  std_logic;

    -- DEBUG (handshakes + FSM state + decoded request info)
    dbg_ctrl_state         : out std_logic_vector(2 downto 0);
    dbg_ctrl_cap_idx       : out unsigned(5 downto 0);
    dbg_ctrl_seen_last     : out std_logic;
    dbg_ctrl_payload_idx   : out unsigned(7 downto 0);
    dbg_ctrl_payload_words : out unsigned(8 downto 0);
    dbg_ctrl_resp_is_read  : out std_logic;

    dbg_dp_hdr0  : out std_logic_vector(31 downto 0);
    dbg_dp_hdr1  : out std_logic_vector(31 downto 0);
    dbg_dp_hdr2  : out std_logic_vector(31 downto 0);
    dbg_dp_addr  : out std_logic_vector(31 downto 0);
    dbg_dp_opc   : out std_logic;
    dbg_dp_ready : out std_logic;

    dbg_req_ready    : out std_logic;
    dbg_req_is_write : out std_logic;
    dbg_req_is_read  : out std_logic;
    dbg_req_len      : out unsigned(7 downto 0);
    dbg_hold_valid   : out std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_top_dbg is

  signal cap_en   : std_logic;
  signal cap_flit : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal cap_idx  : unsigned(5 downto 0);
  signal cap_last : std_logic;

  signal req_ready    : std_logic;
  signal req_is_write : std_logic;
  signal req_is_read  : std_logic;
  signal req_len      : unsigned(7 downto 0);
  signal req_id       : std_logic_vector(4 downto 0);
  signal req_burst    : std_logic_vector(1 downto 0);
  signal req_base_idx : unsigned(p_MEM_ADDR_BITS-1 downto 0);

  signal resp_hdr0, resp_hdr1, resp_hdr2 : std_logic_vector(31 downto 0);

  signal rd_payload_idx : unsigned(7 downto 0);
  signal rd_payload     : std_logic_vector(31 downto 0);

  signal hold_valid : std_logic;
  signal hold_clr   : std_logic;

begin

  dbg_req_ready    <= req_ready;
  dbg_req_is_write <= req_is_write;
  dbg_req_is_read  <= req_is_read;
  dbg_req_len      <= req_len;
  dbg_hold_valid   <= hold_valid;

  u_dp: entity work.tg_tm_loopback_datapath_dbg
    generic map(
      p_MEM_ADDR_BITS => p_MEM_ADDR_BITS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_cap_en   => cap_en,
      i_cap_flit => cap_flit,
      i_cap_idx  => cap_idx,
      i_cap_last => cap_last,

      o_req_ready    => req_ready,
      o_req_is_write => req_is_write,
      o_req_is_read  => req_is_read,
      o_req_len      => req_len,
      o_req_id       => req_id,
      o_req_burst    => req_burst,
      o_req_base_idx => req_base_idx,

      i_rd_payload_idx => rd_payload_idx,
      o_rd_payload     => rd_payload,

      o_resp_hdr0 => resp_hdr0,
      o_resp_hdr1 => resp_hdr1,
      o_resp_hdr2 => resp_hdr2,

      o_hold_valid => hold_valid,
      i_hold_clr   => hold_clr,

      o_dbg_hdr0  => dbg_dp_hdr0,
      o_dbg_hdr1  => dbg_dp_hdr1,
      o_dbg_hdr2  => dbg_dp_hdr2,
      o_dbg_addr  => dbg_dp_addr,
      o_dbg_opc   => dbg_dp_opc,
      o_dbg_ready => dbg_dp_ready
    );

  u_ctrl: entity work.tg_tm_loopback_controller_dbg
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_lin_data => lin_data_i,
      i_lin_val  => lin_val_i,
      o_lin_ack  => lin_ack_o,

      o_lout_data => lout_data_o,
      o_lout_val  => lout_val_o,
      i_lout_ack  => lout_ack_i,

      o_cap_en   => cap_en,
      o_cap_flit => cap_flit,
      o_cap_idx  => cap_idx,
      o_cap_last => cap_last,

      i_req_ready    => req_ready,
      i_req_is_write => req_is_write,
      i_req_is_read  => req_is_read,
      i_req_len      => req_len,
      i_resp_hdr0    => resp_hdr0,
      i_resp_hdr1    => resp_hdr1,
      i_resp_hdr2    => resp_hdr2,

      o_rd_payload_idx => rd_payload_idx,
      i_rd_payload     => rd_payload,

      i_hold_valid => hold_valid,
      o_hold_clr   => hold_clr,

      o_dbg_state         => dbg_ctrl_state,
      o_dbg_cap_idx       => dbg_ctrl_cap_idx,
      o_dbg_seen_last     => dbg_ctrl_seen_last,
      o_dbg_payload_idx   => dbg_ctrl_payload_idx,
      o_dbg_payload_words => dbg_ctrl_payload_words,
      o_dbg_resp_is_read  => dbg_ctrl_resp_is_read
    );

end architecture;
