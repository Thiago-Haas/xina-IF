library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

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
begin

  ---------------------------------------------------------------------------------------------
  -- Corrupt flag mirrors backend

  CORRUPT_PACKET <= CORRUPT_RECEIVE_i;

  ---------------------------------------------------------------------------------------------
  -- Write response (B channel)

  BVALID <= BVALID_EN_i;
  BID    <= ID_RECEIVE_i     when (BVALID_EN_i = '1') else (others => '0');
  BRESP  <= STATUS_RECEIVE_i when (BVALID_EN_i = '1') else (others => '0');

  ---------------------------------------------------------------------------------------------
  -- Read response (R channel)

  RVALID <= RVALID_EN_i;
  RDATA  <= DATA_RECEIVE_i   when (RVALID_EN_i = '1') else (others => '0');
  RLAST  <= LAST_RECEIVE_DATA_i;
  RID    <= ID_RECEIVE_i     when (RVALID_EN_i = '1') else (others => '0');
  RRESP  <= STATUS_RECEIVE_i when (RVALID_EN_i = '1') else (others => '0');

end architecture;
