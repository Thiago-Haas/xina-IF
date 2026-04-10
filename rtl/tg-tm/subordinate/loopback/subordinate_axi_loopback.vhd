library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- Minimal AXI slave loopback for the subordinate NI system test.
-- Wrapper split into control and datapath, matching the TG/TM organization.
entity subordinate_axi_loopback is
  generic(
    p_USE_TMR_CTRL  : boolean := c_ENABLE_SUB_LB_CTRL_TMR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    AWVALID : in  std_logic;
    AWREADY : out std_logic;
    AWID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : in  std_logic_vector(7 downto 0);
    AWSIZE  : in  std_logic_vector(2 downto 0);
    AWBURST : in  std_logic_vector(1 downto 0);

    WVALID : in  std_logic;
    WREADY : out std_logic;
    WDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST  : in  std_logic;

    BVALID : out std_logic;
    BREADY : in  std_logic;
    BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    ARVALID : in  std_logic;
    ARREADY : out std_logic;
    ARID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : in  std_logic_vector(7 downto 0);
    ARSIZE  : in  std_logic_vector(2 downto 0);
    ARBURST : in  std_logic_vector(1 downto 0);

    RVALID : out std_logic;
    RREADY : in  std_logic;
    RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RLAST  : out std_logic;
    RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_TMR_CTRL_ERROR_o         : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i   : in  std_logic := '1';
    OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o      : out std_logic := '0';
    OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o      : out std_logic := '0';
    OBS_SUB_LB_HAM_RDATA_ENC_DATA_o        : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0');
    OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o      : out std_logic_vector((3 * c_AXI_ID_WIDTH) + work.hamming_pkg.get_ecc_size(3 * c_AXI_ID_WIDTH, c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0')
  );
end entity;

architecture rtl of subordinate_axi_loopback is
  signal rvalid_w : std_logic;
  signal aw_accept_w : std_logic;
  signal w_accept_w  : std_logic;
  signal ar_accept_w : std_logic;
begin
  RLAST <= rvalid_w;

  gen_control_plain : if not p_USE_TMR_CTRL generate
    u_control: entity work.subordinate_axi_loopback_control
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        AWVALID => AWVALID,
        AWREADY => AWREADY,
        WVALID => WVALID,
        WREADY => WREADY,
        BVALID => BVALID,
        BREADY => BREADY,
        ARVALID => ARVALID,
        ARREADY => ARREADY,
        RVALID => rvalid_w,
        RREADY => RREADY,
        aw_accept_o => aw_accept_w,
        w_accept_o => w_accept_w,
        ar_accept_o => ar_accept_w
      );

    OBS_SUB_LB_TMR_CTRL_ERROR_o <= '0';
  end generate;

  gen_control_tmr : if p_USE_TMR_CTRL generate
    u_control_tmr: entity work.subordinate_axi_loopback_control_tmr
      port map(
        ACLK => ACLK,
        ARESETn => ARESETn,
        AWVALID => AWVALID,
        AWREADY => AWREADY,
        WVALID => WVALID,
        WREADY => WREADY,
        BVALID => BVALID,
        BREADY => BREADY,
        ARVALID => ARVALID,
        ARREADY => ARREADY,
        RVALID => rvalid_w,
        RREADY => RREADY,
        aw_accept_o => aw_accept_w,
        w_accept_o => w_accept_w,
        ar_accept_o => ar_accept_w,
        correct_enable_i => OBS_SUB_LB_TMR_CTRL_CORRECT_ERROR_i,
        error_o => OBS_SUB_LB_TMR_CTRL_ERROR_o
      );
  end generate;

  RVALID <= rvalid_w;

  u_datapath: entity work.subordinate_axi_loopback_datapath
    port map(
      ACLK => ACLK,
      ARESETn => ARESETn,
      aw_accept_i => aw_accept_w,
      w_accept_i => w_accept_w,
      ar_accept_i => ar_accept_w,
      AWID => AWID,
      WDATA => WDATA,
      WLAST => WLAST,
      BID => BID,
      BRESP => BRESP,
      ARID => ARID,
      RDATA => RDATA,
      RID => RID,
      RRESP => RRESP,
      OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i => OBS_SUB_LB_HAM_PAYLOAD_CORRECT_ERROR_i,
      OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o    => OBS_SUB_LB_HAM_PAYLOAD_SINGLE_ERR_o,
      OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o    => OBS_SUB_LB_HAM_PAYLOAD_DOUBLE_ERR_o,
      OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o      => OBS_SUB_LB_HAM_PAYLOAD_ENC_DATA_o,
      OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i   => OBS_SUB_LB_HAM_RDATA_CORRECT_ERROR_i,
      OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o      => OBS_SUB_LB_HAM_RDATA_SINGLE_ERR_o,
      OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o      => OBS_SUB_LB_HAM_RDATA_DOUBLE_ERR_o,
      OBS_SUB_LB_HAM_RDATA_ENC_DATA_o        => OBS_SUB_LB_HAM_RDATA_ENC_DATA_o,
      OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i => OBS_SUB_LB_HAM_ID_STATE_CORRECT_ERROR_i,
      OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o    => OBS_SUB_LB_HAM_ID_STATE_SINGLE_ERR_o,
      OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o    => OBS_SUB_LB_HAM_ID_STATE_DOUBLE_ERR_o,
      OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o      => OBS_SUB_LB_HAM_ID_STATE_ENC_DATA_o
    );
end architecture;
