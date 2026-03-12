library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_ctrl is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    lin_ctrl_i : in  std_logic;
    lin_val_i  : in  std_logic;
    lin_ack_o  : out std_logic;

    lout_val_o  : out std_logic;
    lout_ack_i  : in  std_logic;
    tx_next_is_read_o : out std_logic;
    tx_flit_sel_o     : out std_logic_vector(2 downto 0); -- 000 H0, 001 H1, 010 H2, 011 PAYLOAD, 100 CHKSUM

    cap_en_o   : out std_logic;
    cap_flit_ctrl_o : out std_logic;
    cap_idx_o  : out unsigned(5 downto 0);

    hold_valid_i : in  std_logic    -- DP pulse (payload captured)
  );
end entity;

architecture rtl of lb_ctrl is
  constant C_ST_RX_WAIT_VAL   : std_logic_vector(2 downto 0) := "000";
  constant C_ST_RX_ACK_HI     : std_logic_vector(2 downto 0) := "001";
  constant C_ST_RX_WAIT_DROP  : std_logic_vector(2 downto 0) := "010";
  constant C_ST_TX_WAIT_ACK_LO: std_logic_vector(2 downto 0) := "011";
  constant C_ST_TX_WAIT_ACCEPT: std_logic_vector(2 downto 0) := "100";
  signal st_r : std_logic_vector(2 downto 0) := C_ST_RX_WAIT_VAL;

  constant C_TX_PHASE_H0  : std_logic_vector(2 downto 0) := "000";
  constant C_TX_PHASE_H1  : std_logic_vector(2 downto 0) := "001";
  constant C_TX_PHASE_H2  : std_logic_vector(2 downto 0) := "010";
  constant C_TX_PHASE_PAY : std_logic_vector(2 downto 0) := "011";
  constant C_TX_PHASE_CKS : std_logic_vector(2 downto 0) := "100";
  signal tx_phase_r : std_logic_vector(2 downto 0) := C_TX_PHASE_H0;

  signal cap_idx_r       : unsigned(5 downto 0) := (others => '0');
  signal rx_seen_first_r : std_logic := '0';
  signal seen_last_r     : std_logic := '0';

  signal cap_en_r        : std_logic := '0';
  signal lin_ack_r       : std_logic := '0';

  signal tx_next_is_read_r : std_logic := '0';
  signal tx_has_payload_r  : std_logic := '0';

  signal hold_valid_r    : std_logic := '0';




  -- Xilinx attributes to prevent optimization of TMR
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of cap_en_r : signal is "TRUE";
  attribute DONT_TOUCH of cap_idx_r : signal is "TRUE";
  attribute DONT_TOUCH of hold_valid_r : signal is "TRUE";
  attribute DONT_TOUCH of lin_ack_r : signal is "TRUE";
  attribute DONT_TOUCH of rx_seen_first_r : signal is "TRUE";
  attribute DONT_TOUCH of seen_last_r : signal is "TRUE";
  attribute DONT_TOUCH of st_r : signal is "TRUE";
  attribute DONT_TOUCH of tx_has_payload_r : signal is "TRUE";
  attribute DONT_TOUCH of tx_next_is_read_r : signal is "TRUE";
  attribute DONT_TOUCH of tx_phase_r : signal is "TRUE";
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_preserve : boolean;
  attribute syn_preserve of cap_en_r : signal is true;
  attribute syn_preserve of cap_idx_r : signal is true;
  attribute syn_preserve of hold_valid_r : signal is true;
  attribute syn_preserve of lin_ack_r : signal is true;
  attribute syn_preserve of rx_seen_first_r : signal is true;
  attribute syn_preserve of seen_last_r : signal is true;
  attribute syn_preserve of st_r : signal is true;
  attribute syn_preserve of tx_has_payload_r : signal is true;
  attribute syn_preserve of tx_next_is_read_r : signal is true;
  attribute syn_preserve of tx_phase_r : signal is true;
