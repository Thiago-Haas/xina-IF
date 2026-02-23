library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Debuggable datapath:
--  * captures request flits (hdr0,hdr1,hdr2,addr,[payload],checksum)
--  * decodes fields following the SAME bit layout used by the *working TBs*
--  * stores WRITE payload into a small word RAM
--  * provides READ payload words from that RAM
--  * builds response hdr0/hdr1 swap + hdr2 exactly like TBs
entity tg_tm_loopback_datapath_dbg is
  generic (
    p_MEM_ADDR_BITS : natural := 10
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
    i_hold_clr   : in  std_logic;

    -- DEBUG taps
    o_dbg_hdr0  : out std_logic_vector(31 downto 0);
    o_dbg_hdr1  : out std_logic_vector(31 downto 0);
    o_dbg_hdr2  : out std_logic_vector(31 downto 0);
    o_dbg_addr  : out std_logic_vector(31 downto 0);
    o_dbg_opc   : out std_logic;
    o_dbg_ready : out std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_datapath_dbg is

  -- Bit layout (MUST match backend_manager_reception + TBs)
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

  signal r_hdr0, r_hdr1, r_hdr2 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_addr                 : std_logic_vector(31 downto 0) := (others => '0');

  signal r_len   : unsigned(7 downto 0) := (others => '0');
  signal r_id    : std_logic_vector(4 downto 0) := (others => '0');
  signal r_burst : std_logic_vector(1 downto 0) := (others => '0');
  signal r_opc   : std_logic := '0';

  signal r_req_ready  : std_logic := '0';

  -- simple word RAM
  constant c_DEPTH : natural := 2**p_MEM_ADDR_BITS;
  type t_mem is array(0 to c_DEPTH-1) of std_logic_vector(31 downto 0);
  signal mem : t_mem := (others => (others => '0'));

  signal r_base_idx   : unsigned(p_MEM_ADDR_BITS-1 downto 0) := (others => '0');
  signal r_hold_valid : std_logic := '0';

  signal rd_idx : unsigned(p_MEM_ADDR_BITS-1 downto 0);

begin

  -- debug taps
  o_dbg_hdr0  <= r_hdr0;
  o_dbg_hdr1  <= r_hdr1;
  o_dbg_hdr2  <= r_hdr2;
  o_dbg_addr  <= r_addr;
  o_dbg_opc   <= r_opc;
  o_dbg_ready <= r_req_ready;

  -- request summary
  o_req_ready    <= r_req_ready;
  o_req_len      <= r_len;
  o_req_id       <= r_id;
  o_req_burst    <= r_burst;
  o_req_base_idx <= r_base_idx;

  o_req_is_write <= '1' when (r_req_ready='1' and r_opc='0') else '0';
  o_req_is_read  <= '1' when (r_req_ready='1' and r_opc='1') else '0';

  -- response swap
  o_resp_hdr0 <= r_hdr1;
  o_resp_hdr1 <= r_hdr0;

  -- response hdr2 build (TB-like)
  process(all)
    variable v : std_logic_vector(31 downto 0);
  begin
    v := r_hdr2;  -- start from request hdr2 (keeps ID/LEN/BURST)

    -- STATUS always OK
    v(c_STATUS_MSB downto c_STATUS_LSB) := "000";

    if r_opc = '0' then
      -- WRITE response (like tb_tg_ni_manager_loopback_dbg): TYPE=1, OPC=0, LEN=0
      v(c_TYPE_BIT) := '1';
      v(c_OPC_BIT)  := '0';
      v(c_LENGTH_MSB downto c_LENGTH_LSB) := (others => '0');
    else
      -- READ response (like tb_tm_ni_manager_loopback_dbg): keep OPC=1, LEN=req_len, force bit0=0
      v(c_TYPE_BIT) := '0';
      v(c_OPC_BIT)  := '1';
      -- keep LEN as-is
    end if;

    o_resp_hdr2 <= v;
  end process;

  o_hold_valid <= r_hold_valid;

  -- payload read
  rd_idx <= r_base_idx + resize(i_rd_payload_idx, p_MEM_ADDR_BITS);
  o_rd_payload <= mem(to_integer(rd_idx));

  -- capture request + store write payload
  process(ACLK)
    variable v_word   : std_logic_vector(31 downto 0);
    variable v_idx    : unsigned(p_MEM_ADDR_BITS-1 downto 0);
    variable v_widx9  : unsigned(8 downto 0);
    variable v_pld_words : unsigned(8 downto 0);
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_hdr0 <= (others => '0');
        r_hdr1 <= (others => '0');
        r_hdr2 <= (others => '0');
        r_addr <= (others => '0');

        r_len <= (others => '0');
        r_id <= (others => '0');
        r_burst <= (others => '0');
        r_opc <= '0';

        r_req_ready <= '0';
        r_base_idx <= (others => '0');
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
              r_hdr2 <= v_word;
              r_opc  <= v_word(c_OPC_BIT);
              r_id   <= v_word(c_ID_MSB downto c_ID_LSB);
              r_len  <= unsigned(v_word(c_LENGTH_MSB downto c_LENGTH_LSB));
              r_burst<= v_word(c_BURST_MSB downto c_BURST_LSB);
            when 3 =>
              r_addr <= v_word;
              -- base index = word address (addr>>2) truncated to memory depth
              v_idx := unsigned(v_word((p_MEM_ADDR_BITS+1) downto 2));
              r_base_idx <= v_idx;
              r_req_ready <= '1';
            when others =>
              -- payload for WRITE requests: idx>=4 and ctrl=0
              if (r_opc = '0') and (i_cap_flit(i_cap_flit'left) = '0') then
                v_pld_words := unsigned('0' & r_len) + 1; -- LEN+1
                v_widx9 := resize(i_cap_idx, 9) - to_unsigned(4, 9);
                if v_widx9 < v_pld_words then
                  v_idx := r_base_idx + resize(v_widx9, p_MEM_ADDR_BITS);
                  mem(to_integer(v_idx)) <= v_word;
                  r_hold_valid <= '1';
                end if;
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;
