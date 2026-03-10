library IEEE;
library work;

use IEEE.std_logic_1164.all;

package xina_ni_ft_pkg is
    -- AMBA-AXI attributes.
    constant c_AXI_DATA_WIDTH: natural := 32;
    constant c_AXI_ADDR_WIDTH: natural := c_AXI_DATA_WIDTH * 2; -- First half: Operation address. Second half: IP address (XXYY).
    constant c_AXI_ID_WIDTH  : natural := 5;  -- This constant corresponds to "ID_W_WIDTH" and "ID_R_WIDTH".
    constant c_AXI_RESP_WIDTH: natural := 3;  -- This constant corresponds to "BRESP_WIDTH" and "RRESP_WIDTH".

    -- Interface attributes.
    constant c_FLIT_WIDTH        : natural  := c_AXI_DATA_WIDTH + 1;
    constant c_BUFFER_DEPTH      : positive := 8;
    
    -- Grouped FT switches (global defaults).
    constant c_ENABLE_TMR_PACKETIZER          : boolean := true;
    constant c_ENABLE_TMR_FLOW_CTRL           : boolean := true;
    constant c_ENABLE_INTEGRITY_CHECK         : boolean := true;
    constant c_ENABLE_TMR_INTEGRITY_CHECK     : boolean := true;
    constant c_ENABLE_HAMMING_PROTECTION      : boolean := true;
    constant c_ENABLE_HAMMING_DOUBLE_DETECT   : boolean := true;

    -- Manager frontend ECC toggles.
    constant c_ENABLE_MGR_FE_INJ_META_HDR_HAMMING : boolean := true;
    constant c_ENABLE_MGR_FE_INJ_ADDR_HAMMING     : boolean := true;

    -- Manager backend injection ECC/TMR toggles.
    constant c_ENABLE_MGR_BE_INJ_BUFFER_HAMMING    : boolean := true;
    constant c_ENABLE_MGR_BE_INJ_PKTZ_CTRL_TMR     : boolean := true;
    constant c_ENABLE_MGR_BE_INJ_FLOW_CTRL_TMR     : boolean := true;
    constant c_ENABLE_MGR_BE_INJ_INTEGRITY_CHECK   : boolean := true;
    constant c_ENABLE_MGR_BE_INJ_INTEGRITY_TMR     : boolean := true;

    -- Manager backend reception ECC/TMR toggles.
    constant c_ENABLE_MGR_BE_RX_BUFFER_HAMMING     : boolean := true;
    constant c_ENABLE_MGR_BE_RX_INTERFACE_HDR_HAMMING : boolean := true;
    constant c_ENABLE_MGR_BE_RX_DEPKTZ_CTRL_TMR    : boolean := true;
    constant c_ENABLE_MGR_BE_RX_FLOW_CTRL_TMR      : boolean := true;
    constant c_ENABLE_MGR_BE_RX_INTEGRITY_CHECK    : boolean := true;
    constant c_ENABLE_MGR_BE_RX_INTEGRITY_TMR      : boolean := true;

    -- TG ECC/TMR toggles.
    constant c_ENABLE_TG_CTRL_TMR                : boolean := true;
    constant c_ENABLE_TG_HAMMING_PROTECTION      : boolean := true;
    constant c_ENABLE_TG_HAMMING_DOUBLE_DETECT   : boolean := true;
    constant c_ENABLE_TG_HAMMING_INJECT_ERROR    : boolean := false;

    -- TM ECC/TMR toggles.
    constant c_ENABLE_TM_CTRL_TMR                : boolean := true;
    constant c_ENABLE_TM_HAMMING_PROTECTION      : boolean := true;
    constant c_ENABLE_TM_HAMMING_DOUBLE_DETECT   : boolean := true;
    constant c_ENABLE_TM_HAMMING_INJECT_ERROR    : boolean := false;
    constant c_ENABLE_TM_TXN_COUNTER_HAMMING     : boolean := true;
    constant c_TM_TRANSACTION_COUNTER_WIDTH       : natural := 24;
    -- Number of TM completed packets between periodic UART reports.
    constant c_TM_UART_REPORT_PERIOD_PACKETS      : positive := 100;

    -- Loopback ECC/TMR toggles.
    constant c_ENABLE_LB_CTRL_TMR                : boolean := true;
    constant c_ENABLE_LB_HAMMING_PROTECTION      : boolean := true;
    constant c_ENABLE_LB_HAMMING_DOUBLE_DETECT   : boolean := true;
    constant c_ENABLE_LB_HAMMING_INJECT_ERROR    : boolean := false;

    -- Hamming FIFO control-state TMR toggle (stage_valid + fifo_count in buffer_fifo_ham).
    constant c_ENABLE_HAM_FIFO_CTRL_TMR          : boolean := true;
    
    -- XINA SETTINGS
    constant flow_ft_c          : natural  := 1; -- 1 for TMR, 0 for Standard
    constant routing_ft_c       : natural  := 1; -- 1 for TMR, 0 for Standard
    constant arbitration_ft_c   : natural  := 1; -- 1 for TMR, 0 for Standard
    constant buffering_ft_c     : natural  := 1; -- 1 for Hamming, 0 for Standard
    constant rows_c             : positive := 2;
    constant cols_c             : positive := 2;
    constant flow_mode_c        : natural  := 0; -- 0 for HS Moore, 1 for HS Mealy
    constant routing_mode_c     : natural  := 0; -- 0 for XY Moore, 1 for XY Mealy
    constant arbitration_mode_c : natural  := 0; -- 0 for RR Moore, 1 for RR Mealy
    constant buffer_mode_c      : natural  := 0; -- 0 for FIFO Ring, 1 for FIFO Shift
    constant buffer_depth_c     : positive := 4;
    constant data_width_c       : positive := 32;
    
    --XINA DATATYPES
    type data_link_l_t is array (cols_c - 1 downto 0, rows_c - 1 downto 0) of std_logic_vector(data_width_c downto 0);
    type data_link_x_t is array (cols_c downto 0, rows_c - 1 downto 0) of std_logic_vector(data_width_c downto 0);
    type data_link_y_t is array (cols_c - 1 downto 0, rows_c downto 0) of std_logic_vector(data_width_c downto 0);
    type ctrl_link_l_t is array (cols_c - 1 downto 0, rows_c - 1 downto 0) of std_logic;
    type ctrl_link_x_t is array (cols_c downto 0, rows_c - 1 downto 0) of std_logic;
    type ctrl_link_y_t is array (cols_c - 1 downto 0, rows_c downto 0) of std_logic;
    
end package;
