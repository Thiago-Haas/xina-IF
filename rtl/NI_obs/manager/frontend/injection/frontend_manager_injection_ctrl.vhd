library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Injection controller: decides when to capture AW/AR header into DP and drives
-- all injection-side handshakes/valids.
entity frontend_manager_injection_ctrl is
  port(
    -- Clock / reset (reset currently unused to preserve original behaviour)
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- AXI address/write/read inputs
    AWVALID : in  std_logic;
    ARVALID : in  std_logic;
    WVALID  : in  std_logic;
    WLAST   : in  std_logic;

    -- Backend ready
    i_READY_SEND_PACKET : in  std_logic;
    i_READY_SEND_DATA   : in  std_logic;

    -- From DP: current opcode (0=write, 1=read)
    i_OPC_SEND_R : in  std_logic;

    -- To DP: capture strobes (AW has priority over AR)
    o_CAP_AW : out std_logic;
    o_CAP_AR : out std_logic;

    -- To backend (injection)
    o_START_SEND_PACKET : out std_logic;
    o_VALID_SEND_DATA   : out std_logic;
    o_LAST_SEND_DATA    : out std_logic;

    -- To AXI ready signals
    AWREADY : out std_logic;
    ARREADY : out std_logic;
    WREADY  : out std_logic
  );
end entity;

architecture rtl of frontend_manager_injection_ctrl is
begin
  -- Preserve original ready behaviour
  AWREADY <= i_READY_SEND_PACKET;
  ARREADY <= i_READY_SEND_PACKET;
  WREADY  <= i_READY_SEND_DATA;

  -- Preserve original packet start behaviour (combinational, independent of ready)
  o_START_SEND_PACKET <= '1' when (AWVALID = '1' or ARVALID = '1') else '0';

  -- Capture request header into datapath only when backend is ready for a packet.
  -- Preserve original priority: AW over AR when both asserted.
  o_CAP_AW <= '1' when (i_READY_SEND_PACKET = '1' and AWVALID = '1') else '0';
  o_CAP_AR <= '1' when (i_READY_SEND_PACKET = '1' and AWVALID = '0' and ARVALID = '1') else '0';

  -- Preserve original data valid/last behaviour (only for writes, using stored opc)
  o_VALID_SEND_DATA <= '1' when (i_OPC_SEND_R = '0' and WVALID = '1') else '0';
  o_LAST_SEND_DATA  <= '1' when (i_OPC_SEND_R = '0' and WLAST  = '1') else '0';

end architecture;
