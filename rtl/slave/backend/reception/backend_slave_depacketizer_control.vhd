library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity backend_slave_depacketizer_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        i_READY_RECEIVE_PACKET: in std_logic;
        i_READY_RECEIVE_DATA  : in std_logic;
        o_VALID_RECEIVE_PACKET: out std_logic;
        o_VALID_RECEIVE_DATA  : out std_logic;
        o_LAST_RECEIVE_DATA   : out std_logic;

        -- Signals from injection.
        i_HAS_FINISHED_RESPONSE: in std_logic;
        o_HAS_REQUEST_PACKET   : out std_logic;

        -- Buffer.
        i_FLIT          : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        o_READ_BUFFER   : out std_logic;
        i_READ_OK_BUFFER: in std_logic;

        -- Headers.
        i_H_INTERFACE: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

        o_WRITE_H_SRC_REG      : out std_logic;
        o_WRITE_H_INTERFACE_REG: out std_logic;
        o_WRITE_H_ADDRESS_REG  : out std_logic;

        -- Integrity control.
        o_ADD    : out std_logic;
        o_COMPARE: out std_logic;
        o_INTEGRITY_RESETn: out std_logic
    );
end backend_slave_depacketizer_control;

architecture rtl of backend_slave_depacketizer_control is
    
    signal state_w_r    : std_logic_vector(3 downto 0);
    signal next_state_w : std_logic_vector(3 downto 0);

    signal PAYLOAD_COUNTER_r: unsigned(7 downto 0) := to_unsigned(255, 8);
    signal r_SET_PAYLOAD_COUNTER: std_logic := '0';
    signal r_SUBTRACT_PAYLOAD_COUNTER: std_logic := '0';

begin
    ---------------------------------------------------------------------------------------------
    -- Update current state on clock rising edge.
    process (all)
    begin
        if (ARESETn = '0') then
            state_w_r <= "0000";
        elsif (rising_edge(ACLK)) then
            state_w_r <= next_state_w;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- State machine.
    process (all)
    begin
        case state_w_r is
            when "0000" => if (i_READ_OK_BUFFER = '1') then next_state_w <= "0001"; else next_state_w <= "0000"; end if;

            when "0001"  => if (i_READ_OK_BUFFER = '1') then next_state_w <= "0010"; else next_state_w <= "0001"; end if;

            when "0010" => if (i_READ_OK_BUFFER = '1') then next_state_w <= "0011"; else next_state_w <= "0010"; end if;

            when "0011" => if (i_READ_OK_BUFFER = '1') then
                             if (i_H_INTERFACE(1) = '0') then
                               next_state_w <= "0100"; -- Write request.
                             else
                               next_state_w <= "0110"; -- Read request. Next flit is trailer.
                             end if;
                           else
                             next_state_w <= "0011";
                           end if;

            when "0100" => if (i_READY_RECEIVE_PACKET = '1') then next_state_w <= "0101"; else next_state_w <= "0100"; end if;

            when "0101" => if (PAYLOAD_COUNTER_r = to_unsigned(0, 8) and i_READY_RECEIVE_DATA = '1' and i_READ_OK_BUFFER = '1') then
                             next_state_w <= "0111";
                           else
                             next_state_w <= "0101";
                           end if;

            when "0110" => if (i_READY_RECEIVE_PACKET = '1') then next_state_w <= "0111"; else next_state_w <= "0110"; end if;

            when "0111" => if (i_READ_OK_BUFFER = '1') then next_state_w <= "1000"; else next_state_w <= "0111"; end if;

            when "1000" => if (i_HAS_FINISHED_RESPONSE = '1') then next_state_w <= "0000"; else next_state_w <= "1000"; end if;
            
            when others => next_state_w <= "0000"; 

        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Payload counter.
    process (all)
    begin
        if (ARESETn = '0') then
            PAYLOAD_COUNTER_r <= to_unsigned(255, 8);
        elsif (rising_edge(ACLK)) then
            if (r_SET_PAYLOAD_COUNTER = '1') then
                PAYLOAD_COUNTER_r <= unsigned(i_H_INTERFACE(14 downto 7));
            elsif (r_SUBTRACT_PAYLOAD_COUNTER = '1') then
                PAYLOAD_COUNTER_r <= PAYLOAD_COUNTER_r - 1;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Internal signals.
    r_SET_PAYLOAD_COUNTER      <= '1' when (state_w_r = "0011") else '0';
    r_SUBTRACT_PAYLOAD_COUNTER <= '1' when (state_w_r = "0101" and i_READ_OK_BUFFER = '1' and i_READY_RECEIVE_DATA = '1') else '0';

    ---------------------------------------------------------------------------------------------
    -- Output values.
	o_READ_BUFFER <= '1' when (state_w_r = "0000") or
                              (state_w_r = "0001") or
                              (state_w_r = "0010") or
                              (state_w_r = "0011") or
                              (state_w_r = "0101" and i_READY_RECEIVE_DATA = '1') or
                              (state_w_r = "0111")
                              else '0';

    o_VALID_RECEIVE_PACKET <= '1' when (state_w_r = "0100") or
                                       (state_w_r = "0110")
                                       else '0';

    o_VALID_RECEIVE_DATA <= '1' when (state_w_r = "0101" and i_READ_OK_BUFFER = '1') else '0';

    o_LAST_RECEIVE_DATA  <= '1' when (state_w_r = "0101" and i_READ_OK_BUFFER = '1' and PAYLOAD_COUNTER_r = to_unsigned(0, 8)) else '0';

    o_HAS_REQUEST_PACKET <= '1' when (state_w_r = "1000") else '0';

    o_WRITE_H_SRC_REG       <= '1' when (state_w_r = "0001") else '0';
    o_WRITE_H_INTERFACE_REG <= '1' when (state_w_r = "0010") else '0';
    o_WRITE_H_ADDRESS_REG   <= '1' when (state_w_r = "0011")  else '0';

    o_ADD <= '1' when ((state_w_r = "0000") or
                       (state_w_r = "0001") or
                       (state_w_r = "0010") or
                       (state_w_r = "0011") or
                       (state_w_r = "0101" and i_READY_RECEIVE_DATA = '1')) and i_READ_OK_BUFFER = '1' else '0';

    o_COMPARE <= '1' when (state_w_r = "0111" and i_READ_OK_BUFFER = '1') else '0';

    o_INTEGRITY_RESETn <= '0' when (state_w_r = "0000" and next_state_w = "0000") else '1';

end rtl;
