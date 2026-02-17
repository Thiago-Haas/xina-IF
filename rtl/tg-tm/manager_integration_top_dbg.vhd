library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

-- Integration top: connects
--   tg_write_top  -> AXI write into top_manager
--   tm_read_top   -> AXI read  into top_manager
--   top_manager   -> NoC-side link
--   manager_loopback_top -> loopback "NoC" responder for manager
entity manager_integration_dbg_top is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- control / sequencing
    i_start_write : in  std_logic := '0';
    i_start_read  : in  std_logic := '0';

    i_address : in std_logic_vector(63 downto 0) := (others => '0');
    i_seed    : in std_logic_vector(31 downto 0) := (others => '0');

    -- status / observability
    o_done_write : out std_logic;
    o_done_read  : out std_logic;
    o_mismatch   : out std_logic;
    o_expected_value : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_lfsr_value     : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    o_corrupt_packet : out std_logic;
    -- debug taps (for testbench diagnostics)
    dbg_awvalid : out std_logic;
    dbg_awready : out std_logic;
    dbg_awaddr  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    dbg_awlen   : out std_logic_vector(7 downto 0);

    dbg_wvalid : out std_logic;
    dbg_wready : out std_logic;
    dbg_wlast  : out std_logic;
    dbg_wdata  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    dbg_bvalid : out std_logic;
    dbg_bready : out std_logic;
    dbg_bresp  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    dbg_arvalid : out std_logic;
    dbg_arready : out std_logic;
    dbg_araddr  : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    dbg_arlen   : out std_logic_vector(7 downto 0);

    dbg_rvalid : out std_logic;
    dbg_rready : out std_logic;
    dbg_rlast  : out std_logic;
    dbg_rdata  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    dbg_rresp  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    dbg_lin_val  : out std_logic;
    dbg_lin_ack  : out std_logic;
    dbg_lin_data : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    dbg_lout_val  : out std_logic;
    dbg_lout_ack  : out std_logic;
    dbg_lout_data : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of manager_integration_dbg_top is

  -- AXI write channel
  signal awvalid_s : std_logic;
  signal awready_s : std_logic;
  signal awid_s    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal awaddr_s  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal awlen_s   : std_logic_vector(7 downto 0);
  signal awburst_s : std_logic_vector(1 downto 0);

  signal wvalid_s  : std_logic;
  signal wready_s  : std_logic;
  signal wdata_s   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal wlast_s   : std_logic;

  signal bvalid_s  : std_logic;
  signal bready_s  : std_logic;
  signal bid_s     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp_s   : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- AXI read channel
  signal arvalid_s : std_logic;
  signal arready_s : std_logic;
  signal arid_s    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal araddr_s  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal arlen_s   : std_logic_vector(7 downto 0);
  signal arburst_s : std_logic_vector(1 downto 0);

  signal rvalid_s  : std_logic;
  signal rready_s  : std_logic;
  signal rdata_s   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rlast_s   : std_logic;
  signal rid_s     : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp_s   : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  -- NoC-side link between NI (inside top_manager) and loopback
  signal l_in_data_s : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal l_in_val_s  : std_logic;
  signal l_in_ack_s  : std_logic;

  signal l_out_data_s: std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal l_out_val_s : std_logic;
  signal l_out_ack_s : std_logic;

