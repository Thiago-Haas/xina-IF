library IEEE;
use IEEE.std_logic_1164.all;

library work;
use work.xina_ni_ft_pkg.all;

-- Injection controller (AXI -> backend send)
--  * Generates AXI ready signals.
--  * Generates backend injection control strobes.
--  * Holds SMALL control register(s) (intended for future TMR hardening).
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

    -- To datapath: capture strobes (AW has priority over AR).
    o_CAP_AW : out std_logic;
    o_CAP_AR : out std_logic;

    -- To datapath/backend: registered opcode (0=write, 1=read).
    o_OPC_SEND : out std_logic;

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

  -- Registered opcode (SMALL control register).
  signal opc_send_r : std_logic;

  -- Combinational capture wires.
  signal cap_aw_w : std_logic;
  signal cap_ar_w : std_logic;

begin

  ---------------------------------------------------------------------------------------------
  -- Combinational capture qualification (preserves original priority: AW over AR)

  cap_aw_w <= '1' when (i_READY_SEND_PACKET = '1' and i_AWVALID = '1') else '0';
  cap_ar_w <= '1' when (i_READY_SEND_PACKET = '1' and i_AWVALID = '0' and i_ARVALID = '1') else '0';

  o_CAP_AW <= cap_aw_w;
  o_CAP_AR <= cap_ar_w;

  ---------------------------------------------------------------------------------------------
  -- Opcode register (intended for future TMR)
  -- Matches original behaviour:
  --   * updated only when backend can accept a packet header
  --   * AW has priority if both AWVALID/ARVALID are asserted

  process (all)
  begin
    if (ARESETn = '0') then
      opc_send_r <= '0';
    elsif rising_edge(ACLK) then
      if (i_READY_SEND_PACKET = '1') then
        if (i_AWVALID = '1') then
          opc_send_r <= '0';
        elsif (i_ARVALID = '1') then
          opc_send_r <= '1';
        end if;
      end if;
    end if;
  end process;

  o_OPC_SEND <= opc_send_r;

  ---------------------------------------------------------------------------------------------
  -- Ready signals to AXI (preserve original behaviour)

  o_AWREADY <= i_READY_SEND_PACKET;
  o_ARREADY <= i_READY_SEND_PACKET;
  o_WREADY  <= i_READY_SEND_DATA;

  ---------------------------------------------------------------------------------------------
  -- Backend injection control (preserve original combinational behaviour)

  o_START_SEND_PACKET <= '1' when (i_AWVALID = '1' or i_ARVALID = '1') else '0';
  o_VALID_SEND_DATA   <= '1' when (opc_send_r = '0' and i_WVALID = '1') else '0';
  o_LAST_SEND_DATA    <= '1' when (opc_send_r = '0' and i_WLAST  = '1') else '0';

end architecture;
