library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_packetizer_control_tmr is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        OPC_SEND_i         : in std_logic;
        START_SEND_PACKET_i: in std_logic;
        VALID_SEND_DATA_i  : in std_logic;
        LAST_SEND_DATA_i   : in std_logic;

        READY_SEND_PACKET_o: out std_logic;
        READY_SEND_DATA_o  : out std_logic;
        FLIT_SELECTOR_o    : out std_logic_vector(2 downto 0);

        -- Buffer.
        WRITE_OK_BUFFER_i: in std_logic;
        WRITE_BUFFER_o   : out std_logic;

        -- Integrity control.
        ADD_o            : out std_logic;
        INTEGRITY_RESETn_o: out std_logic;

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end backend_manager_packetizer_control_tmr;

architecture rtl of backend_manager_packetizer_control_tmr is

    attribute DONT_TOUCH : string;
    attribute syn_preserve : boolean;
    attribute KEEP_HIERARCHY : string;

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;
    type t_BIT_VECTOR_FLIT_SELECTOR is array (2 downto 0) of std_logic_vector(2 downto 0);

    signal READY_SEND_PACKET_w  : t_BIT_VECTOR;
    signal READY_SEND_DATA_w    : t_BIT_VECTOR;
    signal FLIT_SELECTOR_w      : t_BIT_VECTOR_FLIT_SELECTOR;
    signal WRITE_BUFFER_w       : t_BIT_VECTOR;
    signal ADD_w                : t_BIT_VECTOR;
    signal INTEGRITY_RESETn_w   : t_BIT_VECTOR;

    -- Majority (corrected) outputs
    signal corr_READY_SEND_PACKET_w : std_logic;
    signal corr_READY_SEND_DATA_w   : std_logic;
    signal corr_WRITE_BUFFER_w      : std_logic;
    signal corr_ADD_w               : std_logic;
    signal corr_INTEGRITY_RESETn_w  : std_logic;
    signal corr_FLIT_SELECTOR_w     : std_logic_vector(2 downto 0);

    -- Error (mismatch) flags per output
    signal error_READY_SEND_PACKET_w : std_logic;
    signal error_READY_SEND_DATA_w   : std_logic;
    signal error_WRITE_BUFFER_w      : std_logic;
    signal error_ADD_w               : std_logic;
    signal error_INTEGRITY_RESETn_w  : std_logic;
    signal error_FLIT_SELECTOR_vec_w : std_logic_vector(2 downto 0);
    signal error_FLIT_SELECTOR_w     : std_logic;

