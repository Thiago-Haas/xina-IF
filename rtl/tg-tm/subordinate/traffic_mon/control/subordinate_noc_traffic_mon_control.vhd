library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- NoC response-packet sequencer for the subordinate isolation TM.
entity subordinate_noc_traffic_mon_control is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    start_i   : in  std_logic;
    is_read_i : in  std_logic;
    done_o    : out std_logic;

    l_in_val_i : in  std_logic;
    l_in_ack_o : out std_logic;

    load_expected_o : out std_logic;
    step_lfsr_o     : out std_logic;
    lfsr_seeded_o   : out std_logic;
    accept_flit_o   : out std_logic;
    flit_idx_o      : out unsigned(2 downto 0);
    is_read_o       : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_control is
  constant C_ST_IDLE      : std_logic_vector(1 downto 0) := "00";
  constant C_ST_ACK       : std_logic_vector(1 downto 0) := "01";
  constant C_ST_WAIT_DROP : std_logic_vector(1 downto 0) := "10";
  constant C_ST_DONE      : std_logic_vector(1 downto 0) := "11";

  signal state_r    : std_logic_vector(1 downto 0) := C_ST_IDLE;
  signal flit_idx_r : unsigned(2 downto 0) := (others => '0');
  signal is_read_r  : std_logic := '0';
  signal load_expected_r : std_logic := '0';
  signal step_lfsr_r     : std_logic := '0';
  signal lfsr_seeded_r   : std_logic := '0';
  signal accept_flit_r   : std_logic := '0';

  signal last_idx_w : unsigned(2 downto 0);
begin
  last_idx_w <= to_unsigned(3, last_idx_w'length) when is_read_r = '0' else
                to_unsigned(4, last_idx_w'length);

  l_in_ack_o <= '1' when state_r = C_ST_ACK else '0';
  done_o <= '1' when state_r = C_ST_DONE else '0';
  load_expected_o <= load_expected_r;
  step_lfsr_o <= step_lfsr_r;
  lfsr_seeded_o <= lfsr_seeded_r;
  accept_flit_o <= accept_flit_r;
  flit_idx_o <= flit_idx_r;
  is_read_o <= is_read_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      load_expected_r <= '0';
      step_lfsr_r <= '0';
      accept_flit_r <= '0';

      if ARESETn = '0' then
        state_r <= C_ST_IDLE;
        flit_idx_r <= (others => '0');
        is_read_r <= '0';
        lfsr_seeded_r <= '0';
      else
        -- Delay this marker by one cycle so the datapath uses seed_i for the
        -- first read-side expected LFSR step.
        if step_lfsr_r = '1' then
          lfsr_seeded_r <= '1';
        end if;

        case state_r is
          when C_ST_IDLE =>
            if start_i = '1' then
              is_read_r <= is_read_i;
              flit_idx_r <= (others => '0');
              load_expected_r <= '1';
              step_lfsr_r <= is_read_i;
              state_r <= C_ST_ACK;
            end if;

          when C_ST_ACK =>
            if l_in_val_i = '1' then
              accept_flit_r <= '1';
              state_r <= C_ST_WAIT_DROP;
            end if;

          when C_ST_WAIT_DROP =>
            if l_in_val_i = '0' then
              if flit_idx_r = last_idx_w then
                state_r <= C_ST_DONE;
              else
                flit_idx_r <= flit_idx_r + 1;
                state_r <= C_ST_ACK;
              end if;
            end if;

          when C_ST_DONE =>
            if start_i = '1' then
              is_read_r <= is_read_i;
              flit_idx_r <= (others => '0');
              load_expected_r <= '1';
              step_lfsr_r <= is_read_i;
              lfsr_seeded_r <= '0';
              state_r <= C_ST_ACK;
            end if;

          when others =>
            state_r <= C_ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
