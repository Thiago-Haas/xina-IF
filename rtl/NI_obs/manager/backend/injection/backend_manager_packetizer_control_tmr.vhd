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
        i_OPC_SEND         : in std_logic;
        i_START_SEND_PACKET: in std_logic;
        i_VALID_SEND_DATA  : in std_logic;
        i_LAST_SEND_DATA   : in std_logic;

        o_READY_SEND_PACKET: out std_logic;
        o_READY_SEND_DATA  : out std_logic;
        o_FLIT_SELECTOR    : out std_logic_vector(2 downto 0);

        -- Buffer.
        i_WRITE_OK_BUFFER: in std_logic;
        o_WRITE_BUFFER   : out std_logic;

        -- Integrity control.
        o_ADD            : out std_logic;
        o_INTEGRITY_RESETn: out std_logic;

        -- Hardening
        correct_error_i : in  std_logic;
        error_o         : out std_logic
    );
end backend_manager_packetizer_control_tmr;

architecture rtl of backend_manager_packetizer_control_tmr is

    type t_BIT_VECTOR is array (2 downto 0) of std_logic;
    type t_BIT_VECTOR_FLIT_SELECTOR is array (2 downto 0) of std_logic_vector(2 downto 0);

    signal w_READY_SEND_PACKET  : t_BIT_VECTOR;
    signal w_READY_SEND_DATA    : t_BIT_VECTOR;
    signal w_FLIT_SELECTOR      : t_BIT_VECTOR_FLIT_SELECTOR;
    signal w_WRITE_BUFFER       : t_BIT_VECTOR;
    signal w_ADD                : t_BIT_VECTOR;
    signal w_INTEGRITY_RESETn   : t_BIT_VECTOR;

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
        -- Xilinx attributes to prevent optimization of TMR
        attribute DONT_TOUCH : string;
        attribute DONT_TOUCH of u_PACKETIZER_CONTROL : label is "TRUE";
        -- Synplify attributes to prevent optimization of TMR
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

                i_OPC_SEND          => i_OPC_SEND,
                i_START_SEND_PACKET => i_START_SEND_PACKET,
                i_VALID_SEND_DATA   => i_VALID_SEND_DATA,
                i_LAST_SEND_DATA    => i_LAST_SEND_DATA,

                o_READY_SEND_PACKET => w_READY_SEND_PACKET(i),
                o_READY_SEND_DATA   => w_READY_SEND_DATA(i),
                o_FLIT_SELECTOR     => w_FLIT_SELECTOR(i),

                i_WRITE_OK_BUFFER   => i_WRITE_OK_BUFFER,
                o_WRITE_BUFFER      => w_WRITE_BUFFER(i),

                o_ADD               => w_ADD(i),
                o_INTEGRITY_RESETn  => w_INTEGRITY_RESETn(i)
            );
    end generate;

    -----------------------------------------------------------------------------
    -- Majority vote (corrected)
    -----------------------------------------------------------------------------
    corr_READY_SEND_PACKET_w <= (w_READY_SEND_PACKET(2) and w_READY_SEND_PACKET(1)) or
                                (w_READY_SEND_PACKET(2) and w_READY_SEND_PACKET(0)) or
                                (w_READY_SEND_PACKET(1) and w_READY_SEND_PACKET(0));

    corr_READY_SEND_DATA_w   <= (w_READY_SEND_DATA(2) and w_READY_SEND_DATA(1)) or
                                (w_READY_SEND_DATA(2) and w_READY_SEND_DATA(0)) or
                                (w_READY_SEND_DATA(1) and w_READY_SEND_DATA(0));

    corr_WRITE_BUFFER_w      <= (w_WRITE_BUFFER(2) and w_WRITE_BUFFER(1)) or
                                (w_WRITE_BUFFER(2) and w_WRITE_BUFFER(0)) or
                                (w_WRITE_BUFFER(1) and w_WRITE_BUFFER(0));

    corr_ADD_w               <= (w_ADD(2) and w_ADD(1)) or
                                (w_ADD(2) and w_ADD(0)) or
                                (w_ADD(1) and w_ADD(0));

    corr_INTEGRITY_RESETn_w  <= (w_INTEGRITY_RESETn(2) and w_INTEGRITY_RESETn(1)) or
                                (w_INTEGRITY_RESETn(2) and w_INTEGRITY_RESETn(0)) or
                                (w_INTEGRITY_RESETn(1) and w_INTEGRITY_RESETn(0));

    gen_FLIT_SEL_MAJ : for b in 2 downto 0 generate
    begin
        corr_FLIT_SELECTOR_w(b) <= (w_FLIT_SELECTOR(2)(b) and w_FLIT_SELECTOR(1)(b)) or
                                   (w_FLIT_SELECTOR(2)(b) and w_FLIT_SELECTOR(0)(b)) or
                                   (w_FLIT_SELECTOR(1)(b) and w_FLIT_SELECTOR(0)(b));
    end generate;

    -----------------------------------------------------------------------------
    -- Error detection (mismatch)
    -----------------------------------------------------------------------------
    error_READY_SEND_PACKET_w <= (w_READY_SEND_PACKET(2) xor w_READY_SEND_PACKET(1)) or
                                 (w_READY_SEND_PACKET(2) xor w_READY_SEND_PACKET(0)) or
                                 (w_READY_SEND_PACKET(1) xor w_READY_SEND_PACKET(0));

    error_READY_SEND_DATA_w   <= (w_READY_SEND_DATA(2) xor w_READY_SEND_DATA(1)) or
                                 (w_READY_SEND_DATA(2) xor w_READY_SEND_DATA(0)) or
                                 (w_READY_SEND_DATA(1) xor w_READY_SEND_DATA(0));

    error_WRITE_BUFFER_w      <= (w_WRITE_BUFFER(2) xor w_WRITE_BUFFER(1)) or
                                 (w_WRITE_BUFFER(2) xor w_WRITE_BUFFER(0)) or
                                 (w_WRITE_BUFFER(1) xor w_WRITE_BUFFER(0));

    error_ADD_w               <= (w_ADD(2) xor w_ADD(1)) or
                                 (w_ADD(2) xor w_ADD(0)) or
                                 (w_ADD(1) xor w_ADD(0));

    error_INTEGRITY_RESETn_w  <= (w_INTEGRITY_RESETn(2) xor w_INTEGRITY_RESETn(1)) or
                                 (w_INTEGRITY_RESETn(2) xor w_INTEGRITY_RESETn(0)) or
                                 (w_INTEGRITY_RESETn(1) xor w_INTEGRITY_RESETn(0));

    gen_FLIT_SEL_ERR : for b in 2 downto 0 generate
    begin
        error_FLIT_SELECTOR_vec_w(b) <= (w_FLIT_SELECTOR(2)(b) xor w_FLIT_SELECTOR(1)(b)) or
                                        (w_FLIT_SELECTOR(2)(b) xor w_FLIT_SELECTOR(0)(b)) or
                                        (w_FLIT_SELECTOR(1)(b) xor w_FLIT_SELECTOR(0)(b));
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
    o_READY_SEND_PACKET  <= corr_READY_SEND_PACKET_w when correct_error_i = '1' else w_READY_SEND_PACKET(0);
    o_READY_SEND_DATA    <= corr_READY_SEND_DATA_w   when correct_error_i = '1' else w_READY_SEND_DATA(0);
    o_WRITE_BUFFER       <= corr_WRITE_BUFFER_w      when correct_error_i = '1' else w_WRITE_BUFFER(0);
    o_ADD                <= corr_ADD_w               when correct_error_i = '1' else w_ADD(0);
    o_INTEGRITY_RESETn   <= corr_INTEGRITY_RESETn_w  when correct_error_i = '1' else w_INTEGRITY_RESETn(0);
    o_FLIT_SELECTOR      <= corr_FLIT_SELECTOR_w     when correct_error_i = '1' else w_FLIT_SELECTOR(0);

end rtl;
