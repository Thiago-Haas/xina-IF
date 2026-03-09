library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_dp is
  generic (
    p_MEM_ADDR_BITS       : natural := 10; -- kept for compatibility; unused
    p_USE_LB_HAMMING               : boolean := c_ENABLE_LB_HAMMING_PROTECTION;
    p_USE_LB_HAMMING_DOUBLE_DETECT : boolean := c_ENABLE_LB_HAMMING_DOUBLE_DETECT;
    p_USE_LB_HAMMING_INJECT_ERROR  : boolean := c_ENABLE_LB_HAMMING_INJECT_ERROR
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_cap_en    : in  std_logic;
    i_cap_flit  : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_cap_last  : in  std_logic;

    o_req_ready     : out std_logic;
    o_req_is_write  : out std_logic;
    o_req_is_read   : out std_logic;
    o_req_len       : out unsigned(7 downto 0);
    o_req_burst     : out std_logic_vector(1 downto 0);
    o_req_base_idx  : out unsigned(p_MEM_ADDR_BITS-1 downto 0);

    i_rd_payload_idx : in  unsigned(7 downto 0);
    o_rd_payload     : out std_logic_vector(31 downto 0);

    o_resp_hdr0 : out std_logic_vector(31 downto 0);
    o_resp_hdr1 : out std_logic_vector(31 downto 0);
    o_resp_hdr2 : out std_logic_vector(31 downto 0);

    -- Hamming observe/correct (same "style" as TG/TM datapaths)
    i_OBS_LB_HAM_BUFFER_CORRECT_ERROR : in  std_logic := '1';
    o_single_err     : out std_logic;
    o_double_err     : out std_logic;
    o_ham_buffer_enc_data : out std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

    -- pulse when payload captured
    o_hold_valid : out std_logic;
    i_hold_clr   : in  std_logic
  );
end entity;

architecture rtl of lb_dp is

  signal r_cap_idx : unsigned(5 downto 0) := (others => '0');
  signal w_payload_cap : std_logic;
  signal w_payload     : std_logic_vector(31 downto 0);

  signal w_single_err  : std_logic;
  signal w_double_err  : std_logic;

  -- optional observability of encoded reg (not exported here, but kept for debug parity with TG)
  -- width = 32 + get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT)
  signal w_enc_payload : std_logic_vector(32 + work.hamming_pkg.get_ecc_size(32, p_USE_LB_HAMMING_DOUBLE_DETECT) - 1 downto 0);

  signal r_payload_dec : std_logic_vector(31 downto 0);

begin

  ------------------------------------------------------------------------------
  -- Minimal DP: no request decode, no header registers
  ------------------------------------------------------------------------------
  o_req_ready    <= '0';
  o_req_is_write <= '0';
  o_req_is_read  <= '0';
  o_req_len      <= (others => '0');
  o_req_burst    <= (others => '0');
  o_req_base_idx <= (others => '0');

  o_resp_hdr0 <= (others => '0');
  o_resp_hdr1 <= (others => '0');
  o_resp_hdr2 <= (others => '0');

  ------------------------------------------------------------------------------
  -- Capture condition: payload at fixed flit index 4 when ctrl=0
  ------------------------------------------------------------------------------
  w_payload_cap <= '1' when (i_cap_en = '1') and
                          (r_cap_idx = to_unsigned(4, r_cap_idx'length)) and
                          (i_cap_flit(i_cap_flit'left) = '0')
                   else '0';

  w_payload <= i_cap_flit(31 downto 0);

  -- Local capture-index counter (kept inside datapath to avoid wide control outputs).
  p_cap_idx: process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_cap_idx <= (others => '0');
      elsif i_cap_en = '1' then
        if (i_cap_flit(i_cap_flit'left) = '1') and (r_cap_idx /= to_unsigned(0, r_cap_idx'length)) then
          r_cap_idx <= (others => '0');
        else
          r_cap_idx <= r_cap_idx + 1;
        end if;
      end if;
    end if;
  end process;

  -- pulse to controller (no reg here)
  o_hold_valid <= w_payload_cap;

  ------------------------------------------------------------------------------
  -- TG-style Hamming-protected 32-bit payload register
  ------------------------------------------------------------------------------
  u_PAYLOAD_REG : entity work.hamming_register
    generic map(
      DATA_WIDTH     => 32,
      HAMMING_ENABLE => p_USE_LB_HAMMING,
      DETECT_DOUBLE  => p_USE_LB_HAMMING_DOUBLE_DETECT,
      RESET_VALUE    => (31 downto 0 => '0'),
      INJECT_ERROR   => p_USE_LB_HAMMING_INJECT_ERROR
    )
    port map(
      correct_en_i => i_OBS_LB_HAM_BUFFER_CORRECT_ERROR,
      write_en_i   => w_payload_cap,
      data_i       => w_payload,
      rstn_i       => ARESETn,
      clk_i        => ACLK,
      single_err_o => w_single_err,
      double_err_o => w_double_err,
      enc_data_o   => w_enc_payload,
      data_o       => r_payload_dec
    );

  -- outputs
  o_single_err <= w_single_err;
  o_double_err <= w_double_err;
  o_ham_buffer_enc_data <= w_enc_payload;

  -- for READ responses, always drive the (decoded) payload
  o_rd_payload <= r_payload_dec;

  -- unused in this minimal datapath
  -- i_cap_last, i_rd_payload_idx, i_hold_clr

end architecture;
