library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;

entity send_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Buffer signals.
        READ_OK_BUFFER_i: in std_logic;
        READ_BUFFER_o   : out std_logic;

        -- XINA signals.
        l_in_val_i: out std_logic;
        l_in_ack_o: in std_logic
    );
end send_control;

architecture rtl of send_control is

    signal state_w_r    : std_logic_vector(1 downto 0);
    signal next_state_w : std_logic_vector(1 downto 0);





  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of state_w_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of state_w_r : signal is true;
begin
    ---------------------------------------------------------------------------------------------
    -- Update current state on clock rising edge.
    process (all)
    begin
      if (ARESETn = '0') then
        state_w_r <= "00";
      elsif (rising_edge(ACLK)) then
        state_w_r <= next_state_w;
      end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- State machine.
    process (all)
    begin
        case state_w_r is

            when "00" => if (l_in_ack_o = '1' and READ_OK_BUFFER_i = '1') then next_state_w <= "01"; else next_state_w <= "00"; end if;

            when "01" => if (l_in_ack_o = '0') then next_state_w <= "10"; else next_state_w <= "01"; end if;

            when "10" => next_state_w <= "00";

            when others => next_state_w <= "00";

        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Output values (buffer).
    READ_BUFFER_o <= '1' when (state_w_r = "10") else '0';

    ---------------------------------------------------------------------------------------------
    -- Output values (NoC).
    l_in_val_i <= '1' when (state_w_r = "00" and READ_OK_BUFFER_i = '1') else '0';
    --l_in_val_i <= '1' when (state_w_r = "00" or state_w_r = "10") else '0';

end rtl;
