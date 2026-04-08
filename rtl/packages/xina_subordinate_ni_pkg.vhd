library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;

package xina_subordinate_ni_pkg is
  ------------------------------------------------------------------------------
  -- Subordinate NI FT Switches
  ------------------------------------------------------------------------------
  -- Keep this policy shaped like the manager package: frontend, backend
  -- injection, then backend reception. The subordinate backend currently uses
  -- shared generic switches for injection/reception, so aggregate defaults are
  -- provided below for ni_subordinate_top.

  -- Frontend path. These are plain today, but the switches reserve the same
  -- package-level shape used by the manager side.
  constant c_ENABLE_SUB_FE_INJ_META_HDR_HAMMING : boolean := true;
  constant c_ENABLE_SUB_FE_INJ_ADDR_HAMMING     : boolean := true;
  constant c_ENABLE_SUB_FE_INJ_STATUS_TMR       : boolean := true;

  -- Backend injection.
  constant c_ENABLE_SUB_BE_INJ_BUFFER_HAMMING  : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_PKTZ_CTRL_TMR   : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_FLOW_CTRL_TMR   : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_INTEGRITY_CHECK : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_INTEGRITY_TMR   : boolean := true;

  -- Backend reception.
  constant c_ENABLE_SUB_BE_RX_BUFFER_HAMMING        : boolean := true;
  constant c_ENABLE_SUB_BE_RX_INTERFACE_HDR_HAMMING : boolean := true;
  constant c_ENABLE_SUB_BE_RX_DEPKTZ_CTRL_TMR       : boolean := true;
  constant c_ENABLE_SUB_BE_RX_FLOW_CTRL_TMR         : boolean := true;
  constant c_ENABLE_SUB_BE_RX_INTEGRITY_CHECK       : boolean := true;
  constant c_ENABLE_SUB_BE_RX_INTEGRITY_TMR         : boolean := true;

  -- Aggregate defaults used by the current subordinate top generics.
  constant c_ENABLE_SUB_TMR_PACKETIZER      : boolean := c_ENABLE_SUB_BE_INJ_PKTZ_CTRL_TMR and c_ENABLE_SUB_BE_RX_DEPKTZ_CTRL_TMR;
  constant c_ENABLE_SUB_TMR_FLOW_CTRL       : boolean := c_ENABLE_SUB_BE_INJ_FLOW_CTRL_TMR and c_ENABLE_SUB_BE_RX_FLOW_CTRL_TMR;
  constant c_ENABLE_SUB_INTEGRITY_CHECK     : boolean := c_ENABLE_SUB_BE_INJ_INTEGRITY_CHECK and c_ENABLE_SUB_BE_RX_INTEGRITY_CHECK;
  constant c_ENABLE_SUB_TMR_INTEGRITY_CHECK : boolean := c_ENABLE_SUB_BE_INJ_INTEGRITY_TMR and c_ENABLE_SUB_BE_RX_INTEGRITY_TMR;
  constant c_ENABLE_SUB_HAMMING_PROTECTION  : boolean := c_ENABLE_SUB_BE_INJ_BUFFER_HAMMING and c_ENABLE_SUB_BE_RX_BUFFER_HAMMING;
end package;
