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
    i_AWVALID : in std_logic;
    i_ARVALID : in std_logic;
    i_WVALID  : in std_logic;
    i_WLAST   : in std_logic;

    -- Backend ready.
    i_READY_SEND_PACKET : in std_logic;
    i_READY_SEND_DATA   : in std_logic;

    -- From datapath: registered opcode (0=write, 1=read).
    i_OPC_SEND_R : in std_logic;

    -- To datapath: capture strobes (AW has priority over AR).
    o_CAP_AW : out std_logic;
    o_CAP_AR : out std_logic;

    -- To backend (injection side).
    o_START_SEND_PACKET : out std_logic;
    o_VALID_SEND_DATA   : out std_logic;
    o_LAST_SEND_DATA    : out std_logic;

    -- To AXI ready signals.
    o_AWREADY : out std_logic;
    o_ARREADY : out std_logic;
    o_WREADY  : out std_logic
  );
end entity;

architecture rtl of frontend_manager_injection_ctrl is

  signal cap_aw_w : std_logic;
  signal cap_ar_w : std_logic;

begin

  ---------------------------------------------------------------------------------------------
  -- Capture qualification (preserves original priority: AW over AR)

  cap_aw_w <= '1' when (i_READY_SEND_PACKET = '1' and i_AWVALID = '1') else '0';
  cap_ar_w <= '1' when (i_READY_SEND_PACKET = '1' and i_AWVALID = '0' and i_ARVALID = '1') else '0';

  o_CAP_AW <= cap_aw_w;
  o_CAP_AR <= cap_ar_w;

  ---------------------------------------------------------------------------------------------
  -- Ready signals to AXI (preserve original behaviour)

  o_AWREADY <= i_READY_SEND_PACKET;
  o_ARREADY <= i_READY_SEND_PACKET;
  o_WREADY  <= i_READY_SEND_DATA;

  ---------------------------------------------------------------------------------------------
  -- Backend injection control (preserve original combinational behaviour)

  o_START_SEND_PACKET <= '1' when (i_AWVALID = '1' or i_ARVALID = '1') else '0';
  o_VALID_SEND_DATA   <= '1' when (i_OPC_SEND_R = '0' and i_WVALID = '1') else '0';
  o_LAST_SEND_DATA    <= '1' when (i_OPC_SEND_R = '0' and i_WLAST  = '1') else '0';

end architecture;
