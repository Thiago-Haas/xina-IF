library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Ejection datapath: routes backend receive fields onto AXI B/R channels.
entity frontend_manager_ejection_dp is
  port(
    -- Backend receive fields
    i_LAST_RECEIVE_DATA  : in std_logic;
    i_ID_RECEIVE         : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    i_STATUS_RECEIVE     : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
    i_DATA_RECEIVE       : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    i_CORRUPT_RECEIVE    : in std_logic;

    -- From controller
    i_BVALID_EN : in std_logic;
    i_RVALID_EN : in std_logic;

    -- AXI outputs
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
begin
  -- Preserve original behaviour: RLAST always mirrors i_LAST_RECEIVE_DATA
  RLAST <= i_LAST_RECEIVE_DATA;

  -- Corrupt flag mirrors backend
  CORRUPT_PACKET <= i_CORRUPT_RECEIVE;

  -- Write response
  BVALID <= i_BVALID_EN;
  BID    <= i_ID_RECEIVE     when i_BVALID_EN = '1' else (others => '0');
  BRESP  <= i_STATUS_RECEIVE when i_BVALID_EN = '1' else (others => '0');

  -- Read response
  RVALID <= i_RVALID_EN;
  RDATA  <= i_DATA_RECEIVE   when i_RVALID_EN = '1' else (others => '0');
  RID    <= i_ID_RECEIVE     when i_RVALID_EN = '1' else (others => '0');
  RRESP  <= i_STATUS_RECEIVE when i_RVALID_EN = '1' else (others => '0');

end architecture;
