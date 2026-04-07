library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_noc_pkg.all;
use work.xina_manager_ni_pkg.all;

-- Ejection datapath (backend receive -> AXI)
--  * Routes backend receive fields onto AXI B/R channels.
--  * No buffering, preserves original behaviour (future: you can add ECC regs here).
entity frontend_manager_ejection_dp is
  port(
    -- Backend receive fields.
    LAST_RECEIVE_DATA_i : in std_logic;
    ID_RECEIVE_i        : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    STATUS_RECEIVE_i    : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
    DATA_RECEIVE_i      : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    CORRUPT_RECEIVE_i   : in std_logic;

    -- From controller.
    BVALID_EN_i : in std_logic;
    RVALID_EN_i : in std_logic;

    -- AXI outputs.
    BVALID : out std_logic;
    BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    RVALID : out std_logic;
    RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    RLAST  : out std_logic;
    RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    CORRUPT_PACKET : out std_logic
  );
end entity;

architecture rtl of frontend_manager_ejection_dp is

  signal bvalid_w : std_logic;
  signal bid_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal bresp_w  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
  signal rvalid_w : std_logic;
  signal rdata_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal rid_w    : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
  signal rresp_w  : std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of bvalid_w : signal is "TRUE";
  attribute DONT_TOUCH of bid_w : signal is "TRUE";
  attribute DONT_TOUCH of bresp_w : signal is "TRUE";
  attribute DONT_TOUCH of rvalid_w : signal is "TRUE";
  attribute DONT_TOUCH of rdata_w : signal is "TRUE";
  attribute DONT_TOUCH of rid_w : signal is "TRUE";
  attribute DONT_TOUCH of rresp_w : signal is "TRUE";

  attribute syn_preserve : boolean;
  attribute syn_preserve of bvalid_w : signal is true;
  attribute syn_preserve of bid_w : signal is true;
  attribute syn_preserve of bresp_w : signal is true;
  attribute syn_preserve of rvalid_w : signal is true;
  attribute syn_preserve of rdata_w : signal is true;
  attribute syn_preserve of rid_w : signal is true;
  attribute syn_preserve of rresp_w : signal is true;
begin

  ---------------------------------------------------------------------------------------------
  -- Corrupt flag mirrors backend

  CORRUPT_PACKET <= CORRUPT_RECEIVE_i;

  ---------------------------------------------------------------------------------------------
  -- Write response (B channel)

  bvalid_w <= BVALID_EN_i;
  bid_w    <= ID_RECEIVE_i     when (BVALID_EN_i = '1') else (others => '0');
  bresp_w  <= STATUS_RECEIVE_i when (BVALID_EN_i = '1') else (others => '0');

  ---------------------------------------------------------------------------------------------
  -- Read response (R channel)

  rvalid_w <= RVALID_EN_i;
  rdata_w  <= DATA_RECEIVE_i   when (RVALID_EN_i = '1') else (others => '0');
  RLAST  <= LAST_RECEIVE_DATA_i;
  rid_w    <= ID_RECEIVE_i     when (RVALID_EN_i = '1') else (others => '0');
  rresp_w  <= STATUS_RECEIVE_i when (RVALID_EN_i = '1') else (others => '0');

  BVALID <= bvalid_w;
  BID    <= bid_w;
  BRESP  <= bresp_w;
  RVALID <= rvalid_w;
  RDATA  <= rdata_w;
  RID    <= rid_w;
  RRESP  <= rresp_w;

end architecture;
