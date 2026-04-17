# Closed-Box UART Observability Protocol

This document describes how observability messages are encoded by hardware in the `manager_tg_tm_lb_selftest_*` closed-box flow.

## 1) Message Types (same encoding path)

Both periodic and event reports use the same UART encoding path:
- Nibble extraction from `fault_data`
- Hex-to-ASCII conversion (`utf8_hex`)
- Label + hex text framing
- LF (`\n`) line termination

So the console can use the same byte decoding logic for both.

## 2) UART Line Formats

`TM` width is parameterized by:
- `c_TM_TRANSACTION_COUNTER_WIDTH` in `xina_manager_ni_pkg` (`rtl/packages/xina_manager_ni_pkg.vhd`)
- Current value: `32`, so `TM` is 8 hex digits.

Hex digits used for `TM`:
- `TM_HEX_DIGITS = ceil(c_TM_TRANSACTION_COUNTER_WIDTH / 4)`

### Periodic line
```text
MGR RX=<RX_HEX> OK=<OK_HEX>\n
```
Example (32-bit):
```text
MGR RX=00002710 OK=00002710
```

### Event base line
```text
MGR RX=<RX_HEX> OK=<OK_HEX> FLAGS=<10_HEX>\n
```
Example:
```text
MGR RX=000000FE OK=000000FD FLAGS=0001010000
```

### Optional event encoded-data line (only if a Hamming source is selected)
```text
ENC SRC=<1_HEX> DATA=<20_HEX>\n
```

## 3) Visual Frame Layout

Base internal frame in UART encode control:

```text
bit [135:0] fault_data

 [135 ................. 104][103 .................... 72][71 ................. 40][39 ............ 0]
 +-------------------------+----------------------------+-------------------------+------------------+
 | TM correct count        | TM received count          | reserved / alignment    | FLAGS[39:0]      |
 +-------------------------+----------------------------+-------------------------+------------------+
```

`RX` and `OK` are each placed above the flags field, using the manager TM counter width.

## 4) FLAGS Bit Map (37 used bits in a 40-bit vector)

`FLAGS` is printed as 10 hex chars (40 bits). Bit mapping:

| FLAG bit | Signal |
|---|---|
| 39..37 | Reserved (0) |
| 36 | `i_OBS_UART_ENCODE_CRITICAL_TMR_ERROR` |
| 35 | `i_OBS_UART_COMMAND_CTRL_TMR_ERROR` |
| 34 | `i_OBS_START_DONE_CTRL_TMR_ERROR` |
| 33 | `i_tm_comparison_mismatch` |
| 32 | `i_NI_CORRUPT_PACKET` |
| 31 | `i_OBS_TM_TMR_CTRL_ERROR` |
| 30 | `i_OBS_TM_HAM_BUFFER_SINGLE_ERR` |
| 29 | `i_OBS_TM_HAM_BUFFER_DOUBLE_ERR` |
| 28 | `i_OBS_TM_HAM_TXN_COUNTER_SINGLE_ERR` |
| 27 | `i_OBS_TM_HAM_TXN_COUNTER_DOUBLE_ERR` |
| 26 | `i_OBS_LB_TMR_CTRL_ERROR` |
| 25 | `i_OBS_LB_HAM_BUFFER_SINGLE_ERR` |
| 24 | `i_OBS_LB_HAM_BUFFER_DOUBLE_ERR` |
| 23 | `i_OBS_TG_TMR_CTRL_ERROR` |
| 22 | `i_OBS_TG_HAM_BUFFER_SINGLE_ERR` |
| 21 | `i_OBS_TG_HAM_BUFFER_DOUBLE_ERR` |
| 20 | `i_OBS_FE_INJ_META_HDR_SINGLE_ERR` |
| 19 | `i_OBS_FE_INJ_META_HDR_DOUBLE_ERR` |
| 18 | `i_OBS_FE_INJ_ADDR_SINGLE_ERR` |
| 17 | `i_OBS_FE_INJ_ADDR_DOUBLE_ERR` |
| 16 | `i_OBS_BE_INJ_HAM_BUFFER_SINGLE_ERR` |
| 15 | `i_OBS_BE_INJ_HAM_BUFFER_DOUBLE_ERR` |
| 14 | `i_OBS_BE_INJ_TMR_HAM_BUFFER_CTRL_ERROR` |
| 13 | `i_OBS_BE_INJ_HAM_INTEGRITY_SINGLE_ERR` |
| 12 | `i_OBS_BE_INJ_HAM_INTEGRITY_DOUBLE_ERR` |
| 11 | `i_OBS_BE_INJ_TMR_FLOW_CTRL_ERROR` |
| 10 | `i_OBS_BE_INJ_TMR_PKTZ_CTRL_ERROR` |
| 9  | `i_OBS_BE_RX_HAM_BUFFER_SINGLE_ERR` |
| 8  | `i_OBS_BE_RX_HAM_BUFFER_DOUBLE_ERR` |
| 7  | `i_OBS_BE_RX_TMR_DEPKTZ_CTRL_ERROR` |
| 6  | `i_OBS_BE_RX_TMR_HAM_BUFFER_CTRL_ERROR` |
| 5  | `i_OBS_BE_RX_HAM_INTERFACE_HDR_SINGLE_ERR` |
| 4  | `i_OBS_BE_RX_HAM_INTERFACE_HDR_DOUBLE_ERR` |
| 3  | `i_OBS_BE_RX_INTEGRITY_CORRUPT` |
| 2  | `i_OBS_BE_RX_HAM_INTEGRITY_SINGLE_ERR` |
| 1  | `i_OBS_BE_RX_HAM_INTEGRITY_DOUBLE_ERR` |
| 0  | `i_OBS_BE_RX_TMR_FLOW_CTRL_ERROR` |

## 5) ENC Source (`SRC`) Map

When an event matches one of these sources, one extra line may be emitted:

| SRC hex | Encoded data source |
|---|---|
| `1` | TM buffer Hamming `ENC_DATA` |
| `2` | TM received-counter Hamming `ENC_DATA` |
| `C` | TM correct-counter Hamming `ENC_DATA` |
| `3` | LB buffer Hamming `ENC_DATA` |
| `4` | TG buffer Hamming `ENC_DATA` |
| `5` | FE INJ meta/header Hamming `ENC_DATA` |
| `6` | FE INJ address Hamming `ENC_DATA` |
| `7` | BE INJ buffer Hamming `ENC_DATA` |
| `8` | BE INJ integrity Hamming `ENC_DATA` |
| `9` | BE RX buffer Hamming `ENC_DATA` |
| `A` | BE RX interface-header Hamming `ENC_DATA` |
| `B` | BE RX integrity Hamming `ENC_DATA` |

## 6) Console Decoder Guidance

Recommended parser strategy:
- Decode bytes to text by lines (split on LF).
- Parse labels, not fixed positions:
  - `RX=...`
  - `OK=...`
  - optional `FLAGS=...`
  - optional `ENC SRC=... DATA=...`
- Treat `RX` / `OK` lengths as variable, driven by the hardware counter width.

This keeps the same console decoder working across 24-bit, 32-bit, or other TM counter widths.
