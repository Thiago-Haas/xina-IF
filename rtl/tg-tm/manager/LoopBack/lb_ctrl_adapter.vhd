library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.xina_ni_ft_pkg.all;

-- Control-side adapter kept outside TMR:
--  * rebuilds captured flit for lb_dp
--  * rebuilds response flit for lout_data
entity lb_ctrl_adapter is
  port (
    ACLK            : in  std_logic;
    ARESETn         : in  std_logic;
    i_lin_data      : in  std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    i_cap_flit_ctrl : in  std_logic;

    i_lout_val       : in  std_logic;
    i_lout_ack       : in  std_logic;
    i_tx_next_is_read: in  std_logic;
    i_tx_has_payload : in  std_logic;
    i_rd_payload     : in  std_logic_vector(31 downto 0);

    o_cap_flit  : out std_logic_vector(c_FLIT_WIDTH-1 downto 0);
    o_lout_data : out std_logic_vector(c_FLIT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of lb_ctrl_adapter is
  constant c_RESP_HDR0_CONST : std_logic_vector(31 downto 0) := x"00000000";
  constant c_RESP_HDR1_CONST : std_logic_vector(31 downto 0) := x"00000100";
  constant c_HDR2_WR         : std_logic_vector(31 downto 0) := x"00000001";
  constant c_HDR2_RD         : std_logic_vector(31 downto 0) := x"00000002";
  signal r_tx_active    : std_logic := '0';
  signal r_tx_idx       : unsigned(3 downto 0) := (others => '0');
  signal w_tx_last      : unsigned(3 downto 0);
begin
  -- control bit comes from voted controller path; payload comes direct.
  o_cap_flit <= i_cap_flit_ctrl & i_lin_data(c_AXI_DATA_WIDTH-1 downto 0);

  w_tx_last <= to_unsigned(3, w_tx_last'length) + to_unsigned(0, w_tx_last'length) when i_tx_has_payload = '0' else
               to_unsigned(3, w_tx_last'length) + to_unsigned(1, w_tx_last'length);

  o_lout_data <= ('1' & c_RESP_HDR0_CONST) when r_tx_idx = to_unsigned(0, r_tx_idx'length) else
                 ('0' & c_RESP_HDR1_CONST) when r_tx_idx = to_unsigned(1, r_tx_idx'length) else
                 ('0' & c_HDR2_RD)         when (r_tx_idx = to_unsigned(2, r_tx_idx'length) and i_tx_next_is_read = '1') else
                 ('0' & c_HDR2_WR)         when (r_tx_idx = to_unsigned(2, r_tx_idx'length) and i_tx_next_is_read = '0') else
                 ('1' & x"00000000")       when r_tx_idx = w_tx_last else
                 ('0' & i_rd_payload);

  p_tx_seq: process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_tx_active <= '0';
        r_tx_idx    <= (others => '0');
      else
        if r_tx_active = '0' then
          if i_lout_val = '1' then
            r_tx_active <= '1';
            r_tx_idx    <= (others => '0');
          end if;
        elsif (i_lout_val = '1' and i_lout_ack = '1') then
          if r_tx_idx = w_tx_last then
            r_tx_active <= '0';
            r_tx_idx    <= (others => '0');
          else
            r_tx_idx <= r_tx_idx + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
