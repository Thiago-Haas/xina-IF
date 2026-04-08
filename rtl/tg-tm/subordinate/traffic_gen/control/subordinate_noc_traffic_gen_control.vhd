library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- NoC request-packet sequencer for the subordinate isolation TG.
entity subordinate_noc_traffic_gen_control is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i   : in  std_logic;
    is_read_i : in  std_logic;
    done_o    : out std_logic;

    l_out_ack_i : in  std_logic;
    l_out_val_o : out std_logic;

    load_request_o : out std_logic;
    step_lfsr_o    : out std_logic;
    flit_idx_o     : out unsigned(2 downto 0)
  );
end entity;

architecture rtl of subordinate_noc_traffic_gen_control is
  constant C_ST_IDLE     : std_logic_vector(1 downto 0) := "00";
  constant C_ST_WAIT_ACK : std_logic_vector(1 downto 0) := "01";
  constant C_ST_DROP_VAL : std_logic_vector(1 downto 0) := "10";
  constant C_ST_DONE     : std_logic_vector(1 downto 0) := "11";

  signal state_r    : std_logic_vector(1 downto 0) := C_ST_IDLE;
  signal flit_idx_r : unsigned(2 downto 0) := (others => '0');
  signal is_read_r  : std_logic := '0';
  signal load_request_r : std_logic := '0';
  signal step_lfsr_r    : std_logic := '0';

  signal last_idx_w : unsigned(2 downto 0);
begin
  last_idx_w <= to_unsigned(4, last_idx_w'length) when is_read_r = '1' else
                to_unsigned(5, last_idx_w'length);

  l_out_val_o <= '1' when state_r = C_ST_WAIT_ACK else '0';
  done_o <= '1' when state_r = C_ST_DONE else '0';
  load_request_o <= load_request_r;
  step_lfsr_o <= step_lfsr_r;
  flit_idx_o <= flit_idx_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      load_request_r <= '0';
      step_lfsr_r <= '0';

      if ARESETn = '0' then
        state_r <= C_ST_IDLE;
        flit_idx_r <= (others => '0');
        is_read_r <= '0';
      else
        case state_r is
          when C_ST_IDLE =>
            if start_i = '1' then
              is_read_r <= is_read_i;
              flit_idx_r <= (others => '0');
              load_request_r <= '1';
              step_lfsr_r <= not is_read_i;
              state_r <= C_ST_WAIT_ACK;
            end if;

          when C_ST_WAIT_ACK =>
            if l_out_ack_i = '1' then
              state_r <= C_ST_DROP_VAL;
            end if;

          when C_ST_DROP_VAL =>
            if l_out_ack_i = '0' then
              if flit_idx_r = last_idx_w then
                state_r <= C_ST_DONE;
              else
                flit_idx_r <= flit_idx_r + 1;
                state_r <= C_ST_WAIT_ACK;
              end if;
            end if;

          when C_ST_DONE =>
            if start_i = '0' then
              state_r <= C_ST_IDLE;
            end if;

          when others =>
            state_r <= C_ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
