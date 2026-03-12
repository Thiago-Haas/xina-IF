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
    CAP_AW_i : in std_logic;
    CAP_AR_i : in std_logic;

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
    META_HDR_CORRECT_ERROR_i : in std_logic := '1';
    ADDR_CORRECT_ERROR_i     : in std_logic := '1';

    -- Outputs to backend
    ADDR_o      : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ID_o        : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    LENGTH_o    : out std_logic_vector(7 downto 0);
    BURST_o     : out std_logic_vector(1 downto 0);
    OPC_SEND_o  : out std_logic;
    DATA_SEND_o : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Hamming detection flags (exported to top)
    --  * meta header = opc + id + len + burst
    META_HDR_SINGLE_ERR_o : out std_logic;
    META_HDR_DOUBLE_ERR_o : out std_logic;
    --  * address = addr
    ADDR_SINGLE_ERR_o     : out std_logic;
    ADDR_DOUBLE_ERR_o     : out std_logic;
    META_HDR_ENC_DATA_o   : out std_logic_vector((1 + c_AXI_ID_WIDTH + 8 + 2) + work.hamming_pkg.get_ecc_size((1 + c_AXI_ID_WIDTH + 8 + 2), p_HAMMING_DETECT_DOUBLE) - 1 downto 0);
    ADDR_ENC_DATA_o       : out std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0)
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
  signal meta_hdr_enc_w        : std_logic_vector(META_HDR_WIDTH_C + work.hamming_pkg.get_ecc_size(META_HDR_WIDTH_C, p_HAMMING_DETECT_DOUBLE) - 1 downto 0);

  ---------------------------------------------------------------------------------------------
  -- Address bundle: addr

  signal addr_out_w : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);

  signal addr_single_err_w : std_logic;
  signal addr_double_err_w : std_logic;
  signal addr_enc_w        : std_logic_vector(c_AXI_ADDR_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_ADDR_WIDTH, p_HAMMING_DETECT_DOUBLE) - 1 downto 0);

begin

  ---------------------------------------------------------------------------------------------
  -- Capture qualification

  cap_hdr_w <= '1' when (CAP_AW_i = '1' or CAP_AR_i = '1') else '0';

  ---------------------------------------------------------------------------------------------
  -- Input muxing

  opc_in_w <= '0' when (CAP_AW_i = '1') else
              '1' when (CAP_AR_i = '1') else
              '0';

  id_in_w <= AWID when (CAP_AW_i = '1') else
             ARID when (CAP_AR_i = '1') else
             (others => '0');

  len_in_w <= AWLEN when (CAP_AW_i = '1') else
              ARLEN when (CAP_AR_i = '1') else
              (others => '0');

  burst_in_w <= AWBURST when (CAP_AW_i = '1') else
                ARBURST when (CAP_AR_i = '1') else
                (others => '0');

  addr_in_w <= AWADDR when (CAP_AW_i = '1') else
               ARADDR when (CAP_AR_i = '1') else
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
      correct_en_i => META_HDR_CORRECT_ERROR_i,
      write_en_i   => cap_hdr_w,
      data_i       => meta_hdr_in_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => meta_hdr_single_err_w,
      double_err_o => meta_hdr_double_err_w,
      enc_data_o   => meta_hdr_enc_w,
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
      correct_en_i => ADDR_CORRECT_ERROR_i,
      write_en_i   => cap_hdr_w,
      data_i       => addr_in_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => addr_single_err_w,
      double_err_o => addr_double_err_w,
      enc_data_o   => addr_enc_w,
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

  OPC_SEND_o <= opc_send_r_w;
  ID_o       <= id_r_w;
  LENGTH_o   <= len_r_w;
  BURST_o    <= burst_r_w;
  ADDR_o     <= addr_out_w;

  ---------------------------------------------------------------------------------------------
  -- Export Hamming detection flags

  META_HDR_SINGLE_ERR_o <= meta_hdr_single_err_w;
  META_HDR_DOUBLE_ERR_o <= meta_hdr_double_err_w;

  ADDR_SINGLE_ERR_o <= addr_single_err_w;
  ADDR_DOUBLE_ERR_o <= addr_double_err_w;
  META_HDR_ENC_DATA_o <= meta_hdr_enc_w;
  ADDR_ENC_DATA_o <= addr_enc_w;

  ---------------------------------------------------------------------------------------------
  -- Preserve original data send behaviour (only meaningful for writes and when WVALID=1)

  DATA_SEND_o <= WDATA when (opc_send_r_w = '0' and WVALID = '1') else (others => '0');

end architecture;
