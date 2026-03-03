library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Ejection controller: generates ready/valid for B/R channels.
entity frontend_manager_ejection_ctrl is
  port(
    -- Backend receive indicators
    i_VALID_RECEIVE_DATA : in std_logic;
    i_OPC_RECEIVE        : in std_logic;

    -- AXI ready inputs
    BREADY : in std_logic;
    RREADY : in std_logic;

    -- To backend
    o_READY_RECEIVE_PACKET : out std_logic;
    o_READY_RECEIVE_DATA   : out std_logic;

    -- To DP: valid enables
    o_BVALID_EN : out std_logic;
    o_RVALID_EN : out std_logic
  );
end entity;

architecture rtl of frontend_manager_ejection_ctrl is
begin
  -- Preserve original ready behaviour
  o_READY_RECEIVE_PACKET <= '1' when (i_OPC_RECEIVE = '0' and BREADY = '1') or
                                     (i_OPC_RECEIVE = '1' and RREADY = '1') else '0';

  o_READY_RECEIVE_DATA <= RREADY;

  -- Valid enables (exactly matching original gating)
  o_BVALID_EN <= '1' when (i_OPC_RECEIVE = '0' and i_VALID_RECEIVE_DATA = '1') else '0';
  o_RVALID_EN <= '1' when (i_OPC_RECEIVE = '1' and i_VALID_RECEIVE_DATA = '1') else '0';

end architecture;
