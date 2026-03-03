library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;
use work.hamming_pkg.all;

-- Injection datapath (AXI -> backend send)
--  * Holds the REQUEST HEADER registers, protected with Hamming ECC.
--  * Split into two independent Hamming-protected register blocks:
--      1) small header: opc + id + len + burst
--      2) address      : addr
--  * Passes write data to backend (no buffering, preserves original behaviour).
--
-- Naming convention (aligned with backend style):
--  * *_r  : registered elements
--  * *_w  : combinational wires
entity frontend_manager_injection_dp is
  port(
    -- AMBA AXI clock / reset.
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Capture strobes (1-cycle pulses).
    i_CAP_AW : in std_logic;
    i_CAP_AR : in std_logic;

    -- AXI header sources.
    i_AWID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    i_AWADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    i_AWLEN   : in std_logic_vector(7 downto 0);
    i_AWBURST : in std_logic_vector(1 downto 0);

    i_ARID    : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    i_ARADDR  : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    i_ARLEN   : in std_logic_vector(7 downto 0);
    i_ARBURST : in std_logic_vector(1 downto 0);

    -- AXI write data source.
    i_WVALID : in std_logic;
    i_WDATA  : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    -- Outputs to backend.
    o_ADDR      : out std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    o_ID        : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_LENGTH    : out std_logic_vector(7 downto 0);
    o_BURST     : out std_logic_vector(1 downto 0);
    o_OPC_SEND  : out std_logic;
    o_DATA_SEND : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of frontend_manager_injection_dp is

  ---------------------------------------------------------------------------------------------
  -- Hamming configuration (keep simple; can be promoted to generics later)

  constant HAMMING_ENABLE_C : boolean := true;
  constant DETECT_DOUBLE_C  : boolean := true;
  constant INJECT_ERROR_C   : boolean := false;

  ---------------------------------------------------------------------------------------------
  -- Small header bundle: opc + id + len + burst

  constant SMALL_HDR_WIDTH_C : integer := 1 + c_AXI_ID_WIDTH + 8 + 2;

  signal cap_hdr_w       : std_logic;
  signal opc_in_w        : std_logic;
  signal id_in_w         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal len_in_w        : std_logic_vector(7 downto 0);
  signal burst_in_w      : std_logic_vector(1 downto 0);

  signal small_hdr_in_w  : std_logic_vector(SMALL_HDR_WIDTH_C - 1 downto 0);
  signal small_hdr_out_w : std_logic_vector(SMALL_HDR_WIDTH_C - 1 downto 0);

  signal opc_send_w      : std_logic;
  signal id_w            : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal len_w           : std_logic_vector(7 downto 0);
  signal burst_w         : std_logic_vector(1 downto 0);

  -- Optional error flags (left unconnected for now)
  signal small_single_err_w : std_logic;
  signal small_double_err_w : std_logic;

  ---------------------------------------------------------------------------------------------
  -- Address bundle: addr

  signal addr_in_w       : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
  signal addr_out_w      : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);

  signal addr_single_err_w : std_logic;
  signal addr_double_err_w : std_logic;

begin

  ---------------------------------------------------------------------------------------------
  -- Capture qualification

  cap_hdr_w <= '1' when (i_CAP_AW = '1' or i_CAP_AR = '1') else '0';

  ---------------------------------------------------------------------------------------------
  -- Input muxing (AW has priority over AR; capture strobes are generated that way)

  opc_in_w   <= '0' when (i_CAP_AW = '1') else
                '1' when (i_CAP_AR = '1') else
                '0';

  id_in_w    <= i_AWID    when (i_CAP_AW = '1') else
                i_ARID    when (i_CAP_AR = '1') else
                (others => '0');

  len_in_w   <= i_AWLEN   when (i_CAP_AW = '1') else
                i_ARLEN   when (i_CAP_AR = '1') else
                (others => '0');

  burst_in_w <= i_AWBURST when (i_CAP_AW = '1') else
                i_ARBURST when (i_CAP_AR = '1') else
                (others => '0');

  addr_in_w  <= i_AWADDR  when (i_CAP_AW = '1') else
                i_ARADDR  when (i_CAP_AR = '1') else
                (others => '0');

  ---------------------------------------------------------------------------------------------
  -- Pack small header bundle (MSB..LSB): opc | id | len | burst

  small_hdr_in_w <= opc_in_w & id_in_w & len_in_w & burst_in_w;

  ---------------------------------------------------------------------------------------------
  -- Hamming-protected registers

  u_small_hdr_hamming_reg : hamming_register
    generic map(
      DATA_WIDTH     => SMALL_HDR_WIDTH_C,
      HAMMING_ENABLE => HAMMING_ENABLE_C,
      DETECT_DOUBLE  => DETECT_DOUBLE_C,
      RESET_VALUE    => (SMALL_HDR_WIDTH_C - 1 downto 0 => '0'),
      INJECT_ERROR   => INJECT_ERROR_C
    )
    port map(
      correct_en_i => '1',
      write_en_i   => cap_hdr_w,
      data_i       => small_hdr_in_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => small_single_err_w,
      double_err_o => small_double_err_w,
      enc_data_o   => open,
      data_o       => small_hdr_out_w
    );

  u_addr_hamming_reg : hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_ADDR_WIDTH,
      HAMMING_ENABLE => HAMMING_ENABLE_C,
      DETECT_DOUBLE  => DETECT_DOUBLE_C,
      RESET_VALUE    => (c_AXI_ADDR_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => INJECT_ERROR_C
    )
    port map(
      correct_en_i => '1',
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
  -- Unpack small header bundle (MSB..LSB): opc | id | len | burst

  opc_send_w <= small_hdr_out_w(SMALL_HDR_WIDTH_C - 1);

  id_w       <= small_hdr_out_w(SMALL_HDR_WIDTH_C - 2 downto SMALL_HDR_WIDTH_C - 1 - c_AXI_ID_WIDTH);

  len_w      <= small_hdr_out_w(SMALL_HDR_WIDTH_C - 2 - c_AXI_ID_WIDTH downto SMALL_HDR_WIDTH_C - 9 - c_AXI_ID_WIDTH);

  burst_w    <= small_hdr_out_w(1 downto 0);

  ---------------------------------------------------------------------------------------------
  -- Drive backend outputs

  o_OPC_SEND <= opc_send_w;
  o_ID       <= id_w;
  o_LENGTH   <= len_w;
  o_BURST    <= burst_w;
  o_ADDR     <= addr_out_w;

  ---------------------------------------------------------------------------------------------
  -- Preserve original data-send behaviour:
  -- only meaningful for writes and only when WVALID=1, otherwise zeros.

  o_DATA_SEND <= i_WDATA when (opc_send_w = '0' and i_WVALID = '1') else (others => '0');

end architecture;
