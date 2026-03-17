# Selftest FT Correction And Signal Map

This document summarizes which FT blocks are controlled by the selftest UART commands `D` and `E`, where they live in the RTL, what hierarchical block name they use in simulation, and which `FLAGS` output bit(s) represent their error reporting.

Current behavior:
- `D` drives the correction fanout low
- `E` drives the correction fanout high
- the testbench currently sends `D` after reset by default
- it only sends `E` if `G_ENABLE_OBS_AFTER_RESET = true`

Main control path:
1. `tb_tg_tm_lb_selftest_top` sends `D` / `E`
2. `selftest_uart_command_control` decodes the command into `command_enable`
3. `selftest_uart_command_datapath` fans `command_enable` out to all `OBS_*_CORRECT_ERROR_o`
4. `selftest_obs_uart_encode_block` forwards those enables into `tg_tm_lb_selftest_top`
5. `tg_tm_lb_selftest_top` forwards them into `tg_tm_lb_system_top`
6. `tg_tm_lb_system_top` forwards them into TG, TM, LB, and NI blocks

Reference files for the control fanout:
- [tb_tg_tm_lb_selftest_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/tb_tg_tm_lb_selftest_top.vhd)
- [uart_command_control.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/uart/command/uart_command_control.vhd)
- [uart_command_datapath.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/uart/command/uart_command_datapath.vhd)
- [uart_encode_block.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/uart/uart_encode_block.vhd)
- [README_uart_observability.md](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/uart/README_uart_observability.md)
- [tg_tm_lb_selftest_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/tg_tm_lb_selftest_top.vhd)
- [tg_tm_lb_system_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/system/tg_tm_lb_system_top.vhd)

Notes:
- `FLAGS` is now a 40-bit UART vector, printed as 10 hex digits.
- Bits `39..37` are reserved.
- All manager-side correction paths now follow `D` / `E`; none remain hardwired disabled.
- Backend reception depacketizer control TMR is now surfaced into the same observability map as the other FT blocks.

---

