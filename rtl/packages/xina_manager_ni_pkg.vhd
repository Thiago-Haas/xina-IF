library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;

package xina_manager_ni_pkg is
  ------------------------------------------------------------------------------
  -- Manager NI FT Switches
  ------------------------------------------------------------------------------
  -- Frontend injection.
  constant c_ENABLE_MGR_FE_INJ_META_HDR_HAMMING : boolean := true;
  constant c_ENABLE_MGR_FE_INJ_ADDR_HAMMING     : boolean := true;

  -- Backend injection.
  constant c_ENABLE_MGR_BE_INJ_BUFFER_HAMMING  : boolean := true;
  constant c_ENABLE_MGR_BE_INJ_PKTZ_CTRL_TMR   : boolean := true;
  constant c_ENABLE_MGR_BE_INJ_FLOW_CTRL_TMR   : boolean := true;
  constant c_ENABLE_MGR_BE_INJ_INTEGRITY_CHECK : boolean := true;
  constant c_ENABLE_MGR_BE_INJ_INTEGRITY_TMR   : boolean := true;

  -- Backend reception.
  constant c_ENABLE_MGR_BE_RX_BUFFER_HAMMING        : boolean := true;
  constant c_ENABLE_MGR_BE_RX_INTERFACE_HDR_HAMMING : boolean := true;
  constant c_ENABLE_MGR_BE_RX_DEPKTZ_CTRL_TMR       : boolean := true;
  constant c_ENABLE_MGR_BE_RX_FLOW_CTRL_TMR         : boolean := true;
  constant c_ENABLE_MGR_BE_RX_INTEGRITY_CHECK       : boolean := true;
  constant c_ENABLE_MGR_BE_RX_INTEGRITY_TMR         : boolean := true;

  ------------------------------------------------------------------------------
  -- TG/TM/LB Manager Self-Test FT Configuration
  ------------------------------------------------------------------------------
  -- Runtime correction for TG/TM/LB/NI/OBS follows the UART D/E command fanout.
  -- The two UART shell FT blocks are the exception: correction is forced on in
  -- RTL so the control/reporting path cannot disable itself.

  -- TG.
  constant c_ENABLE_TG_CTRL_TMR              : boolean := true;
  constant c_ENABLE_TG_HAMMING_PROTECTION    : boolean := true;
  constant c_ENABLE_TG_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_TG_HAMMING_INJECT_ERROR  : boolean := false; -- Fault INJECTION

  -- TM.
  constant c_ENABLE_TM_CTRL_TMR              : boolean := true;
  constant c_ENABLE_TM_HAMMING_PROTECTION    : boolean := true;
  constant c_ENABLE_TM_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_TM_HAMMING_INJECT_ERROR  : boolean := false; -- Fault INJECTION
  constant c_ENABLE_TM_RECEIVED_COUNTER_HAMMING : boolean := true;
  constant c_ENABLE_TM_CORRECT_COUNTER_HAMMING  : boolean := true;
  constant c_TM_COUNTER_WIDTH                   : natural := 32;
  constant c_ENABLE_TM_TXN_COUNTER_HAMMING      : boolean := c_ENABLE_TM_RECEIVED_COUNTER_HAMMING;
  constant c_TM_TRANSACTION_COUNTER_WIDTH       : natural := c_TM_COUNTER_WIDTH;
  -- Number of TM completed packets between periodic UART reports.
  constant c_TM_UART_REPORT_PERIOD_PACKETS   : positive := 100;
  -- UART FLAGS field width. Keep nibble-aligned so TM hex formatting stays aligned.
  constant c_TM_UART_FLAGS_WIDTH             : natural := 44;

  -- Loopback.
  constant c_ENABLE_LB_CTRL_TMR              : boolean := true;
  constant c_ENABLE_LB_HAMMING_PROTECTION    : boolean := true;
  constant c_ENABLE_LB_HAMMING_DOUBLE_DETECT : boolean := true;
  constant c_ENABLE_LB_HAMMING_INJECT_ERROR  : boolean := false; -- Fault INJECTION

  -- Shared manager/self-test observability blocks.
  constant c_ENABLE_OBS_START_DONE_CTRL_TMR : boolean := true;

  -- UART shell FT blocks. Their correction is forced on in RTL.
  constant c_ENABLE_OBS_UART_COMMAND_CTRL_TMR    : boolean := true;
  constant c_ENABLE_OBS_UART_ENCODE_CRITICAL_TMR : boolean := true;
end package;
