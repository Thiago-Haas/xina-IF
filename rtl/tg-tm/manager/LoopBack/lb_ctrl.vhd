library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

entity lb_ctrl is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_lin_ctrl : in  std_logic;
    i_lin_val  : in  std_logic;
    o_lin_ack  : out std_logic;

    o_lout_val  : out std_logic;
    i_lout_ack  : in  std_logic;
    o_tx_next_is_read : out std_logic;
    o_tx_flit_sel     : out std_logic_vector(2 downto 0); -- 000 H0, 001 H1, 010 H2, 011 PAYLOAD, 100 CHKSUM

    o_cap_en   : out std_logic;
    o_cap_flit_ctrl : out std_logic;
    o_cap_idx  : out unsigned(5 downto 0);

    i_hold_valid : in  std_logic    -- DP pulse (payload captured)
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

  signal r_cap_idx_r       : unsigned(5 downto 0) := (others => '0');
  signal r_rx_seen_first_r : std_logic := '0';
  signal r_seen_last_r     : std_logic := '0';

  signal cap_en_r        : std_logic := '0';
  signal lin_ack_r       : std_logic := '0';

  signal r_tx_next_is_read_r : std_logic := '0';
  signal r_tx_has_payload_r  : std_logic := '0';

  signal r_hold_valid_r    : std_logic := '0';
begin
  o_lin_ack       <= lin_ack_r;
  o_cap_en        <= cap_en_r;
  o_cap_flit_ctrl <= i_lin_ctrl;
  o_cap_idx       <= r_cap_idx_r;
  o_tx_next_is_read <= r_tx_next_is_read_r;

  o_lout_val <= '1' when st_r = C_ST_TX_WAIT_ACCEPT else
                '0';

  o_tx_flit_sel <= "000" when tx_phase_r = C_TX_PHASE_H0 else
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
        r_cap_idx_r        <= (others => '0');
        r_rx_seen_first_r   <= '0';
        r_seen_last_r       <= '0';
        cap_en_r          <= '0';
        lin_ack_r         <= '0';
        r_tx_next_is_read_r <= '0';
        r_tx_has_payload_r  <= '0';
        r_hold_valid_r      <= '0';
      else
        cap_en_r   <= '0';
        lin_ack_r  <= '0';

        if i_hold_valid = '1' then
          r_hold_valid_r <= '1';
        end if;

        case st_r is
          when C_ST_RX_WAIT_VAL =>
            if i_lin_val = '1' then
              cap_en_r <= '1';
              v_is_checksum := '0';
              if (r_rx_seen_first_r = '1') and (i_lin_ctrl = '1') then
                v_is_checksum := '1';
              end if;
              if v_is_checksum = '1' then
                r_seen_last_r <= '1';
                r_cap_idx_r   <= (others => '0');
              else
                r_rx_seen_first_r <= '1';
                r_cap_idx_r <= r_cap_idx_r + 1;
              end if;
              lin_ack_r <= '1';
              st_r <= C_ST_RX_ACK_HI;
            end if;

          when C_ST_RX_ACK_HI =>
            st_r <= C_ST_RX_WAIT_DROP;

          when C_ST_RX_WAIT_DROP =>
            if i_lin_val = '0' then
              if r_seen_last_r = '1' then
                if (r_tx_next_is_read_r = '1') and (r_hold_valid_r = '1') then
                  r_tx_has_payload_r <= '1';
                else
                  r_tx_has_payload_r <= '0';
                end if;
                r_seen_last_r     <= '0';
                r_rx_seen_first_r <= '0';
                r_cap_idx_r       <= (others => '0');
                tx_phase_r <= C_TX_PHASE_H0;
                st_r <= C_ST_TX_WAIT_ACK_LO;
              else
                st_r <= C_ST_RX_WAIT_VAL;
              end if;
            end if;

          when C_ST_TX_WAIT_ACK_LO =>
            if i_lout_ack = '0' then
              st_r <= C_ST_TX_WAIT_ACCEPT;
            end if;

          when C_ST_TX_WAIT_ACCEPT =>
            if i_lout_ack = '1' then
              case tx_phase_r is
                when C_TX_PHASE_H0 =>
                  tx_phase_r <= C_TX_PHASE_H1;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_H1 =>
                  tx_phase_r <= C_TX_PHASE_H2;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_H2 =>
                  if r_tx_has_payload_r = '1' then
                    tx_phase_r <= C_TX_PHASE_PAY;
                  else
                    tx_phase_r <= C_TX_PHASE_CKS;
                  end if;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_PAY =>
                  tx_phase_r <= C_TX_PHASE_CKS;
                  st_r <= C_ST_TX_WAIT_ACK_LO;
                when C_TX_PHASE_CKS =>
                  if r_tx_next_is_read_r = '1' then
                    r_hold_valid_r <= '0';
                  end if;
                  r_tx_next_is_read_r <= not r_tx_next_is_read_r;
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
