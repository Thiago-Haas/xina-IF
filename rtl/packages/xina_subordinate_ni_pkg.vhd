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

  -- Closed subordinate endpoint controllers used by the isolation TG/TM/LB.
  constant c_ENABLE_SUB_TG_CTRL_TMR : boolean := true;
  constant c_ENABLE_SUB_TM_CTRL_TMR : boolean := true;
  constant c_ENABLE_SUB_LB_CTRL_TMR : boolean := true;
  constant c_ENABLE_SUB_TG_LFSR_HAMMING : boolean := true;
  constant c_ENABLE_SUB_TG_LFSR_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_SUB_TG_LFSR_HAMMING_INJECT_ERROR  : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_TM_LFSR_HAMMING : boolean := true;
  constant c_ENABLE_SUB_TM_LFSR_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_SUB_TM_LFSR_HAMMING_INJECT_ERROR  : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_TM_TXN_COUNTER_HAMMING : boolean := true;
  constant c_ENABLE_SUB_TM_CORRECT_COUNTER_HAMMING : boolean := true;
  constant c_SUB_TM_TRANSACTION_COUNTER_WIDTH  : natural := 32;
  -- Number of TM completed packets between periodic UART reports.
  constant c_SUB_TM_UART_REPORT_PERIOD_PACKETS : positive := 400;
  -- UART FLAGS field width. Keep nibble-aligned like the manager OBS report.
  constant c_SUB_TM_UART_FLAGS_WIDTH           : natural := 56;
  constant c_ENABLE_SUB_OBS_START_GO_CTRL_TMR  : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_COMMAND_CTRL_TMR    : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_ENCODE_CRITICAL_TMR : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_RX_COUNT_HAMMING : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_CORRECT_COUNT_HAMMING : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_FLAGS_SEEN_HAMMING : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_EVENT_FLAGS_HAMMING : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_REPORT_FLAGS_HAMMING : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_SUB_OBS_UART_RX_COUNT_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_OBS_UART_CORRECT_COUNT_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_OBS_UART_FLAGS_SEEN_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_OBS_UART_EVENT_FLAGS_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_OBS_UART_REPORT_FLAGS_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_LB_PAYLOAD_HAMMING : boolean := true;
  constant c_ENABLE_SUB_LB_RDATA_HAMMING   : boolean := true;
  constant c_ENABLE_SUB_LB_ID_STATE_HAMMING : boolean := true;
  constant c_ENABLE_SUB_LB_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_SUB_LB_PAYLOAD_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_LB_RDATA_HAMMING_INJECT_ERROR   : boolean := false; -- Fault INJECTION
  constant c_ENABLE_SUB_LB_ID_STATE_HAMMING_INJECT_ERROR : boolean := false; -- Fault INJECTION

  -- Backend injection.
  constant c_ENABLE_SUB_BE_INJ_BUFFER_HAMMING  : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_PKTZ_CTRL_TMR   : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_FLOW_CTRL_TMR   : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_INTEGRITY_CHECK : boolean := true;
  constant c_ENABLE_SUB_BE_INJ_INTEGRITY_TMR   : boolean := true;

  -- Backend reception.
  constant c_ENABLE_SUB_BE_RX_BUFFER_HAMMING        : boolean := true;
  constant c_ENABLE_SUB_BE_RX_SRC_HDR_HAMMING       : boolean := true;
  constant c_ENABLE_SUB_BE_RX_INTERFACE_HDR_HAMMING : boolean := true;
  constant c_ENABLE_SUB_BE_RX_ADDRESS_HDR_HAMMING   : boolean := true;
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
