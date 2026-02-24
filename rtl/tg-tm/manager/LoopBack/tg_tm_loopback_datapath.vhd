library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Datapath for a synthesizeable NoC-side loopback (non-debug).
-- Resource-optimized version:
--  * No inferred RAM/BRAM.
--  * Stores payload in a SINGLE 32-bit register.
--  * Repeats that payload for any READ beat.
--  * Keeps only minimal header fields needed to rebuild responses.
--
-- Behaviour is aligned with the working debug loopback:
--  * Capture hdr0/hdr1/hdr2/address and (for WRITE) payload words.
--  * Response hdr0/hdr1 swapped; hdr2 rebuilt (STATUS=OK).
--  * WRITE response has LEN=0 (no payload). READ mirrors request LEN.
--
entity tg_tm_loopback_datapath is
  generic (
    p_MEM_ADDR_BITS : natural := 10  -- kept for interface compatibility (no RAM used)
  );
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Request capture interface (from controller)
    i_cap_en    : in  std_logic;
    i_cap_flit  : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_cap_idx   : in  unsigned(5 downto 0);
    i_cap_last  : in  std_logic;

    -- Decoded request summary (to controller)
    o_req_ready     : out std_logic;
    o_req_is_write  : out std_logic;
    o_req_is_read   : out std_logic;
    o_req_len       : out unsigned(7 downto 0);
    o_req_id        : out std_logic_vector(4 downto 0);
    o_req_burst     : out std_logic_vector(1 downto 0);
    o_req_base_idx  : out unsigned(p_MEM_ADDR_BITS-1 downto 0);

    -- Payload access for response streaming
    i_rd_payload_idx : in  unsigned(7 downto 0);
    o_rd_payload     : out std_logic_vector(31 downto 0);

    -- Response header outputs
    o_resp_hdr0 : out std_logic_vector(31 downto 0);
    o_resp_hdr1 : out std_logic_vector(31 downto 0);
    o_resp_hdr2 : out std_logic_vector(31 downto 0);

    -- Availability tracking
    o_hold_valid : out std_logic;
    i_hold_clr   : in  std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_datapath is

  -- Bit layout (matches working TBs / NI format)
  constant c_TYPE_BIT     : integer := 0;
  constant c_OPC_BIT      : integer := 1;
  constant c_STATUS_LSB   : integer := 2;
  constant c_STATUS_MSB   : integer := 4;
  constant c_BURST_LSB    : integer := 5;
  constant c_BURST_MSB    : integer := 6;
  constant c_LENGTH_LSB   : integer := 7;
  constant c_LENGTH_MSB   : integer := 14;
  constant c_ID_LSB       : integer := 15;
  constant c_ID_MSB       : integer := 19;

  -- Minimal request storage
  signal r_hdr0, r_hdr1 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_len          : unsigned(7 downto 0) := (others => '0');
  signal r_id           : std_logic_vector(4 downto 0) := (others => '0');
  signal r_burst        : std_logic_vector(1 downto 0) := (others => '0');
  signal r_opc          : std_logic := '0';
  signal r_req_ready    : std_logic := '0';

  -- Ultra-light payload storage
  signal r_payload      : std_logic_vector(31 downto 0) := (others => '0');
  signal r_hold_valid   : std_logic := '0';

  function mk_hdr2(
    opc   : std_logic;
    id    : std_logic_vector(4 downto 0);
    len   : unsigned(7 downto 0);
    burst : std_logic_vector(1 downto 0)
  ) return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := (others => '0');
  begin
    v(c_ID_MSB downto c_ID_LSB) := id;
    v(c_LENGTH_MSB downto c_LENGTH_LSB) := std_logic_vector(len);
    v(c_BURST_MSB downto c_BURST_LSB) := burst;
    v(c_STATUS_MSB downto c_STATUS_LSB) := "000"; -- OK
    v(c_OPC_BIT)  := opc;
    v(c_TYPE_BIT) := '0';
    return v;
  end function;

begin

  -- request summary
  o_req_ready    <= r_req_ready;
  o_req_len      <= r_len;
  o_req_id       <= r_id;
  o_req_burst    <= r_burst;
  o_req_base_idx <= (others => '0'); -- no RAM used

  o_req_is_write <= '1' when (r_req_ready='1' and r_opc='0') else '0';
  o_req_is_read  <= '1' when (r_req_ready='1' and r_opc='1') else '0';

  -- response hdr0/hdr1 swap
  o_resp_hdr0 <= r_hdr1;
  o_resp_hdr1 <= r_hdr0;

  -- response hdr2 rebuild
  process(all)
    variable v : std_logic_vector(31 downto 0);
  begin
    v := mk_hdr2(r_opc, r_id, r_len, r_burst);

    if r_opc = '0' then
      -- WRITE response: TYPE=1, OPC=0, LEN=0
      v(c_TYPE_BIT) := '1';
      v(c_OPC_BIT)  := '0';
      v(c_LENGTH_MSB downto c_LENGTH_LSB) := (others => '0');
    else
      -- READ response: TYPE=0, OPC=1, LEN=req_len
      v(c_TYPE_BIT) := '0';
      v(c_OPC_BIT)  := '1';
    end if;

    o_resp_hdr2 <= v;
  end process;

  -- payload output (repeat stored word for any beat)
  o_rd_payload <= r_payload;

  -- availability tracking
  o_hold_valid <= r_hold_valid;

  -- capture
  process(ACLK)
    variable v_word : std_logic_vector(31 downto 0);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_hdr0 <= (others => '0');
        r_hdr1 <= (others => '0');
        r_len  <= (others => '0');
        r_id   <= (others => '0');
        r_burst<= (others => '0');
        r_opc  <= '0';
        r_req_ready <= '0';
        r_payload <= (others => '0');
        r_hold_valid <= '0';
      else
        if i_hold_clr = '1' then
          r_hold_valid <= '0';
        end if;

        if i_cap_en = '1' then
          v_word := i_cap_flit(31 downto 0);

          case to_integer(i_cap_idx) is
            when 0 =>
              r_hdr0 <= v_word;
              r_req_ready <= '0';
            when 1 =>
              r_hdr1 <= v_word;
            when 2 =>
              r_opc   <= v_word(c_OPC_BIT);
              r_id    <= v_word(c_ID_MSB downto c_ID_LSB);
              r_len   <= unsigned(v_word(c_LENGTH_MSB downto c_LENGTH_LSB));
              r_burst <= v_word(c_BURST_MSB downto c_BURST_LSB);
            when 3 =>
              -- address flit (not used in this minimal build)
              r_req_ready <= '1';
            when others =>
              -- payload flits for WRITE (ctrl must be 0); keep latest word only
              if (r_opc = '0') and (i_cap_flit(i_cap_flit'left) = '0') then
                r_payload <= v_word;
                r_hold_valid <= '1';
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;

  -- i_cap_last and i_rd_payload_idx are intentionally unused in this minimal version.

end architecture;
