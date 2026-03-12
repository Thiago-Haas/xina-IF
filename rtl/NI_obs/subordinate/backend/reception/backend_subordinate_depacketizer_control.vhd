library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

entity backend_subordinate_depacketizer_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;
        VALID_RECEIVE_PACKET_o: out std_logic;
        VALID_RECEIVE_DATA_o  : out std_logic;
        LAST_RECEIVE_DATA_o   : out std_logic;

        -- Signals from injection.
        HAS_FINISHED_RESPONSE_i: in std_logic;
        HAS_REQUEST_PACKET_o   : out std_logic;

        -- Buffer.
        FLIT_i          : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        READ_BUFFER_o   : out std_logic;
        READ_OK_BUFFER_i: in std_logic;

        -- Headers.
        H_INTERFACE_i: in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);

        WRITE_H_SRC_REG_o      : out std_logic;
        WRITE_H_INTERFACE_REG_o: out std_logic;
        WRITE_H_ADDRESS_REG_o  : out std_logic;

        -- Integrity control.
        ADD_o    : out std_logic;
        COMPARE_o: out std_logic;
        INTEGRITY_RESETn_o: out std_logic
    );
end backend_subordinate_depacketizer_control;

architecture rtl of backend_subordinate_depacketizer_control is
    
    signal state_w_r    : std_logic_vector(3 downto 0);
    signal next_state_w : std_logic_vector(3 downto 0);

    signal PAYLOAD_COUNTER_r: unsigned(7 downto 0) := to_unsigned(255, 8);
    signal set_payload_counter_w: std_logic := '0';
    signal subtract_payload_counter_w: std_logic := '0';





  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of PAYLOAD_COUNTER_r : signal is "TRUE";
  attribute DONT_TOUCH of state_w_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of PAYLOAD_COUNTER_r : signal is true;
  attribute syn_preserve of state_w_r : signal is true;
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
            when "0000" => if (READ_OK_BUFFER_i = '1') then next_state_w <= "0001"; else next_state_w <= "0000"; end if;

            when "0001"  => if (READ_OK_BUFFER_i = '1') then next_state_w <= "0010"; else next_state_w <= "0001"; end if;

            when "0010" => if (READ_OK_BUFFER_i = '1') then next_state_w <= "0011"; else next_state_w <= "0010"; end if;

            when "0011" => if (READ_OK_BUFFER_i = '1') then
                             if (H_INTERFACE_i(1) = '0') then
                               next_state_w <= "0100"; -- Write request.
                             else
                               next_state_w <= "0110"; -- Read request. Next flit is trailer.
                             end if;
                           else
                             next_state_w <= "0011";
                           end if;

            when "0100" => if (READY_RECEIVE_PACKET_i = '1') then next_state_w <= "0101"; else next_state_w <= "0100"; end if;

            when "0101" => if (PAYLOAD_COUNTER_r = to_unsigned(0, 8) and READY_RECEIVE_DATA_i = '1' and READ_OK_BUFFER_i = '1') then
                             next_state_w <= "0111";
                           else
                             next_state_w <= "0101";
                           end if;

            when "0110" => if (READY_RECEIVE_PACKET_i = '1') then next_state_w <= "0111"; else next_state_w <= "0110"; end if;

            when "0111" => if (READ_OK_BUFFER_i = '1') then next_state_w <= "1000"; else next_state_w <= "0111"; end if;

            when "1000" => if (HAS_FINISHED_RESPONSE_i = '1') then next_state_w <= "0000"; else next_state_w <= "1000"; end if;
            
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
            if (set_payload_counter_w = '1') then
                PAYLOAD_COUNTER_r <= unsigned(H_INTERFACE_i(14 downto 7));
            elsif (subtract_payload_counter_w = '1') then
                PAYLOAD_COUNTER_r <= PAYLOAD_COUNTER_r - 1;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Internal signals.
    set_payload_counter_w      <= '1' when (state_w_r = "0011") else '0';
    subtract_payload_counter_w <= '1' when (state_w_r = "0101" and READ_OK_BUFFER_i = '1' and READY_RECEIVE_DATA_i = '1') else '0';

    ---------------------------------------------------------------------------------------------
    -- Output values.
	READ_BUFFER_o <= '1' when (state_w_r = "0000") or
                              (state_w_r = "0001") or
                              (state_w_r = "0010") or
                              (state_w_r = "0011") or
                              (state_w_r = "0101" and READY_RECEIVE_DATA_i = '1') or
                              (state_w_r = "0111")
                              else '0';

    VALID_RECEIVE_PACKET_o <= '1' when (state_w_r = "0100") or
                                       (state_w_r = "0110")
                                       else '0';

    VALID_RECEIVE_DATA_o <= '1' when (state_w_r = "0101" and READ_OK_BUFFER_i = '1') else '0';

    LAST_RECEIVE_DATA_o  <= '1' when (state_w_r = "0101" and READ_OK_BUFFER_i = '1' and PAYLOAD_COUNTER_r = to_unsigned(0, 8)) else '0';

    HAS_REQUEST_PACKET_o <= '1' when (state_w_r = "1000") else '0';

    WRITE_H_SRC_REG_o       <= '1' when (state_w_r = "0001") else '0';
    WRITE_H_INTERFACE_REG_o <= '1' when (state_w_r = "0010") else '0';
    WRITE_H_ADDRESS_REG_o   <= '1' when (state_w_r = "0011")  else '0';

    ADD_o <= '1' when ((state_w_r = "0000") or
                       (state_w_r = "0001") or
                       (state_w_r = "0010") or
                       (state_w_r = "0011") or
                       (state_w_r = "0101" and READY_RECEIVE_DATA_i = '1')) and READ_OK_BUFFER_i = '1' else '0';

    COMPARE_o <= '1' when (state_w_r = "0111" and READ_OK_BUFFER_i = '1') else '0';

    INTEGRITY_RESETn_o <= '0' when (state_w_r = "0000" and next_state_w = "0000") else '1';

end rtl;
