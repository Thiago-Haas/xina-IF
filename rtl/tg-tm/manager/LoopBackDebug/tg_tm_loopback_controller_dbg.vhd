library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ft_pkg.all;
use work.xina_ni_ft_pkg.all;

-- Debuggable controller (adds state visibility + counters).
entity tg_tm_loopback_controller_dbg is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- Request stream from NI
    i_lin_data : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_lin_val  : in  std_logic;
    o_lin_ack  : out std_logic;

    -- Response stream to NI
    o_lout_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_lout_val  : out std_logic;
    i_lout_ack  : in  std_logic;

    -- Capture interface to datapath
    o_cap_en   : out std_logic;
    o_cap_flit : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_cap_idx  : out unsigned(5 downto 0);
    o_cap_last : out std_logic;

    -- Decoded request summary from datapath
    i_req_ready    : in  std_logic;
    i_req_is_write : in  std_logic;
    i_req_is_read  : in  std_logic;
    i_req_len      : in  unsigned(7 downto 0);

    -- Response headers from datapath
    i_resp_hdr0 : in  std_logic_vector(31 downto 0);
    i_resp_hdr1 : in  std_logic_vector(31 downto 0);
    i_resp_hdr2 : in  std_logic_vector(31 downto 0);

    -- Payload access
    o_rd_payload_idx : out unsigned(7 downto 0);
    i_rd_payload     : in  std_logic_vector(31 downto 0);

    -- Availability tracking (optional)
    i_hold_valid : in  std_logic;
    o_hold_clr   : out std_logic;

    -- DEBUG
    o_dbg_state         : out std_logic_vector(2 downto 0);
    o_dbg_cap_idx       : out unsigned(5 downto 0);
    o_dbg_seen_last     : out std_logic;
    o_dbg_payload_idx   : out unsigned(7 downto 0);
    o_dbg_payload_words : out unsigned(8 downto 0);
    o_dbg_resp_is_read  : out std_logic
  );
end entity;