begin
  lin_ack_o       <= lin_ack_r;
  cap_en_o        <= cap_en_r;
  cap_flit_ctrl_o <= lin_ctrl_i;
  cap_idx_o       <= cap_idx_r;
  tx_next_is_read_o <= tx_next_is_read_r;

  lout_val_o <= '1' when st_r = C_ST_TX_WAIT_ACCEPT else
                '0';

  tx_flit_sel_o <= "000" when tx_phase_r = C_TX_PHASE_H0 else
                   "001" when tx_phase_r = C_TX_PHASE_H1 else
                   "010" when tx_phase_r = C_TX_PHASE_H2 else
                   "011" when tx_phase_r = C_TX_PHASE_PAY else
                   "100";

  process(ACLK)
    variable v_is_checksum : std_logic;
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st_r <= C_ST_RX_WAIT_VAL;
        tx_phase_r        <= C_TX_PHASE_H0;
        cap_idx_r        <= (others => '0');
        rx_seen_first_r   <= '0';
        seen_last_r       <= '0';
        cap_en_r          <= '0';
        lin_ack_r         <= '0';
        tx_next_is_read_r <= '0';
        tx_has_payload_r  <= '0';
        hold_valid_r      <= '0';
      else
        cap_en_r   <= '0';
        lin_ack_r  <= '0';

        if hold_valid_i = '1' then
          hold_valid_r <= '1';
        end if;

        case st_r is
          when C_ST_RX_WAIT_VAL =>
            if lin_val_i = '1' then
              cap_en_r <= '1';
              v_is_checksum := '0';
              if (rx_seen_first_r = '1') and (lin_ctrl_i = '1') then
                v_is_checksum := '1';
              end if;
              if v_is_checksum = '1' then
                seen_last_r <= '1';
                cap_idx_r   <= (others => '0');
              else
                rx_seen_first_r <= '1';
                cap_idx_r <= cap_idx_r + 1;
              end if;
              lin_ack_r <= '1';
              st_r <= C_ST_RX_ACK_HI;
            end if;

          when C_ST_RX_ACK_HI =>
            st_r <= C_ST_RX_WAIT_DROP;

          when C_ST_RX_WAIT_DROP =>
            if lin_val_i = '0' then
              if seen_last_r = '1' then
                if (tx_next_is_read_r = '1') and (hold_valid_r = '1') then
                  tx_has_payload_r <= '1';
                else
                  tx_has_payload_r <= '0';
                end if;
                seen_last_r     <= '0';
                rx_seen_first_r <= '0';
                cap_idx_r       <= (others => '0');
                tx_phase_r <= C_TX_PHASE_H0;
                st_r <= C_ST_TX_WAIT_ACK_LO;
              else
                st_r <= C_ST_RX_WAIT_VAL;
              end if;
            end if;

          when C_ST_TX_WAIT_ACK_LO =>
            if lout_ack_i = '0' then
              st_r <= C_ST_TX_WAIT_ACCEPT;
            end if;

          when C_ST_TX_WAIT_ACCEPT =>
            if lout_ack_i = '1' then
              case tx_phase_r is
                when C_TX_PHASE_H0 =>
                  tx_phase_r <= C_TX_PHASE_H1;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_H1 =>
                  tx_phase_r <= C_TX_PHASE_H2;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_H2 =>
                  if tx_has_payload_r = '1' then
                    tx_phase_r <= C_TX_PHASE_PAY;
                  else
                    tx_phase_r <= C_TX_PHASE_CKS;
                  end if;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_PAY =>
                  tx_phase_r <= C_TX_PHASE_CKS;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_CKS =>
                  if tx_next_is_read_r = '1' then
                    hold_valid_r <= '0';
                  end if;
                  tx_next_is_read_r <= not tx_next_is_read_r;
                  st_r <= C_ST_RX_WAIT_VAL;
                when others =>
                  tx_phase_r <= C_TX_PHASE_H0;
                  st_r <= C_ST_RX_WAIT_VAL;
              end case;
            end if;

          when others =>
            st_r <= C_ST_RX_WAIT_VAL;
        end case;
      end if;
    end if;
  end process;
end architecture;
