library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Ultra-minimal loopback datapath (NON-DBG)
--  * ONLY stores one 32-bit payload word (register).
--  * No RAM / no header registers / no request decode.
entity lb_dp is
  generic (
    p_MEM_ADDR_BITS : natural := 10  -- kept for compatibility; unused
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_cap_en    : in  std_logic;
    i_cap_flit  : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_cap_idx   : in  unsigned(5 downto 0);
    i_cap_last  : in  std_logic;

    o_req_ready     : out std_logic;
    o_req_is_write  : out std_logic;
    o_req_is_read   : out std_logic;
    o_req_len       : out unsigned(7 downto 0);
    o_req_id        : out std_logic_vector(4 downto 0);
    o_req_burst     : out std_logic_vector(1 downto 0);
    o_req_base_idx  : out unsigned(p_MEM_ADDR_BITS-1 downto 0);

    i_rd_payload_idx : in  unsigned(7 downto 0);
    o_rd_payload     : out std_logic_vector(31 downto 0);

    o_resp_hdr0 : out std_logic_vector(31 downto 0);
    o_resp_hdr1 : out std_logic_vector(31 downto 0);
    o_resp_hdr2 : out std_logic_vector(31 downto 0);

    o_hold_valid : out std_logic;
    i_hold_clr   : in  std_logic
  );
end entity;

architecture rtl of lb_dp is
  signal r_payload    : std_logic_vector(31 downto 0) := (others => '0');
  signal r_hold_valid : std_logic := '0';
begin

  -- No decode in this ultra-min version
  o_req_ready    <= '0';
  o_req_is_write <= '0';
  o_req_is_read  <= '0';
  o_req_len      <= (others => '0');
  o_req_id       <= (others => '0');
  o_req_burst    <= (others => '0');
  o_req_base_idx <= (others => '0');

  -- Controller ignores these headers; keep as zeros
  o_resp_hdr0 <= (others => '0');
  o_resp_hdr1 <= (others => '0');
  o_resp_hdr2 <= (others => '0');

  o_hold_valid <= r_hold_valid;

  -- Payload read: always the stored word (repeat for any index)
  o_rd_payload <= r_payload;

  -- Store payload at fixed flit index 4 when ctrl=0.
  -- Assumed request format: hdr0,hdr1,hdr2,addr,payload0,...,checksum
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_payload    <= (others => '0');
        r_hold_valid <= '0';
      else
        if i_hold_clr = '1' then
          r_hold_valid <= '0';
        end if;

        if i_cap_en = '1' then
          if (i_cap_idx = to_unsigned(4, i_cap_idx'length)) and (i_cap_flit(i_cap_flit'left) = '0') then
            r_payload    <= i_cap_flit(31 downto 0);
            r_hold_valid <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- i_cap_last and i_rd_payload_idx unused intentionally

end architecture;