begin

    gen_TMR : for i in 2 downto 0 generate
        attribute DONT_TOUCH of u_PACKETIZER_CONTROL : label is "TRUE";
        attribute syn_preserve of u_PACKETIZER_CONTROL : label is true;
        attribute KEEP_HIERARCHY of u_PACKETIZER_CONTROL : label is "TRUE";
        attribute syn_radhardlevel : string;
        attribute syn_keep         : boolean;
        attribute syn_safe_case    : boolean;
        attribute syn_noprune      : boolean;
        attribute syn_radhardlevel of u_PACKETIZER_CONTROL : label is "tmr";
        attribute syn_keep         of u_PACKETIZER_CONTROL : label is TRUE;
        attribute syn_safe_case    of u_PACKETIZER_CONTROL : label is TRUE;
        attribute syn_noprune      of u_PACKETIZER_CONTROL : label is TRUE;
    begin
        u_PACKETIZER_CONTROL: entity work.backend_manager_packetizer_control
            port map(
                ACLK    => ACLK,
                ARESETn => ARESETn,

                OPC_SEND_i          => OPC_SEND_i,
                START_SEND_PACKET_i => START_SEND_PACKET_i,
                VALID_SEND_DATA_i   => VALID_SEND_DATA_i,
                LAST_SEND_DATA_i    => LAST_SEND_DATA_i,

                READY_SEND_PACKET_o => READY_SEND_PACKET_w(i),
                READY_SEND_DATA_o   => READY_SEND_DATA_w(i),
                FLIT_SELECTOR_o     => FLIT_SELECTOR_w(i),

                WRITE_OK_BUFFER_i   => WRITE_OK_BUFFER_i,
                WRITE_BUFFER_o      => WRITE_BUFFER_w(i),

                ADD_o               => ADD_w(i),
                INTEGRITY_RESETn_o  => INTEGRITY_RESETn_w(i)
            );
    end generate;

    -----------------------------------------------------------------------------
    -- Majority vote (corrected)
    -----------------------------------------------------------------------------
    corr_READY_SEND_PACKET_w <= (READY_SEND_PACKET_w(2) and READY_SEND_PACKET_w(1)) or
                                (READY_SEND_PACKET_w(2) and READY_SEND_PACKET_w(0)) or
                                (READY_SEND_PACKET_w(1) and READY_SEND_PACKET_w(0));

    corr_READY_SEND_DATA_w   <= (READY_SEND_DATA_w(2) and READY_SEND_DATA_w(1)) or
                                (READY_SEND_DATA_w(2) and READY_SEND_DATA_w(0)) or
                                (READY_SEND_DATA_w(1) and READY_SEND_DATA_w(0));

    corr_WRITE_BUFFER_w      <= (WRITE_BUFFER_w(2) and WRITE_BUFFER_w(1)) or
                                (WRITE_BUFFER_w(2) and WRITE_BUFFER_w(0)) or
                                (WRITE_BUFFER_w(1) and WRITE_BUFFER_w(0));

    corr_ADD_w               <= (ADD_w(2) and ADD_w(1)) or
                                (ADD_w(2) and ADD_w(0)) or
                                (ADD_w(1) and ADD_w(0));

    corr_INTEGRITY_RESETn_w  <= (INTEGRITY_RESETn_w(2) and INTEGRITY_RESETn_w(1)) or
                                (INTEGRITY_RESETn_w(2) and INTEGRITY_RESETn_w(0)) or
                                (INTEGRITY_RESETn_w(1) and INTEGRITY_RESETn_w(0));

    gen_FLIT_SEL_MAJ : for b in 2 downto 0 generate
    begin
        corr_FLIT_SELECTOR_w(b) <= (FLIT_SELECTOR_w(2)(b) and FLIT_SELECTOR_w(1)(b)) or
                                   (FLIT_SELECTOR_w(2)(b) and FLIT_SELECTOR_w(0)(b)) or
                                   (FLIT_SELECTOR_w(1)(b) and FLIT_SELECTOR_w(0)(b));
    end generate;

    -----------------------------------------------------------------------------
    -- Error detection (mismatch)
    -----------------------------------------------------------------------------
    error_READY_SEND_PACKET_w <= (READY_SEND_PACKET_w(2) xor READY_SEND_PACKET_w(1)) or
                                 (READY_SEND_PACKET_w(2) xor READY_SEND_PACKET_w(0)) or
                                 (READY_SEND_PACKET_w(1) xor READY_SEND_PACKET_w(0));

    error_READY_SEND_DATA_w   <= (READY_SEND_DATA_w(2) xor READY_SEND_DATA_w(1)) or
                                 (READY_SEND_DATA_w(2) xor READY_SEND_DATA_w(0)) or
                                 (READY_SEND_DATA_w(1) xor READY_SEND_DATA_w(0));

    error_WRITE_BUFFER_w      <= (WRITE_BUFFER_w(2) xor WRITE_BUFFER_w(1)) or
                                 (WRITE_BUFFER_w(2) xor WRITE_BUFFER_w(0)) or
                                 (WRITE_BUFFER_w(1) xor WRITE_BUFFER_w(0));

    error_ADD_w               <= (ADD_w(2) xor ADD_w(1)) or
                                 (ADD_w(2) xor ADD_w(0)) or
                                 (ADD_w(1) xor ADD_w(0));

    error_INTEGRITY_RESETn_w  <= (INTEGRITY_RESETn_w(2) xor INTEGRITY_RESETn_w(1)) or
                                 (INTEGRITY_RESETn_w(2) xor INTEGRITY_RESETn_w(0)) or
                                 (INTEGRITY_RESETn_w(1) xor INTEGRITY_RESETn_w(0));

    gen_FLIT_SEL_ERR : for b in 2 downto 0 generate
    begin
        error_FLIT_SELECTOR_vec_w(b) <= (FLIT_SELECTOR_w(2)(b) xor FLIT_SELECTOR_w(1)(b)) or
                                        (FLIT_SELECTOR_w(2)(b) xor FLIT_SELECTOR_w(0)(b)) or
                                        (FLIT_SELECTOR_w(1)(b) xor FLIT_SELECTOR_w(0)(b));
    end generate;

    error_FLIT_SELECTOR_w <= or_reduce(error_FLIT_SELECTOR_vec_w);

    -- Aggregate error flag
    error_o <= error_READY_SEND_PACKET_w or
               error_READY_SEND_DATA_w or
               error_WRITE_BUFFER_w or
               error_ADD_w or
               error_INTEGRITY_RESETn_w or
               error_FLIT_SELECTOR_w;

    -----------------------------------------------------------------------------
    -- Output selection (majority when correction enabled, else replica 0)
    -----------------------------------------------------------------------------
    READY_SEND_PACKET_o  <= corr_READY_SEND_PACKET_w when correct_error_i = '1' else READY_SEND_PACKET_w(0);
    READY_SEND_DATA_o    <= corr_READY_SEND_DATA_w   when correct_error_i = '1' else READY_SEND_DATA_w(0);
    WRITE_BUFFER_o       <= corr_WRITE_BUFFER_w      when correct_error_i = '1' else WRITE_BUFFER_w(0);
    ADD_o                <= corr_ADD_w               when correct_error_i = '1' else ADD_w(0);
    INTEGRITY_RESETn_o   <= corr_INTEGRITY_RESETn_w  when correct_error_i = '1' else INTEGRITY_RESETn_w(0);
    FLIT_SELECTOR_o      <= corr_FLIT_SELECTOR_w     when correct_error_i = '1' else FLIT_SELECTOR_w(0);

end rtl;
