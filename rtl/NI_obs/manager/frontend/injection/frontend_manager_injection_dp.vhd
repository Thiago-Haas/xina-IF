library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;
use work.hamming_pkg.all;

-- Injection datapath (AXI -> backend send)
--  * Holds the REQUEST HEADER registers, protected with Hamming ECC.
--  * Split into two independent Hamming-protected register blocks:
--      1) meta header: opc + id + len + burst
--      2) address    : addr
--  * Passes write data to backend (no buffering, preserves original behaviour).
--
-- Naming convention (aligned with backend style):
--  * *_r  : registered elements
--  * *_w  : combinational wires
entity frontend_manager_injection_dp is
  generic(
    p_USE_HAMMING_META_HDR : boolean := c_ENABLE_MGR_FE_INJ_META_HDR_HAMMING;
    p_USE_HAMMING_ADDR     : boolean := c_ENABLE_MGR_FE_INJ_ADDR_HAMMING;
    p_HAMMING_DETECT_DOUBLE: boolean := c_ENABLE_HAMMING_DOUBLE_DETECT
  );
  port(
    -- AMBA AXI clock / reset.
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Capture strobes (1-cycle pulses)
    i_CAP_AW : in std_logic;
    i_CAP_AR : in std_logic;

    -- AXI header sources
    AWID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : in std_logic_vector(7 downto 0);
    AWBURST : in std_logic_vector(1 downto 0);

    ARID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : in std_logic_vector(7 downto 0);
    ARBURST : in std_logic_vector(1 downto 0);

    -- AXI data source
    WVALID : in std_logic;
    WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Frontend injection Hamming correction enables
    i_META_HDR_CORRECT_ERROR : in std_logic := '1';
    i_ADDR_CORRECT_ERROR     : in std_logic := '1';

    -- Outputs to backend
    o_ADDR      : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    o_ID        : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_LENGTH    : out std_logic_vector(7 downto 0);
    o_BURST     : out std_logic_vector(1 downto 0);
    o_OPC_SEND  : out std_logic;
    o_DATA_SEND : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Hamming detection flags (exported to top)
    --  * meta header = opc + id + len + burst
    o_META_HDR_SINGLE_ERR : out std_logic;
    o_META_HDR_DOUBLE_ERR : out std_logic;
    --  * address = addr
    o_ADDR_SINGLE_ERR     : out std_logic;
    o_ADDR_DOUBLE_ERR     : out std_logic
  );
end entity;

architecture rtl of frontend_manager_injection_dp is

  ---------------------------------------------------------------------------------------------
  -- Hamming configuration
  constant INJECT_ERROR_C   : boolean := false;

  ---------------------------------------------------------------------------------------------
  -- Capture qualification

  signal cap_hdr_w : std_logic;

  ---------------------------------------------------------------------------------------------
  -- Input muxing (AW has priority over AR; capture strobes are generated that way)

  signal opc_in_w   : std_logic;
  signal id_in_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal len_in_w   : std_logic_vector(7 downto 0);
  signal burst_in_w : std_logic_vector(1 downto 0);
  signal addr_in_w  : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);

  ---------------------------------------------------------------------------------------------
  -- Meta header bundle: opc + id + len + burst

  constant META_HDR_WIDTH_C : integer := 1 + c_AXI_ID_WIDTH + 8 + 2;

  signal meta_hdr_in_w   : std_logic_vector(META_HDR_WIDTH_C - 1 downto 0);
  signal meta_hdr_out_w  : std_logic_vector(META_HDR_WIDTH_C - 1 downto 0);

  signal opc_send_r_w : std_logic;
  signal id_r_w       : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal len_r_w      : std_logic_vector(7 downto 0);
  signal burst_r_w    : std_logic_vector(1 downto 0);

  signal meta_hdr_single_err_w : std_logic;
  signal meta_hdr_double_err_w : std_logic;

  ---------------------------------------------------------------------------------------------
  -- Address bundle: addr

  signal addr_out_w : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);

  signal addr_single_err_w : std_logic;
  signal addr_double_err_w : std_logic;

