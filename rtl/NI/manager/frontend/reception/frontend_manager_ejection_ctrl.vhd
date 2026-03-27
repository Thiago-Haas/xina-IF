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

  signal ready_receive_packet_w : std_logic;
  signal ready_receive_data_w   : std_logic;
  signal bvalid_en_w            : std_logic;
  signal rvalid_en_w            : std_logic;

  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of ready_receive_packet_w : signal is "TRUE";
  attribute DONT_TOUCH of ready_receive_data_w : signal is "TRUE";
  attribute DONT_TOUCH of bvalid_en_w : signal is "TRUE";
  attribute DONT_TOUCH of rvalid_en_w : signal is "TRUE";

  attribute syn_preserve : boolean;
  attribute syn_preserve of ready_receive_packet_w : signal is true;
  attribute syn_preserve of ready_receive_data_w : signal is true;
  attribute syn_preserve of bvalid_en_w : signal is true;
  attribute syn_preserve of rvalid_en_w : signal is true;
begin

  ---------------------------------------------------------------------------------------------
  -- Ready back to backend (preserve original behaviour)

  ready_receive_packet_w <= '1' when (OPC_RECEIVE_i = '0' and BREADY = '1') or
                                     (OPC_RECEIVE_i = '1' and RREADY = '1') else '0';

  ready_receive_data_w <= RREADY;

  ---------------------------------------------------------------------------------------------
  -- Enables to drive AXI channels (preserve original behaviour)

  bvalid_en_w <= '1' when (OPC_RECEIVE_i = '0' and VALID_RECEIVE_DATA_i = '1') else '0';
  rvalid_en_w <= '1' when (OPC_RECEIVE_i = '1' and VALID_RECEIVE_DATA_i = '1') else '0';

  READY_RECEIVE_PACKET_o <= ready_receive_packet_w;
  READY_RECEIVE_DATA_o   <= ready_receive_data_w;
  BVALID_EN_o            <= bvalid_en_w;
  RVALID_EN_o            <= rvalid_en_w;

end architecture;
