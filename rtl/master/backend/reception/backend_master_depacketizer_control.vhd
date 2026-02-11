library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;
use work.xina_ft_pkg.all;

entity backend_master_depacketizer_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        i_READY_RECEIVE_PACKET: in std_logic;
        i_READY_RECEIVE_DATA  : in std_logic;
        o_VALID_RECEIVE_DATA  : out std_logic;
        o_LAST_RECEIVE_DATA   : out std_logic;

        -- Buffer.
        i_FLIT          : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        i_READ_OK_BUFFER: in std_logic;
        o_READ_BUFFER   : out std_logic;

        -- Headers.
        o_WRITE_H_INTERFACE_REG: out std_logic;

        -- Integrity control.
        o_ADD    : out std_logic;
        o_COMPARE: out std_logic;
        o_INTEGRITY_RESETn: out std_logic
    );
end backend_master_depacketizer_control;

architecture rtl of backend_master_depacketizer_control is
    
    signal state_w_r    : std_logic_vector(2 downto 0);
    signal next_state_w : std_logic_vector(2 downto 0);

    signal r_PAYLOAD_COUNTER: unsigned(7 downto 0) := to_unsigned(255, 8);
    signal r_SET_PAYLOAD_COUNTER: std_logic := '0';
    signal r_SUBTRACT_PAYLOAD_COUNTER: std_logic := '0';

begin
    ---------------------------------------------------------------------------------------------
    -- Update current state on clock rising edge.
    process (all)
    begin
        if (ARESETn = '0') then
            state_w_r <= "000";
        elsif (rising_edge(ACLK)) then
            state_w_r <= next_state_w;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- State machine.
    process (all)
    begin
        case state_w_r is
            when "000" => if (i_READ_OK_BUFFER = '1') then next_state_w <= "001"; else next_state_w <= "000"; end if;

            when "001" => if (i_READ_OK_BUFFER = '1') then next_state_w <= "010"; else next_state_w <= "001"; end if;

            when "010" => if (i_READ_OK_BUFFER = '1') then
                            if (i_FLIT(1) = '0') then
                              next_state_w <= "100"; -- Write response. Next flit is trailer.
                            else
                              next_state_w <= "011"; -- Read response.
                            end if;
                          else
                            next_state_w <= "010";
                          end if;

            when "011" => if (r_PAYLOAD_COUNTER = to_unsigned(0, 8) and i_READY_RECEIVE_DATA = '1' and i_READ_OK_BUFFER = '1') then
                            next_state_w <= "101";
                          else
                            next_state_w <= "011";
                          end if;

            when "100" => if (i_READY_RECEIVE_PACKET = '1' and i_READ_OK_BUFFER = '1') then next_state_w <= "101"; else next_state_w <= "100"; end if;

            when "101" => if (i_READ_OK_BUFFER = '1') then next_state_w <= "000"; else next_state_w <= "101"; end if;

            when others => next_state_w <= "000";
                
        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Payload counter. 
    -- TODO: Apply ECC
    process (all)
    begin
      if (ARESETn = '0') then
        r_PAYLOAD_COUNTER <= to_unsigned(255, 8);
      elsif (rising_edge(ACLK)) then
        if (r_SET_PAYLOAD_COUNTER = '1') then
          r_PAYLOAD_COUNTER <= unsigned(i_FLIT(14 downto 7));
        elsif (r_SUBTRACT_PAYLOAD_COUNTER = '1') then
          r_PAYLOAD_COUNTER <= r_PAYLOAD_COUNTER - 1;
        end if;
      end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Internal signals.
    r_SET_PAYLOAD_COUNTER      <= '1' when (state_w_r = "010") else '0';
    r_SUBTRACT_PAYLOAD_COUNTER <= '1' when (state_w_r = "011" and i_READ_OK_BUFFER = '1' and i_READY_RECEIVE_DATA = '1') else '0';

    ---------------------------------------------------------------------------------------------
    -- Output values.

    o_VALID_RECEIVE_DATA <= '1' when (state_w_r = "100" and i_READ_OK_BUFFER = '1') or
                                     (state_w_r = "011" and i_READ_OK_BUFFER = '1')
                                     else '0';

    o_LAST_RECEIVE_DATA  <= '1' when (state_w_r = "011" and i_READ_OK_BUFFER = '1' and r_PAYLOAD_COUNTER = to_unsigned(0, 8)) else '0';

    o_READ_BUFFER <= '1' when (state_w_r = "000") or
                              (state_w_r = "001") or
                              (state_w_r = "010") or
                              (state_w_r = "011" and i_READY_RECEIVE_DATA = '1') or
                              (state_w_r = "101")
                              else '0';

    o_WRITE_H_INTERFACE_REG <= '1' when (state_w_r = "010") else '0';

    o_ADD <= '1' when ((state_w_r = "000") or
                       (state_w_r = "001") or
                       (state_w_r = "010") or
                       (state_w_r = "011" and i_READY_RECEIVE_DATA = '1')) and i_READ_OK_BUFFER = '1' else '0';

    o_COMPARE <= '1' when (state_w_r = "101" and i_READ_OK_BUFFER = '1') else '0';

    o_INTEGRITY_RESETn <= '0' when (state_w_r = "000" and next_state_w = "000") else '1';

end rtl;