## TM

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Traffic monitor control | TMR | `OBS_TM_TMR_CTRL_CORRECT_ERROR_i` | `31` | [traffic_mon_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/traffic_mon/traffic_mon_top.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_traffic_mon_top/u_traffic_mon_control_tmr` |
| Traffic monitor expected-value register | Hamming | `OBS_TM_HAM_BUFFER_CORRECT_ERROR_i` | `30` single, `29` double | [traffic_mon_datapath.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/traffic_mon/datapath/traffic_mon_datapath.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_traffic_mon_top/u_traffic_mon_datapath/u_expected_value_hamming_register` |
| Traffic monitor transaction counter | Hamming | `OBS_TM_HAM_TXN_COUNTER_CORRECT_ERROR_i` | `28` single, `27` double | [traffic_mon_datapath_counter_ham.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/traffic_mon/datapath/traffic_mon_datapath_counter_ham.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_traffic_mon_top/u_traffic_mon_datapath_counter_ham/u_transaction_counter_hamming_register` |
| TM comparison mismatch | Comparator status | not a correction-controlled FT block | `33` | [traffic_mon_datapath.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/traffic_mon/datapath/traffic_mon_datapath.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_traffic_mon_top/u_traffic_mon_datapath/u_traffic_mon_datapath_compare` |

---

## LB

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Loopback control | TMR | `OBS_LB_TMR_CTRL_CORRECT_ERROR_i` | `26` | [loopback_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/loopback/loopback_top.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_loopback_top/u_loopback_control_tmr` |
| Loopback payload register | Hamming | `OBS_LB_HAM_BUFFER_CORRECT_ERROR_i` | `25` single, `24` double | [loopback_datapath.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/loopback/datapath/loopback_datapath.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_loopback_top/u_loopback_datapath/u_payload_hamming_register` |

---

## TG

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Traffic generator control | TMR | `OBS_TG_TMR_CTRL_CORRECT_ERROR_i` | `23` | [traffic_gen_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/traffic_gen/traffic_gen_top.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_traffic_gen_top/u_traffic_gen_control_tmr` |
| Traffic generator state register | Hamming | `OBS_TG_HAM_BUFFER_CORRECT_ERROR_i` | `22` single, `21` double | [traffic_gen_datapath.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/traffic_gen/datapath/traffic_gen_datapath.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_traffic_gen_top/u_traffic_gen_datapath/u_state_hamming_register` |

---

## NI

### Frontend

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Frontend injection metadata header | Hamming | `OBS_FE_INJ_META_HDR_CORRECT_ERROR_i` | `20` single, `19` double | [frontend_manager_injection_dp.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/frontend/injection/frontend_manager_injection_dp.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_frontend_manager/u_frontend_manager_injection_dp` |
| Frontend injection address | Hamming | `OBS_FE_INJ_ADDR_CORRECT_ERROR_i` | `18` single, `17` double | [frontend_manager_injection_dp.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/frontend/injection/frontend_manager_injection_dp.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_frontend_manager/u_frontend_manager_injection_dp` |

### Backend Injection

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Backend injection packetizer control | TMR | `OBS_BE_INJ_TMR_PKTZ_CTRL_CORRECT_ERROR_i` | `10` | [backend_manager_packetizer_control_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/backend/injection/backend_manager_packetizer_control_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_injection/u_backend_manager_packetizer_control_tmr` |
| Backend injection FIFO data path | Hamming | `OBS_BE_INJ_HAM_BUFFER_CORRECT_ERROR_i` | `16` single, `15` double | [buffer_fifo_ham.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/buffer_fifo_ham.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_injection/u_buffer_fifo_ham` |
| Backend injection FIFO control | TMR | `OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i` | `14` | [buffer_fifo_ham_ctrl_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/buffer_fifo_ham_ctrl_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_injection/u_buffer_fifo_ham/u_buffer_fifo_ham_ctrl_tmr` |
| Backend injection integrity accumulator | Hamming | `OBS_BE_INJ_HAM_INTEGRITY_CORRECT_ERROR_i` | `13` single, `12` double | [integrity_control_send_hamming.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/integrity_control_send_hamming.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_injection/u_integrity_control_send_hamming/u_checksum_hamming_register` |
| Backend injection flow control | TMR | `OBS_BE_INJ_TMR_FLOW_CTRL_CORRECT_ERROR_i` | `11` | [send_control_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/send_control_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_injection/u_send_control_tmr` |

### Backend Reception

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Backend reception depacketizer control | TMR | `OBS_BE_RX_TMR_DEPKTZ_CTRL_CORRECT_ERROR_i` | `7` | [backend_manager_depacketizer_control_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/backend/reception/backend_manager_depacketizer_control_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception/u_backend_manager_depacketizer_control_tmr` |
| Backend reception FIFO data path | Hamming | `OBS_BE_RX_HAM_BUFFER_CORRECT_ERROR_i` | `9` single, `8` double | [buffer_fifo_ham.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/buffer_fifo_ham.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception/u_buffer_fifo_ham` |
| Backend reception FIFO control | TMR | `OBS_BE_RX_TMR_HAM_BUFFER_CTRL_CORRECT_ERROR_i` | `6` | [buffer_fifo_ham_ctrl_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/buffer_fifo_ham_ctrl_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception/u_buffer_fifo_ham/u_buffer_fifo_ham_ctrl_tmr` |
| Backend reception interface header | Hamming | `OBS_BE_RX_HAM_INTERFACE_HDR_CORRECT_ERROR_i` | `5` single, `4` double | [backend_manager_reception_h_interface_reg.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/backend/reception/backend_manager_reception_h_interface_reg.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception/u_backend_manager_reception_h_interface_reg/u_h_interface_hamming_register` |
| Backend reception integrity accumulator | Hamming | `OBS_BE_RX_HAM_INTEGRITY_CORRECT_ERROR_i` | `2` single, `1` double | [integrity_control_receive_hamming.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/integrity_control_receive_hamming.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception/u_integrity_control_receive_hamming/u_checksum_hamming_register` |
| Backend reception integrity corrupt flag | Integrity status | not a correction-controlled FT block | `3` | [backend_manager_reception.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/backend/reception/backend_manager_reception.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception` |
| Backend reception flow control | TMR | `OBS_BE_RX_TMR_FLOW_CTRL_CORRECT_ERROR_i` | `0` | [receive_control_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/common/ft/receive_control_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top/u_backend_manager/u_backend_manager_reception/u_receive_control_tmr` |
| NI corrupt packet | System status | not a correction-controlled FT block | `32` | [ni_manager_top.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/NI/manager/ni_manager_top.vhd) | `u_tg_tm_lb_selftest_top/u_tg_tm_lb_system_top/u_ni_manager_top` |

---

## OBS

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| Start/done experiment control | TMR | `OBS_START_DONE_CTRL_TMR_CORRECT_ERROR_i` | `34` | [selftest_start_done_control_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/control/selftest_start_done_control_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_start_done_control_tmr` |

---

## UART

| FT block | Type | OBS control signal | FLAGS bit(s) | RTL file | Hierarchical block in sim/logs |
| --- | --- | --- | --- | --- | --- |
| UART command control | TMR | `OBS_UART_COMMAND_CTRL_TMR_CORRECT_ERROR_o` fanout source | `35` | [uart_command_control_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/uart/command/uart_command_control_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_selftest_obs_uart_encode_block/u_obs_enable_block/u_uart_command_control_tmr` |
| UART encode critical path | TMR | `OBS_UART_ENCODE_CRITICAL_TMR_CORRECT_ERROR_o` fanout source | `36` | [uart_encode_critical_tmr.vhd](/home/haas/Documents/GitHub/xina-IF/rtl/tg-tm/manager/selftest/uart/core/uart_encode_critical_tmr.vhd) | `u_tg_tm_lb_selftest_top/u_selftest_obs_uart_encode_block/u_uart_encode_core/u_uart_encode_critical_tmr` |

---

## Summary

All FT correction paths used by the manager/selftest flow are now controlled by `D` / `E`, and all of the FT error sources surfaced into the selftest UART path now have dedicated `FLAGS` bits.
