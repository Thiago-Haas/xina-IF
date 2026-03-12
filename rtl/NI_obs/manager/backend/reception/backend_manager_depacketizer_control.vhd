library IEEE;
library work;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.xina_ni_ft_pkg.all;

entity backend_manager_depacketizer_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Backend signals.
        READY_RECEIVE_PACKET_i: in std_logic;
        READY_RECEIVE_DATA_i  : in std_logic;
        VALID_RECEIVE_DATA_o  : out std_logic;
        LAST_RECEIVE_DATA_o   : out std_logic;

        -- Buffer.
        FLIT_i          : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
        READ_OK_BUFFER_i: in std_logic;
        READ_BUFFER_o   : out std_logic;

        -- Headers.
        WRITE_H_INTERFACE_REG_o: out std_logic;

        -- Integrity control.
        ADD_o    : out std_logic;
        COMPARE_o: out std_logic;
        INTEGRITY_RESETn_o: out std_logic
    );
end backend_manager_depacketizer_control;

architecture rtl of backend_manager_depacketizer_control is
    
    signal state_w_r    : std_logic_vector(2 downto 0);
    signal next_state_w : std_logic_vector(2 downto 0);

    signal payload_counter_r: unsigned(7 downto 0) := to_unsigned(255, 8);
    signal set_payload_counter_r: std_logic := '0';
    signal subtract_payload_counter_r: std_logic := '0';





  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of payload_counter_r : signal is "TRUE";
  attribute DONT_TOUCH of set_payload_counter_r : signal is "TRUE";
  attribute DONT_TOUCH of state_w_r : signal is "TRUE";
  attribute DONT_TOUCH of subtract_payload_counter_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of payload_counter_r : signal is true;
  attribute syn_preserve of set_payload_counter_r : signal is true;
  attribute syn_preserve of state_w_r : signal is true;
  attribute syn_preserve of subtract_payload_counter_r : signal is true;
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
            when "000" => if (READ_OK_BUFFER_i = '1') then next_state_w <= "001"; else next_state_w <= "000"; end if;

            when "001" => if (READ_OK_BUFFER_i = '1') then next_state_w <= "010"; else next_state_w <= "001"; end if;

            when "010" => if (READ_OK_BUFFER_i = '1') then
                            if (FLIT_i(1) = '0') then
                              next_state_w <= "100"; -- Write response. Next flit is trailer.
                            else
                              next_state_w <= "011"; -- Read response.
                            end if;
                          else
                            next_state_w <= "010";
                          end if;

            when "011" => if (payload_counter_r = to_unsigned(0, 8) and READY_RECEIVE_DATA_i = '1' and READ_OK_BUFFER_i = '1') then
                            next_state_w <= "101";
                          else
                            next_state_w <= "011";
                          end if;

            when "100" => if (READY_RECEIVE_PACKET_i = '1' and READ_OK_BUFFER_i = '1') then next_state_w <= "101"; else next_state_w <= "100"; end if;

            when "101" => if (READ_OK_BUFFER_i = '1') then next_state_w <= "000"; else next_state_w <= "101"; end if;

            when others => next_state_w <= "000";
                
        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Payload counter. 
    -- TODO: Apply ECC
    process (all)
    begin
      if (ARESETn = '0') then
        payload_counter_r <= to_unsigned(255, 8);
      elsif (rising_edge(ACLK)) then
        if (set_payload_counter_r = '1') then
          payload_counter_r <= unsigned(FLIT_i(14 downto 7));
        elsif (subtract_payload_counter_r = '1') then
          payload_counter_r <= payload_counter_r - 1;
        end if;
      end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Internal signals.
    set_payload_counter_r      <= '1' when (state_w_r = "010") else '0';
    subtract_payload_counter_r <= '1' when (state_w_r = "011" and READ_OK_BUFFER_i = '1' and READY_RECEIVE_DATA_i = '1') else '0';

    ---------------------------------------------------------------------------------------------
    -- Output values.

    VALID_RECEIVE_DATA_o <= '1' when (state_w_r = "100" and READ_OK_BUFFER_i = '1') or
                                     (state_w_r = "011" and READ_OK_BUFFER_i = '1')
                                     else '0';

    LAST_RECEIVE_DATA_o  <= '1' when (state_w_r = "011" and READ_OK_BUFFER_i = '1' and payload_counter_r = to_unsigned(0, 8)) else '0';

    READ_BUFFER_o <= '1' when (state_w_r = "000") or
                              (state_w_r = "001") or
                              (state_w_r = "010") or
                              (state_w_r = "011" and READY_RECEIVE_DATA_i = '1') or
                              (state_w_r = "101")
                              else '0';

    WRITE_H_INTERFACE_REG_o <= '1' when (state_w_r = "010") else '0';

    ADD_o <= '1' when ((state_w_r = "000") or
                       (state_w_r = "001") or
                       (state_w_r = "010") or
                       (state_w_r = "011" and READY_RECEIVE_DATA_i = '1')) and READ_OK_BUFFER_i = '1' else '0';

    COMPARE_o <= '1' when (state_w_r = "101" and READ_OK_BUFFER_i = '1') else '0';

    INTEGRITY_RESETn_o <= '0' when (state_w_r = "000" and next_state_w = "000") else '1';

end rtl;