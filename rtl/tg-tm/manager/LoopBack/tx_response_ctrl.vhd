library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- TX-side controller: sends a full response packet (hdr0,hdr1,hdr2,[payload],checksum)
-- using tx_sel to select which word the datapath must present.
entity tx_response_ctrl is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    i_enable : in std_logic;
    i_start  : in std_logic; -- 1-cycle pulse to start a new response

    -- TX (to NI)
    lout_ack : in  std_logic;
    lout_val : out std_logic;
    tx_sel   : out unsigned(2 downto 0);

    o_dp_pld_ridx : out unsigned(15 downto 0);

    -- response shape
    i_is_read_resp  : in std_logic;
    i_payload_words : in unsigned(15 downto 0);

    o_done : out std_logic
  );
end entity;

architecture rtl of tx_response_ctrl is
  type t_state is (s_idle, s_hdr0, s_hdr1, s_hdr2, s_payload, s_checksum);
  signal st : t_state := s_idle;

  signal ridx         : unsigned(15 downto 0) := (others => '0');
  signal payload_left : unsigned(15 downto 0) := (others => '0');

  signal r_done : std_logic := '0';

  -- internal outputs (avoid reading OUT ports)
  signal val_i : std_logic := '0';
  signal sel_i : unsigned(2 downto 0) := (others => '0');
  signal tx_hs : std_logic := '0';
begin
  o_dp_pld_ridx <= ridx;
  o_done <= r_done;

  lout_val <= val_i;
  tx_sel   <= sel_i;

  -- comb val/sel from state
  process(all)
  begin
    val_i <= '0';
    sel_i <= (others => '0');

    if i_enable = '1' then
      case st is
        when s_hdr0     => val_i <= '1'; sel_i <= "000";
        when s_hdr1     => val_i <= '1'; sel_i <= "001";
        when s_hdr2     => val_i <= '1'; sel_i <= "010";
        when s_payload  => val_i <= '1'; sel_i <= "011";
        when s_checksum => val_i <= '1'; sel_i <= "100";
        when others     => val_i <= '0'; sel_i <= (others => '0');
      end case;
    end if;
  end process;

  tx_hs <= val_i and lout_ack;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st <= s_idle;
        ridx <= (others => '0');
        payload_left <= (others => '0');
        r_done <= '0';
      else
        r_done <= '0';

        if i_enable = '0' then
          st <= s_idle;
          ridx <= (others => '0');
          payload_left <= (others => '0');
        else
          if i_start = '1' then
            ridx <= (others => '0');
            payload_left <= i_payload_words;
            st <= s_hdr0;
          else
            case st is
              when s_idle =>
                null;

              when s_hdr0 =>
                if tx_hs='1' then st <= s_hdr1; end if;

              when s_hdr1 =>
                if tx_hs='1' then st <= s_hdr2; end if;

              when s_hdr2 =>
                if tx_hs='1' then
                  if (i_is_read_resp='1') and (payload_left /= 0) then
                    st <= s_payload;
                  else
                    st <= s_checksum;
                  end if;
                end if;

              when s_payload =>
                if tx_hs='1' then
                  ridx <= ridx + 1;
                  if payload_left = 1 then
                    st <= s_checksum;
                  end if;
                  payload_left <= payload_left - 1;
                end if;

              when s_checksum =>
                if tx_hs='1' then
                  r_done <= '1';
                  st <= s_idle;
                end if;
            end case;
          end if;
        end if;
      end if;
    end if;
  end process;

end rtl;