begin

  -- debug assignments
  dbg_awvalid <= awvalid_s;
  dbg_awready <= awready_s;
  dbg_awaddr  <= awaddr_s;
  dbg_awlen   <= awlen_s;

  dbg_wvalid <= wvalid_s;
  dbg_wready <= wready_s;
  dbg_wlast  <= wlast_s;
  dbg_wdata  <= wdata_s;

  dbg_bvalid <= bvalid_s;
  dbg_bready <= bready_s;
  dbg_bresp  <= bresp_s;

  dbg_arvalid <= arvalid_s;
  dbg_arready <= arready_s;
  dbg_araddr  <= araddr_s;
  dbg_arlen   <= arlen_s;

  dbg_rvalid <= rvalid_s;
  dbg_rready <= rready_s;
  dbg_rlast  <= rlast_s;
  dbg_rdata  <= rdata_s;
  dbg_rresp  <= rresp_s;

  dbg_lin_val  <= l_in_val_s;
  dbg_lin_ack  <= l_in_ack_s;
  dbg_lin_data <= l_in_data_s;

  dbg_lout_val  <= l_out_val_s;
  dbg_lout_ack  <= l_out_ack_s;
  dbg_lout_data <= l_out_data_s;



  -- Write traffic generator
  u_TG: entity work.tg_write_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start_write,
      o_done  => o_done_write,

      INPUT_ADDRESS => i_address,
      STARTING_SEED => i_seed,

      -- not used in this integration
      i_ext_update_en => '0',
      i_ext_data_in   => (others => '0'),

      AWID    => awid_s,
      AWADDR  => awaddr_s,
      AWLEN   => awlen_s,
      AWBURST => awburst_s,
      AWVALID => awvalid_s,
      AWREADY => awready_s,

      WVALID => wvalid_s,
      WREADY => wready_s,
      WDATA  => wdata_s,
      WLAST  => wlast_s,

      BID    => bid_s,
      BRESP  => bresp_s(1 downto 0), -- tg has 2-bit BRESP
      BVALID => bvalid_s,
      BREADY => bready_s,

      o_lfsr_value => o_lfsr_value
    );

  -- Read traffic monitor / generator
  u_TM: entity work.tm_read_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      i_start => i_start_read,
      o_done  => o_done_read,

      INPUT_ADDRESS => i_address,
      STARTING_SEED => i_seed,

      ARID    => arid_s,
      ARADDR  => araddr_s,
      ARLEN   => arlen_s,
      ARBURST => arburst_s,
      ARVALID => arvalid_s,
      ARREADY => arready_s,

      RVALID => rvalid_s,
      RREADY => rready_s,
      RDATA  => rdata_s,
      RLAST  => rlast_s,

      RID   => rid_s,
      RRESP => rresp_s,

      o_mismatch       => o_mismatch,
      o_expected_value => o_expected_value
    );

  -- Manager + NI top (AXI slave side + NoC-side link)
  u_MGR: entity work.top_manager
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      -- write
      AWVALID => awvalid_s,
      AWREADY => awready_s,
      AWID    => awid_s,
      AWADDR  => awaddr_s,
      AWLEN   => awlen_s,
      AWBURST => awburst_s,

      WVALID  => wvalid_s,
      WREADY  => wready_s,
      WDATA   => wdata_s,
      WLAST   => wlast_s,

      BVALID  => bvalid_s,
      BREADY  => bready_s,
      BID     => bid_s,
      BRESP   => bresp_s,

      -- read
      ARVALID => arvalid_s,
      ARREADY => arready_s,
      ARID    => arid_s,
      ARADDR  => araddr_s,
      ARLEN   => arlen_s,
      ARBURST => arburst_s,

      RVALID  => rvalid_s,
      RREADY  => rready_s,
      RDATA   => rdata_s,
      RLAST   => rlast_s,
      RID     => rid_s,
      RRESP   => rresp_s,

      CORRUPT_PACKET => o_corrupt_packet,

      l_in_data_i  => l_in_data_s,
      l_in_val_i   => l_in_val_s,
      l_in_ack_o   => l_in_ack_s,

      l_out_data_o => l_out_data_s,
      l_out_val_o  => l_out_val_s,
      l_out_ack_i  => l_out_ack_s
    );

  -- NoC-side loopback responder
  u_LB: entity work.manager_loopback_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,

      lin_data => l_in_data_s,
      lin_val  => l_in_val_s,
      lin_ack  => l_in_ack_s,

      lout_data => l_out_data_s,
      lout_val  => l_out_val_s,
      lout_ack  => l_out_ack_s
    );

end architecture;
