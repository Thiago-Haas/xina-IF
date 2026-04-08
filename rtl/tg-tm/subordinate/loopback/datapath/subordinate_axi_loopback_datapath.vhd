library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;

-- Datapath/storage for the subordinate AXI loopback. The control block owns
-- handshakes; this block owns memory contents, ID return fields, and traffic
-- shape checks for the manager-style one-beat accesses.
entity subordinate_axi_loopback_datapath is
  generic(
    p_MEM_ADDR_BITS : natural := 10
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    aw_accept_i : in std_logic;
    w_accept_i  : in std_logic;
    ar_accept_i : in std_logic;

    AWID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    AWADDR  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    AWLEN   : in  std_logic_vector(7 downto 0);
    AWSIZE  : in  std_logic_vector(2 downto 0);
    AWBURST : in  std_logic_vector(1 downto 0);

    WDATA  : in  std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    WLAST  : in  std_logic;

    BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    ARID    : in  std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    ARADDR  : in  std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    ARLEN   : in  std_logic_vector(7 downto 0);
    ARSIZE  : in  std_logic_vector(2 downto 0);
    ARBURST : in  std_logic_vector(1 downto 0);

    RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of subordinate_axi_loopback_datapath is
  constant C_DEPTH : natural := 2 ** p_MEM_ADDR_BITS;
  constant C_AXI_RESP_OKAY : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0) := (others => '0');
  constant C_AXI_LEN_ONE_BEAT : std_logic_vector(7 downto 0) := x"00";
  constant C_AXI_BURST_INCR : std_logic_vector(1 downto 0) := "01";
  -- AXI SIZE encoding is log2(bytes/beat). The current XINA setup uses 32-bit
  -- data, so manager-style traffic is one 4-byte beat: SIZE = 2.
  constant C_AXI_SIZE_32BIT : std_logic_vector(2 downto 0) := "010";

  type mem_t is array (0 to C_DEPTH - 1) of std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal mem_r : mem_t := (others => (others => '0'));
  -- Keep only the memory index between AW and W. The full AXI address and the
  -- unused burst fields are not retained by this one-beat loopback model.
  signal write_index_r : unsigned(p_MEM_ADDR_BITS - 1 downto 0) := (others => '0');
  signal write_id_r    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal bid_r         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal rid_r         : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal rdata_r       : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  function addr_index(addr : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0)) return unsigned is
    variable idx_v : unsigned(p_MEM_ADDR_BITS - 1 downto 0);
  begin
    -- The NoC request carries the upper AXI address word in its address flit.
    -- Use the low bits of that carried word as the local memory index so
    -- consecutive manager-style addresses map to consecutive loopback entries.
    idx_v := unsigned(addr(c_AXI_DATA_WIDTH + p_MEM_ADDR_BITS - 1 downto c_AXI_DATA_WIDTH));
    return idx_v;
  end function;
begin
  BID   <= bid_r;
  BRESP <= C_AXI_RESP_OKAY;
  RID   <= rid_r;
  RDATA <= rdata_r;
  RRESP <= C_AXI_RESP_OKAY;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        write_index_r <= (others => '0');
        write_id_r <= (others => '0');
        bid_r <= (others => '0');
        rid_r <= (others => '0');
        rdata_r <= (others => '0');
      else
        if aw_accept_i = '1' then
          assert AWLEN = C_AXI_LEN_ONE_BEAT
            report "subordinate_axi_loopback expects one-beat AWLEN=0 traffic"
            severity warning;
          assert AWSIZE = C_AXI_SIZE_32BIT
            report "subordinate_axi_loopback expects 32-bit AWSIZE=2 traffic"
            severity warning;
          assert AWBURST = C_AXI_BURST_INCR
            report "subordinate_axi_loopback expects manager-style AWBURST=INCR"
            severity warning;

          write_index_r <= addr_index(AWADDR);
          write_id_r <= AWID;
        end if;

        if w_accept_i = '1' then
          assert WLAST = '1'
            report "subordinate_axi_loopback expects one-beat WLAST=1 traffic"
            severity warning;

          mem_r(to_integer(write_index_r)) <= WDATA;
          bid_r <= write_id_r;
        end if;

        if ar_accept_i = '1' then
          assert ARLEN = C_AXI_LEN_ONE_BEAT
            report "subordinate_axi_loopback expects one-beat ARLEN=0 traffic"
            severity warning;
          assert ARSIZE = C_AXI_SIZE_32BIT
            report "subordinate_axi_loopback expects 32-bit ARSIZE=2 traffic"
            severity warning;
          assert ARBURST = C_AXI_BURST_INCR
            report "subordinate_axi_loopback expects manager-style ARBURST=INCR"
            severity warning;

          rid_r <= ARID;
          rdata_r <= mem_r(to_integer(addr_index(ARADDR)));
        end if;
      end if;
    end if;
  end process;
end architecture;
