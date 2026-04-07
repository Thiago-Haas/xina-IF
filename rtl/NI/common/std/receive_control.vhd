library IEEE;
library work;

use IEEE.std_logic_1164.all;
use work.xina_noc_pkg.all;

entity receive_control is
    port(
        -- AMBA AXI 5 signals.
        ACLK   : in std_logic;
        ARESETn: in std_logic;

        -- Buffer signals.
        WRITE_OK_BUFFER_i: in std_logic;
        WRITE_BUFFER_o   : out std_logic;

        -- XINA signals.
        l_out_val_o: in std_logic;
        l_out_ack_i: out std_logic
    );
end receive_control;

architecture rtl of receive_control is

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
            when "00" => if (l_out_val_o = '1' and WRITE_OK_BUFFER_i = '1') then next_state_w <= "01"; else next_state_w <= "00"; end if;

            when "01" => next_state_w <= "10";

            when "10" => if (l_out_val_o = '0') then next_state_w <= "00"; else next_state_w <= "10"; end if;

            when others => next_state_w <= "00";
        end case;
    end process;

    ---------------------------------------------------------------------------------------------
    -- Output values (buffer).
    WRITE_BUFFER_o <= '1' when (state_w_r = "01") else '0';

    ---------------------------------------------------------------------------------------------
    -- Output values (NoC).
    l_out_ack_i <= '1' when (state_w_r = "10") else '0';
    --l_out_ack_i <= '1' when (state_w_r = "01" or state_w_r = "10") else '0';

end rtl;