begin

  ---------------------------------------------------------------------------------------------
  -- Capture qualification

  cap_hdr_w <= '1' when (i_CAP_AW = '1' or i_CAP_AR = '1') else '0';

  ---------------------------------------------------------------------------------------------
  -- Input muxing

  opc_in_w <= '0' when (i_CAP_AW = '1') else
              '1' when (i_CAP_AR = '1') else
              '0';

  id_in_w <= AWID when (i_CAP_AW = '1') else
             ARID when (i_CAP_AR = '1') else
             (others => '0');

  len_in_w <= AWLEN when (i_CAP_AW = '1') else
              ARLEN when (i_CAP_AR = '1') else
              (others => '0');

  burst_in_w <= AWBURST when (i_CAP_AW = '1') else
                ARBURST when (i_CAP_AR = '1') else
                (others => '0');

  addr_in_w <= AWADDR when (i_CAP_AW = '1') else
               ARADDR when (i_CAP_AR = '1') else
               (others => '0');

  ---------------------------------------------------------------------------------------------
  -- Pack meta header bundle (MSB..LSB): opc | id | len | burst

  meta_hdr_in_w <= opc_in_w & id_in_w & len_in_w & burst_in_w;

  ---------------------------------------------------------------------------------------------
  -- Hamming-protected meta header register

  u_meta_hdr_hamming_reg : hamming_register
    generic map(
      DATA_WIDTH     => META_HDR_WIDTH_C,
      HAMMING_ENABLE => p_USE_HAMMING_META_HDR,
      DETECT_DOUBLE  => p_HAMMING_DETECT_DOUBLE,
      RESET_VALUE    => (META_HDR_WIDTH_C - 1 downto 0 => '0'),
      INJECT_ERROR   => INJECT_ERROR_C
    )
    port map(
      correct_en_i => i_META_HDR_CORRECT_ERROR,
      write_en_i   => cap_hdr_w,
      data_i       => meta_hdr_in_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => meta_hdr_single_err_w,
      double_err_o => meta_hdr_double_err_w,
      enc_data_o   => open,
      data_o       => meta_hdr_out_w
    );

  ---------------------------------------------------------------------------------------------
  -- Hamming-protected address register

  u_addr_hamming_reg : hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_ADDR_WIDTH,
      HAMMING_ENABLE => p_USE_HAMMING_ADDR,
      DETECT_DOUBLE  => p_HAMMING_DETECT_DOUBLE,
      RESET_VALUE    => (c_AXI_ADDR_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => INJECT_ERROR_C
    )
    port map(
      correct_en_i => i_ADDR_CORRECT_ERROR,
      write_en_i   => cap_hdr_w,
      data_i       => addr_in_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => addr_single_err_w,
      double_err_o => addr_double_err_w,
      enc_data_o   => open,
      data_o       => addr_out_w
    );

  ---------------------------------------------------------------------------------------------
  -- Unpack meta header bundle (MSB..LSB): opc | id | len | burst

  opc_send_r_w <= meta_hdr_out_w(META_HDR_WIDTH_C - 1);

  id_r_w <= meta_hdr_out_w(META_HDR_WIDTH_C - 2 downto META_HDR_WIDTH_C - 1 - c_AXI_ID_WIDTH);

  len_r_w <= meta_hdr_out_w(META_HDR_WIDTH_C - 2 - c_AXI_ID_WIDTH downto META_HDR_WIDTH_C - 9 - c_AXI_ID_WIDTH);

  burst_r_w <= meta_hdr_out_w(1 downto 0);

  ---------------------------------------------------------------------------------------------
  -- Drive backend outputs

  o_OPC_SEND <= opc_send_r_w;
  o_ID       <= id_r_w;
  o_LENGTH   <= len_r_w;
  o_BURST    <= burst_r_w;
  o_ADDR     <= addr_out_w;

  ---------------------------------------------------------------------------------------------
  -- Export Hamming detection flags

  o_META_HDR_SINGLE_ERR <= meta_hdr_single_err_w;
  o_META_HDR_DOUBLE_ERR <= meta_hdr_double_err_w;

  o_ADDR_SINGLE_ERR <= addr_single_err_w;
  o_ADDR_DOUBLE_ERR <= addr_double_err_w;

  ---------------------------------------------------------------------------------------------
  -- Preserve original data send behaviour (only meaningful for writes and when WVALID=1)

  o_DATA_SEND <= WDATA when (opc_send_r_w = '0' and WVALID = '1') else (others => '0');

end architecture;
