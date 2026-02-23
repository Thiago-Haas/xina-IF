library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Flat hierarchy top with DEBUG loopback visibility.
--
-- IMPORTANT (matches your working tg_ni_write_only_top / tm_ni_read_only_top wrappers):
--   * top_manager exposes the NI->NoC request stream on ports named l_in_* (yes, *_i suffix!)
--   * top_manager consumes the NoC->NI response stream on ports named l_out_* (yes, *_o suffix!)
--
-- So wiring here is:
--   NI request  (top_manager.l_in_*)  -> loopback.lin_*
--   NI response (top_manager.l_out_*) <- loopback.lout_*
entity tg_tm_ni_hwloopback_flat_top_dbg is
  generic (
    p_MEM_ADDR_BITS : natural := 10
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    i_tg_start       : in  std_logic;
    o_tg_done        : out std_logic;
    TG_INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    TG_STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- TM control
    i_tm_start       : in  std_logic;
    o_tm_done        : out std_logic;
    TM_INPUT_ADDRESS : in  std_logic_vector(63 downto 0);
    TM_STARTING_SEED : in  std_logic_vector(31 downto 0);

    -- TM observability
    o_tm_mismatch       : out std_logic;
    o_tm_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- LOOPBACK DEBUG out to TB
    dbg_lin_val  : out std_logic;
    dbg_lin_ack  : out std_logic;
    dbg_lin_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);

    dbg_lout_val  : out std_logic;
    dbg_lout_ack  : out std_logic;
    dbg_lout_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);

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

architecture rtl of tg_tm_ni_hwloopback_flat_top_dbg is

  -- AXI write (TG)
  signal awid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal awaddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal awlen   : std_logic_vector(7 downto 0);
  signal awburst : std_logic_vector(1 downto 0);
  signal awvalid : std_logic;
  signal awready : std_logic;

  signal wvalid  : std_logic;
  signal wready  : std_logic;
  signal wdata   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal wlast   : std_logic;

  signal bid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal bvalid : std_logic;
  signal bready : std_logic;

  -- AXI read (TM)
  signal arid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen   : std_logic_vector(7 downto 0);
  signal arburst : std_logic_vector(1 downto 0);
  signal arvalid : std_logic;
  signal arready : std_logic;

  signal rvalid : std_logic;
  signal rready : std_logic;
  signal rdata  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast  : std_logic;
  signal rid    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- NI <-> Loopback NoC signals
  signal lin_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lin_val  : std_logic;
  signal lin_ack  : std_logic;

  signal lout_data : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  signal lout_val  : std_logic;
  signal lout_ack  : std_logic;

  signal tg_lfsr_value : std_logic_vector(c_AXI_DATA_WIDTH-1 downto 0);

begin

  -- Export handshakes for TB
  dbg_lin_val  <= lin_val;
  dbg_lin_ack  <= lin_ack;
  dbg_lin_data <= lin_data;

  dbg_lout_val  <= lout_val;
  dbg_lout_ack  <= lout_ack;
  dbg_lout_data <= lout_data;

  -- TG
  u_tg: entity work.tg_write_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_tg_start,
      o_done  => o_tg_done,

      INPUT_ADDRESS => TG_INPUT_ADDRESS,
      STARTING_SEED => TG_STARTING_SEED,

      i_ext_update_en => '0',
      i_ext_data_in   => (others => '0'),

      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,
      AWVALID => awvalid,
      AWREADY => awready,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BID     => bid,
      BRESP   => bresp,
      BVALID  => bvalid,
      BREADY  => bready,

      o_lfsr_value => tg_lfsr_value
    );

  -- TM
  u_tm: entity work.tm_read_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_tm_start,
      o_done  => o_tm_done,

      INPUT_ADDRESS => TM_INPUT_ADDRESS,
      STARTING_SEED => TM_STARTING_SEED,

      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,
      ARVALID => arvalid,
      ARREADY => arready,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      o_mismatch       => o_tm_mismatch,
      o_expected_value => o_tm_expected_value
    );

  -- Single NI manager
  u_ni: entity work.top_manager
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- Write
      AWVALID => awvalid,
      AWREADY => awready,
      AWID    => awid,
      AWADDR  => awaddr,
      AWLEN   => awlen,
      AWBURST => awburst,

      WVALID  => wvalid,
      WREADY  => wready,
      WDATA   => wdata,
      WLAST   => wlast,

      BVALID  => bvalid,
      BREADY  => bready,
      BID     => bid,
      BRESP   => bresp,

      -- Read
      ARVALID => arvalid,
      ARREADY => arready,
      ARID    => arid,
      ARADDR  => araddr,
      ARLEN   => arlen,
      ARBURST => arburst,

      RVALID => rvalid,
      RREADY => rready,
      RDATA  => rdata,
      RLAST  => rlast,
      RID    => rid,
      RRESP  => rresp,

      -- NoC-side ports (see header comment)
      -- NI -> NoC (request stream)
      l_in_data_i  => lin_data,
      l_in_val_i   => lin_val,
      l_in_ack_o   => lin_ack,

      -- NoC -> NI (response stream)
      l_out_data_o => lout_data,
      l_out_val_o  => lout_val,
      l_out_ack_i  => lout_ack,

      corrupt_packet => open
    );

  -- HW loopback (DEBUG variant)
  u_lb: entity work.tg_tm_loopback_top_dbg
    generic map(
      p_MEM_ADDR_BITS => p_MEM_ADDR_BITS
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_data_i => lin_data,
      lin_val_i  => lin_val,
      lin_ack_o  => lin_ack,

      lout_data_o => lout_data,
      lout_val_o  => lout_val,
      lout_ack_i  => lout_ack,

      dbg_ctrl_state         => dbg_ctrl_state,
      dbg_ctrl_cap_idx       => dbg_ctrl_cap_idx,
      dbg_ctrl_seen_last     => dbg_ctrl_seen_last,
      dbg_ctrl_payload_idx   => dbg_ctrl_payload_idx,
      dbg_ctrl_payload_words => dbg_ctrl_payload_words,
      dbg_ctrl_resp_is_read  => dbg_ctrl_resp_is_read,

      dbg_dp_hdr0  => dbg_dp_hdr0,
      dbg_dp_hdr1  => dbg_dp_hdr1,
      dbg_dp_hdr2  => dbg_dp_hdr2,
      dbg_dp_addr  => dbg_dp_addr,
      dbg_dp_opc   => dbg_dp_opc,
      dbg_dp_ready => dbg_dp_ready,

      dbg_req_ready    => dbg_req_ready,
      dbg_req_is_write => dbg_req_is_write,
      dbg_req_is_read  => dbg_req_is_read,
      dbg_req_len      => dbg_req_len,
      dbg_hold_valid   => dbg_hold_valid
    );

end architecture;
