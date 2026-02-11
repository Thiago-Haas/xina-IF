library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity backend_master_packetizer_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        i_OPC_SEND: in std_logic;
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
        o_ADD: out std_logic;
        o_INTEGRITY_RESETn: out std_logic
    );
end backend_master_packetizer_control;

architecture rtl of backend_master_packetizer_control is
    
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

            when "000" => if (i_START_SEND_PACKET = '1' and i_WRITE_OK_BUFFER = '1') then next_state_w <= "001"; else next_state_w <= "000"; end if;

            when "001" => if (i_WRITE_OK_BUFFER = '1') then next_state_w <= "010"; else next_state_w <= "001"; end if;

            when "010"  => if (i_WRITE_OK_BUFFER = '1') then next_state_w <= "011"; else next_state_w <= "010"; end if;

            when "011" => if (i_WRITE_OK_BUFFER = '1') then next_state_w <= "100"; else next_state_w <= "011"; end if;

            when "100" => if (i_WRITE_OK_BUFFER = '1') then
                                    if (i_OPC_SEND = '0') then
                                        next_state_w <= "101"; -- Write packet. Next flit is payload.
                                    else
                                        next_state_w <= "110"; -- Read packet. Next flit is trailer.
                                    end if;
                                else
                                    next_state_w <= "100";
                                end if;

            when "101" => if (i_VALID_SEND_DATA = '1' and i_WRITE_OK_BUFFER = '1' and i_LAST_SEND_DATA = '1') then
                                 next_state_w <= "110";
                              else
                                 next_state_w <= "101";
                              end if;

            when "110" => if (i_WRITE_OK_BUFFER = '1') then next_state_w <= "000"; else next_state_w <= "110"; end if;

            when others => next_state_w <= "000";
        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Output values.

    o_READY_SEND_PACKET <= '1' when (state_w_r = "000" and i_WRITE_OK_BUFFER = '1') else '0';

    o_READY_SEND_DATA <= '1' when (state_w_r = "101" and i_WRITE_OK_BUFFER = '1') else '0';

    o_FLIT_SELECTOR <= "000" when (state_w_r = "001") else
                       "001" when (state_w_r = "010") else
                       "010" when (state_w_r = "011") else
                       "011" when (state_w_r = "100") else
                       "100" when (state_w_r = "101") else
                       "101" when (state_w_r = "110") else
                       "111";

    o_WRITE_BUFFER <= '1' when (state_w_r = "001") or
                               (state_w_r = "010") or
                               (state_w_r = "011") or
                               (state_w_r = "100") or
                               (state_w_r = "101" and i_VALID_SEND_DATA = '1') or
                               (state_w_r = "110") else '0';

    o_ADD <= '1' when ((state_w_r = "001") or
                       (state_w_r = "010") or
                       (state_w_r = "011") or
                       (state_w_r = "100") or
                       (state_w_r = "101" and i_VALID_SEND_DATA = '1')) and i_WRITE_OK_BUFFER = '1' else '0';

    o_INTEGRITY_RESETn <= '0' when (state_w_r = "000") else '1';

end rtl;