architecture rtl of tg_tm_loopback_controller_dbg is

  function flit_ctrl(f : std_logic_vector(c_FLIT_WIDTH-1 downto 0)) return std_logic is
  begin
    return f(f'left);
  end function;

  function mk_flit(ctrl : std_logic; data32 : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable f : std_logic_vector(c_FLIT_WIDTH-1 downto 0);
  begin
    f := (others => '0');
    f(f'left) := ctrl;
    f(31 downto 0) := data32;
    return f;
  end function;

  type state_t is (S_CAP, S_RESP_HDR0, S_RESP_HDR1, S_RESP_HDR2,
                   S_RESP_PAYLOAD, S_RESP_CHK_DELIM, S_RESP_CHK_WORD);

  signal st : state_t := S_CAP;

  signal cap_idx_r   : unsigned(5 downto 0) := (others => '0');
  signal seen_last_r : std_logic := '0';

  signal payload_idx_r : unsigned(7 downto 0) := (others => '0');
  signal payload_words : unsigned(8 downto 0) := (others => '0'); -- len+1 up to 256

  signal resp_is_read : std_logic := '0';

  signal lout_val_r  : std_logic := '0';
  signal lout_data_r : std_logic_vector(c_FLIT_WIDTH-1 downto 0) := (others => '0');

  function st_to_slv(s: state_t) return std_logic_vector is
  begin
    case s is
      when S_CAP           => return "000";
      when S_RESP_HDR0     => return "001";
      when S_RESP_HDR1     => return "010";
      when S_RESP_HDR2     => return "011";
      when S_RESP_PAYLOAD  => return "100";
      when S_RESP_CHK_DELIM=> return "101";
      when S_RESP_CHK_WORD => return "110";
      when others          => return "111";
    end case;
  end function;

begin

  -- DEBUG outputs
  o_dbg_state         <= st_to_slv(st);
  o_dbg_cap_idx       <= cap_idx_r;
  o_dbg_seen_last     <= seen_last_r;
  o_dbg_payload_idx   <= payload_idx_r;
  o_dbg_payload_words <= payload_words;
  o_dbg_resp_is_read  <= resp_is_read;

  o_lout_val  <= lout_val_r;
  o_lout_data <= lout_data_r;

  o_cap_flit <= i_lin_data;

  -- capture side
  o_lin_ack <= '1' when st = S_CAP else '0';

  o_cap_en <= i_lin_val and o_lin_ack;
  o_cap_idx <= cap_idx_r;
  o_cap_last <= (i_lin_val and o_lin_ack and flit_ctrl(i_lin_data));

  -- payload read index
  o_rd_payload_idx <= payload_idx_r;

  -- hold clear: only pulse after finishing a READ response (optional)
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        o_hold_clr <= '0';
      else
        o_hold_clr <= '0';
        if st = S_RESP_CHK_WORD and lout_val_r = '1' and i_lout_ack = '1' then
          if resp_is_read = '1' then
            o_hold_clr <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- main FSM
  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        st <= S_CAP;
        cap_idx_r <= (others => '0');
        seen_last_r <= '0';
        payload_idx_r <= (others => '0');
        payload_words <= (others => '0');
        resp_is_read <= '0';
        lout_val_r <= '0';
        lout_data_r <= (others => '0');
      else
        case st is
          when S_CAP =>
            lout_val_r <= '0';
            if i_lin_val = '1' and o_lin_ack = '1' then
              if flit_ctrl(i_lin_data) = '1' then
                seen_last_r <= '1';
              end if;
              cap_idx_r <= cap_idx_r + 1;
            end if;

            if i_req_ready = '1' and seen_last_r = '1' then
              resp_is_read <= i_req_is_read;
              payload_words <= unsigned('0' & i_req_len) + 1;
              payload_idx_r <= (others => '0');
              cap_idx_r <= (others => '0');
              seen_last_r <= '0';
              st <= S_RESP_HDR0;
            end if;

          when S_RESP_HDR0 =>
            lout_val_r  <= '1';
            lout_data_r <= mk_flit('0', i_resp_hdr0);
            if i_lout_ack = '1' then
              st <= S_RESP_HDR1;
            end if;

          when S_RESP_HDR1 =>
            lout_val_r  <= '1';
            lout_data_r <= mk_flit('0', i_resp_hdr1);
            if i_lout_ack = '1' then
              st <= S_RESP_HDR2;
            end if;

          when S_RESP_HDR2 =>
            lout_val_r  <= '1';
            lout_data_r <= mk_flit('0', i_resp_hdr2);
            if i_lout_ack = '1' then
              if resp_is_read = '1' then
                if payload_words = 0 then
                  st <= S_RESP_CHK_DELIM;
                else
                  st <= S_RESP_PAYLOAD;
                end if;
              else
                st <= S_RESP_CHK_DELIM;
              end if;
            end if;

          when S_RESP_PAYLOAD =>
            lout_val_r  <= '1';
            lout_data_r <= mk_flit('0', i_rd_payload);
            if i_lout_ack = '1' then
              if payload_idx_r = payload_words - 1 then
                st <= S_RESP_CHK_DELIM;
              else
                payload_idx_r <= payload_idx_r + 1;
              end if;
            end if;

          when S_RESP_CHK_DELIM =>
            lout_val_r  <= '1';
            lout_data_r <= mk_flit('1', (others => '0'));
            if i_lout_ack = '1' then
              st <= S_RESP_CHK_WORD;
            end if;

          when S_RESP_CHK_WORD =>
            lout_val_r  <= '1';
            lout_data_r <= mk_flit('0', (others => '0'));
            if i_lout_ack = '1' then
              lout_val_r <= '0';
              st <= S_CAP;
            end if;

          when others =>
            st <= S_CAP;
        end case;
      end if;
    end if;
  end process;

end architecture;
