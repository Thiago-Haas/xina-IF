library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Synthesizable NoC-side loopback (subordinate emulator) for the combined TG/TM+NI top.
-- Split into controller + datapath.
entity tg_tm_loopback_top is
  generic (
    p_MEM_ADDR_BITS : natural := 10
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Connect to tg_tm_ni_top NoC ports
    -- Request stream from NI:
    lin_data_i : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lin_val_i  : in  std_logic;
    lin_ack_o  : out std_logic;

    -- Response stream to NI:
    lout_data_o : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    lout_val_o  : out std_logic;
    lout_ack_i  : in  std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_top is

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

  u_dp: entity work.tg_tm_loopback_datapath
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
      i_hold_clr   => hold_clr
    );

  u_ctrl: entity work.tg_tm_loopback_controller
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
      o_hold_clr   => hold_clr
    );

end architecture;
