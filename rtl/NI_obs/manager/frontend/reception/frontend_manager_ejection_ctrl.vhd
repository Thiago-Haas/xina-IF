library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Ejection controller (backend receive -> AXI)
--  * Generates backend ready signals.
--  * Generates enable strobes for datapath to drive B/R outputs.
entity frontend_manager_ejection_ctrl is
  port(
    -- Backend receive indicators.
    VALID_RECEIVE_DATA_i : in std_logic;
    OPC_RECEIVE_i        : in std_logic;

    -- AXI ready inputs.
    BREADY : in std_logic;
    RREADY : in std_logic;

    -- To backend.
    READY_RECEIVE_PACKET_o : out std_logic;
    READY_RECEIVE_DATA_o   : out std_logic;

    -- To datapath: enables to drive AXI channels.
    BVALID_EN_o : out std_logic;
    RVALID_EN_o : out std_logic
  );
end entity;

architecture rtl of frontend_manager_ejection_ctrl is
begin

  ---------------------------------------------------------------------------------------------
  -- Ready back to backend (preserve original behaviour)

  READY_RECEIVE_PACKET_o <= '1' when (OPC_RECEIVE_i = '0' and BREADY = '1') or
                                     (OPC_RECEIVE_i = '1' and RREADY = '1') else '0';

  READY_RECEIVE_DATA_o <= RREADY;

  ---------------------------------------------------------------------------------------------
  -- Enables to drive AXI channels (preserve original behaviour)

  BVALID_EN_o <= '1' when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_DATA_i = '1') else '0';
  RVALID_EN_o <= '1' when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_DATA_i = '1') else '0';

end architecture;
