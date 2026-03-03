library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Ejection datapath (backend receive -> AXI B/R)
--  * Routes backend receive fields onto AXI B/R channels.
--  * Intentionally no buffering/registration (preserves original behaviour).
entity frontend_manager_ejection_dp is
  port(
    -- Backend receive fields.
    i_LAST_RECEIVE_DATA : in std_logic;
    i_ID_RECEIVE        : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    i_STATUS_RECEIVE    : in std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);
    i_DATA_RECEIVE      : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    i_CORRUPT_RECEIVE   : in std_logic;

    -- From controller.
    i_BVALID_EN : in std_logic;
    i_RVALID_EN : in std_logic;

    -- AXI outputs.
    o_BVALID : out std_logic;
    o_BID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_BRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    o_RVALID : out std_logic;
    o_RDATA  : out std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
    o_RLAST  : out std_logic;
    o_RID    : out std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    o_RRESP  : out std_logic_vector(c_AXI_RESP_WIDTH - 1 downto 0);

    o_CORRUPT_PACKET : out std_logic
  );
end entity;

architecture rtl of frontend_manager_ejection_dp is
begin

  ---------------------------------------------------------------------------------------------
  -- Direct mirrors

  o_RLAST          <= i_LAST_RECEIVE_DATA;
  o_CORRUPT_PACKET <= i_CORRUPT_RECEIVE;

  ---------------------------------------------------------------------------------------------
  -- Write response (B channel)

  o_BVALID <= i_BVALID_EN;
  o_BID    <= i_ID_RECEIVE     when (i_BVALID_EN = '1') else (others => '0');
  o_BRESP  <= i_STATUS_RECEIVE when (i_BVALID_EN = '1') else (others => '0');

  ---------------------------------------------------------------------------------------------
  -- Read response (R channel)

  o_RVALID <= i_RVALID_EN;
  o_RDATA  <= i_DATA_RECEIVE   when (i_RVALID_EN = '1') else (others => '0');
  o_RID    <= i_ID_RECEIVE     when (i_RVALID_EN = '1') else (others => '0');
  o_RRESP  <= i_STATUS_RECEIVE when (i_RVALID_EN = '1') else (others => '0');

end architecture;
