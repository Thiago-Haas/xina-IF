library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_packetizer_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        OPC_SEND_i: in std_logic;
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
        ADD_o: out std_logic;
        INTEGRITY_RESETn_o: out std_logic
    );
end backend_manager_packetizer_control;

architecture rtl of backend_manager_packetizer_control is
    
    signal state_w_r    : std_logic_vector(2 downto 0);
    signal next_state_w : std_logic_vector(2 downto 0);

begin
    ---------------------------------------------------------------------------------------------
    -- Update current state on clock rising edge.
    process (all)
    begin
        if (ARESETn = '0') then
            state_w_r <= "000"; -- Idle
        elsif (rising_edge(ACLK)) then
            state_w_r <= next_state_w;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- State machine.
    process (all)
    begin
        case state_w_r is

            when "000" => if (START_SEND_PACKET_i = '1' and WRITE_OK_BUFFER_i = '1') then next_state_w <= "001"; else next_state_w <= "000"; end if;

            when "001" => if (WRITE_OK_BUFFER_i = '1') then next_state_w <= "010"; else next_state_w <= "001"; end if;

            when "010"  => if (WRITE_OK_BUFFER_i = '1') then next_state_w <= "011"; else next_state_w <= "010"; end if;

            when "011" => if (WRITE_OK_BUFFER_i = '1') then next_state_w <= "100"; else next_state_w <= "011"; end if;

            when "100" => if (WRITE_OK_BUFFER_i = '1') then
                                    if (OPC_SEND_i = '0') then
                                        next_state_w <= "101"; -- Write packet. Next flit is payload.
                                    else
                                        next_state_w <= "110"; -- Read packet. Next flit is trailer.
                                    end if;
                                else
                                    next_state_w <= "100";
                                end if;

            when "101" => if (VALID_SEND_DATA_i = '1' and WRITE_OK_BUFFER_i = '1' and LAST_SEND_DATA_i = '1') then
                                 next_state_w <= "110";
                              else
                                 next_state_w <= "101";
                              end if;

            when "110" => if (WRITE_OK_BUFFER_i = '1') then next_state_w <= "000"; else next_state_w <= "110"; end if;

            when others => next_state_w <= "000";
        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Output values.

    READY_SEND_PACKET_o <= '1' when (state_w_r = "000" and WRITE_OK_BUFFER_i = '1') else '0';

    READY_SEND_DATA_o <= '1' when (state_w_r = "101" and WRITE_OK_BUFFER_i = '1') else '0';

    FLIT_SELECTOR_o <= "000" when (state_w_r = "001") else
                       "001" when (state_w_r = "010") else
                       "010" when (state_w_r = "011") else
                       "011" when (state_w_r = "100") else
                       "100" when (state_w_r = "101") else
                       "101" when (state_w_r = "110") else
                       "111";

    WRITE_BUFFER_o <= '1' when (state_w_r = "001") or
                               (state_w_r = "010") or
                               (state_w_r = "011") or
                               (state_w_r = "100") or
                               (state_w_r = "101" and VALID_SEND_DATA_i = '1') or
                               (state_w_r = "110") else '0';

    ADD_o <= '1' when ((state_w_r = "001") or
                       (state_w_r = "010") or
                       (state_w_r = "011") or
                       (state_w_r = "100") or
                       (state_w_r = "101" and VALID_SEND_DATA_i = '1')) and WRITE_OK_BUFFER_i = '1' else '0';

    INTEGRITY_RESETn_o <= '0' when (state_w_r = "000") else '1';

end rtl;