library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Injection controller (AXI -> backend send)
--  * Generates AXI ready signals.
--  * Generates backend injection control strobes.
--  * Holds ONLY control/handshake logic (future TMR region).
--  * Opcode is stored in the datapath with the other header fields (future ECC region).
--
-- Naming convention (aligned with backend style):
--  * i_*  : inputs
--  * o_*  : outputs
--  * *_r  : registered elements
--  * *_w  : combinational wires
entity frontend_manager_injection_ctrl is
  port(
    -- AMBA AXI clock / reset.
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- AXI request/data inputs.
    AWVALID_i : in std_logic;
    ARVALID_i : in std_logic;
    WVALID_i  : in std_logic;
    WLAST_i   : in std_logic;

    -- Backend ready.
    READY_SEND_PACKET_i : in std_logic;
    READY_SEND_DATA_i   : in std_logic;

    -- From datapath: registered opcode (0=write, 1=read).
    OPC_SEND_R_i : in std_logic;

    -- To datapath: capture strobes (AW has priority over AR).
    CAP_AW_o : out std_logic;
    CAP_AR_o : out std_logic;

    -- To backend (injection side).
    START_SEND_PACKET_o : out std_logic;
    VALID_SEND_DATA_o   : out std_logic;
    LAST_SEND_DATA_o    : out std_logic;

    -- To AXI ready signals.
    AWREADY_o : out std_logic;
    ARREADY_o : out std_logic;
    WREADY_o  : out std_logic
  );
end entity;

architecture rtl of frontend_manager_injection_ctrl is

  signal cap_aw_w : std_logic;
  signal cap_ar_w : std_logic;

begin

  ---------------------------------------------------------------------------------------------
  -- Capture qualification (preserves original priority: AW over AR)

  cap_aw_w <= '1' when (READY_SEND_PACKET_i = '1' and AWVALID_i = '1') else '0';
  cap_ar_w <= '1' when (READY_SEND_PACKET_i = '1' and AWVALID_i = '0' and ARVALID_i = '1') else '0';

  CAP_AW_o <= cap_aw_w;
  CAP_AR_o <= cap_ar_w;

  ---------------------------------------------------------------------------------------------
  -- Ready signals to AXI (preserve original behaviour)

  AWREADY_o <= READY_SEND_PACKET_i;
  ARREADY_o <= READY_SEND_PACKET_i;
  WREADY_o  <= READY_SEND_DATA_i;

  ---------------------------------------------------------------------------------------------
  -- Backend injection control (preserve original combinational behaviour)

  START_SEND_PACKET_o <= '1' when (AWVALID_i = '1' or ARVALID_i = '1') else '0';
  VALID_SEND_DATA_o   <= '1' when (OPC_SEND_R_i = '0' and WVALID_i = '1') else '0';
  LAST_SEND_DATA_o    <= '1' when (OPC_SEND_R_i = '0' and WLAST_i  = '1') else '0';

end architecture;
