library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- Builds manager-style NoC request flits for the subordinate isolation TG.
entity subordinate_noc_traffic_gen_datapath is
  generic(
    p_DEST_X : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_DEST_Y : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_X  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1');
    p_USE_HAMMING               : boolean := c_ENABLE_SUB_TG_LFSR_HAMMING;
    p_USE_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_SUB_TG_LFSR_HAMMING_DOUBLE_DETECT;
    p_USE_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_SUB_TG_LFSR_HAMMING_INJECT_ERROR
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    is_read_i : in std_logic;
    id_i      : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    address_i : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    seed_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    step_lfsr_i    : in std_logic;
    lfsr_seeded_i  : in std_logic;
    flit_idx_i     : in unsigned(2 downto 0);

    l_out_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

    OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i : in  std_logic := '1';
    OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o    : out std_logic := '0';
    OBS_SUB_TG_HAM_LFSR_ENC_DATA_o      : out std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0) := (others => '0')
  );
end entity;

architecture rtl of subordinate_noc_traffic_gen_datapath is
  constant C_ZERO_12       : std_logic_vector(11 downto 0) := (others => '0');
  constant C_RESERVED_8    : std_logic_vector(7 downto 0)  := (others => '0');
  constant C_REQUEST_FLAGS : std_logic_vector(2 downto 0)  := (others => '0');

  signal lfsr_state_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_input_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_next_w   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_single_err_w : std_logic;
  signal lfsr_double_err_w : std_logic;
  signal lfsr_enc_data_w   : std_logic_vector(c_AXI_DATA_WIDTH + work.hamming_pkg.get_ecc_size(c_AXI_DATA_WIDTH, p_USE_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal h_dest_w      : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_src_w       : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_interface_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_address_w   : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal payload_w     : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal trailer_w     : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal checksum_w    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal payload_checksum_w : unsigned(c_AXI_DATA_WIDTH - 1 downto 0);
begin
  h_dest_w      <= '1' & p_DEST_X & p_DEST_Y;
  h_src_w       <= '0' & p_SRC_X & p_SRC_Y;
  h_interface_w <= '0' & C_ZERO_12 & id_i & C_RESERVED_8 & "01" & C_REQUEST_FLAGS & is_read_i & '0';
  h_address_w   <= '0' & address_i(c_AXI_ADDR_WIDTH - 1 downto c_AXI_DATA_WIDTH);
  payload_w     <= '0' & lfsr_state_w;
  payload_checksum_w <= unsigned(lfsr_state_w) when is_read_i = '0' else
                        to_unsigned(0, c_AXI_DATA_WIDTH);

  checksum_w <= std_logic_vector(unsigned(h_dest_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_src_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_interface_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_address_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 payload_checksum_w);
  trailer_w <= '1' & checksum_w;

  lfsr_input_w <= seed_i when lfsr_seeded_i = '0' else lfsr_state_w;

  u_lfsr: entity work.subordinate_noc_traffic_gen_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      data_i => lfsr_input_w,
      next_o => lfsr_next_w
    );

  l_out_data_o <= h_dest_w      when flit_idx_i = to_unsigned(0, flit_idx_i'length) else
                  h_src_w       when flit_idx_i = to_unsigned(1, flit_idx_i'length) else
                  h_interface_w when flit_idx_i = to_unsigned(2, flit_idx_i'length) else
                  h_address_w   when flit_idx_i = to_unsigned(3, flit_idx_i'length) else
                  payload_w     when flit_idx_i = to_unsigned(4, flit_idx_i'length) and is_read_i = '0' else
                  trailer_w;

  u_lfsr_state_hamming_register: entity work.hamming_register
    generic map(
      DATA_WIDTH     => c_AXI_DATA_WIDTH,
      HAMMING_ENABLE => p_USE_HAMMING,
      DETECT_DOUBLE  => p_USE_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (c_AXI_DATA_WIDTH - 1 downto 0 => '0'),
      INJECT_ERROR   => p_USE_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => OBS_SUB_TG_HAM_LFSR_CORRECT_ERROR_i,
      write_en_i   => step_lfsr_i,
      data_i       => lfsr_next_w,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => lfsr_single_err_w,
      double_err_o => lfsr_double_err_w,
      enc_data_o   => lfsr_enc_data_w,
      data_o       => lfsr_state_w
    );

  OBS_SUB_TG_HAM_LFSR_SINGLE_ERR_o <= lfsr_single_err_w;
  OBS_SUB_TG_HAM_LFSR_DOUBLE_ERR_o <= lfsr_double_err_w;
  OBS_SUB_TG_HAM_LFSR_ENC_DATA_o   <= lfsr_enc_data_w;
end architecture;
