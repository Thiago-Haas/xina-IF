library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Debuggable datapath: identical behaviour to tg_tm_loopback_datapath,
-- but exposes internal regs for TB console logging.
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

    -- DEBUG
    o_dbg_hdr0  : out std_logic_vector(31 downto 0);
    o_dbg_hdr1  : out std_logic_vector(31 downto 0);
    o_dbg_hdr2  : out std_logic_vector(31 downto 0);
    o_dbg_addr  : out std_logic_vector(31 downto 0);
    o_dbg_opc   : out std_logic;
    o_dbg_ready : out std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_datapath_dbg is
  constant c_OPC_BIT       : integer := 0;
  constant c_TYPE_BIT      : integer := 1;
  constant c_STATUS_LSB    : integer := 2;
  constant c_STATUS_MSB    : integer := 4;
  constant c_BURST_LSB     : integer := 5;
  constant c_BURST_MSB     : integer := 6;
  constant c_LENGTH_LSB    : integer := 7;
  constant c_LENGTH_MSB    : integer := 14;
  constant c_ID_LSB        : integer := 15;
  constant c_ID_MSB        : integer := 19;

  signal r_hdr0, r_hdr1, r_hdr2 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_addr                 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_req_ready            : std_logic := '0';

  signal r_len   : unsigned(7 downto 0) := (others => '0');
  signal r_id    : std_logic_vector(4 downto 0) := (others => '0');
  signal r_burst : std_logic_vector(1 downto 0) := (others => '0');
  signal r_opc   : std_logic := '0';

  constant c_DEPTH : natural := 2**p_MEM_ADDR_BITS;
  type t_mem is array(0 to c_DEPTH-1) of std_logic_vector(31 downto 0);
  signal mem : t_mem := (others => (others => '0'));

  signal r_base_idx : unsigned(p_MEM_ADDR_BITS-1 downto 0) := (others => '0');
  signal r_hold_valid : std_logic := '0';

  signal rd_idx : unsigned(p_MEM_ADDR_BITS-1 downto 0);

begin
  -- DEBUG taps
  o_dbg_hdr0  <= r_hdr0;
  o_dbg_hdr1  <= r_hdr1;
  o_dbg_hdr2  <= r_hdr2;
  o_dbg_addr  <= r_addr;
  o_dbg_opc   <= r_opc;
  o_dbg_ready <= r_req_ready;

  o_req_ready    <= r_req_ready;
  o_req_len      <= r_len;
  o_req_id       <= r_id;
  o_req_burst    <= r_burst;
  o_req_base_idx <= r_base_idx;

  o_req_is_write <= '1' when (r_req_ready = '1' and r_opc = '0') else '0';
  o_req_is_read  <= '1' when (r_req_ready = '1' and r_opc = '1') else '0';

  o_resp_hdr0 <= r_hdr1;
  o_resp_hdr1 <= r_hdr0;

  process(all)
    variable v_hdr2 : std_logic_vector(31 downto 0);
  begin
    v_hdr2 := (others => '0');
    v_hdr2(c_ID_MSB downto c_ID_LSB) := r_id;
    v_hdr2(c_BURST_MSB downto c_BURST_LSB) := r_burst;
    v_hdr2(c_STATUS_MSB downto c_STATUS_LSB) := (others => '0');
    v_hdr2(c_TYPE_BIT) := '1';
    v_hdr2(c_OPC_BIT)  := r_opc;

    if r_opc = '1' then
      v_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB) := std_logic_vector(r_len);
    else
      v_hdr2(c_LENGTH_MSB downto c_LENGTH_LSB) := (others => '0');
    end if;

    o_resp_hdr2 <= v_hdr2;
  end process;

  o_hold_valid <= r_hold_valid;

  rd_idx <= r_base_idx + resize(i_rd_payload_idx, p_MEM_ADDR_BITS);
  o_rd_payload <= mem(to_integer(rd_idx));

  process(ACLK)
    variable v_word   : std_logic_vector(31 downto 0);
    variable v_idx    : unsigned(p_MEM_ADDR_BITS-1 downto 0);
    variable v_payload_words : natural;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_hdr0 <= (others => '0');
        r_hdr1 <= (others => '0');
        r_hdr2 <= (others => '0');
        r_addr <= (others => '0');
        r_req_ready <= '0';
        r_len <= (others => '0');
        r_id <= (others => '0');
        r_burst <= (others => '0');
        r_opc <= '0';
        r_base_idx <= (others => '0');
        r_hold_valid <= '0';
      else
        if i_hold_clr = '1' then
          r_hold_valid <= '0';
        end if;

        if i_cap_en = '1' then
          v_word := i_cap_flit(31 downto 0);

          if i_cap_idx = 0 then
            r_hdr0 <= v_word;
            r_req_ready <= '0';
          elsif i_cap_idx = 1 then
            r_hdr1 <= v_word;
          elsif i_cap_idx = 2 then
            r_hdr2 <= v_word;
            r_opc  <= v_word(c_OPC_BIT);
            r_id   <= v_word(c_ID_MSB downto c_ID_LSB);
            r_len  <= unsigned(v_word(c_LENGTH_MSB downto c_LENGTH_LSB));
            r_burst<= v_word(c_BURST_MSB downto c_BURST_LSB);
          elsif i_cap_idx = 3 then
            r_addr <= v_word;
            v_idx := unsigned(v_word((p_MEM_ADDR_BITS+1) downto 2));
            r_base_idx <= v_idx;
            r_req_ready <= '1';
          else
            if r_opc = '0' then
              v_payload_words := to_integer(resize(r_len, 16)) + 1;
              if to_integer(i_cap_idx) >= 4 and to_integer(i_cap_idx) < 4 + v_payload_words then
                v_idx := r_base_idx + resize(unsigned(i_cap_idx) - 4, p_MEM_ADDR_BITS);
                mem(to_integer(v_idx)) <= v_word;
                r_hold_valid <= '1';
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
