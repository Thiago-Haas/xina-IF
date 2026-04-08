library IEEE;
use IEEE.std_logic_1164.all;

use work.xina_noc_pkg.all;
use work.xina_subordinate_ni_pkg.all;

-- NoC-side loopback/emulator for the subordinate NI.
--
-- This is the subordinate counterpart to the manager NoC loopback: requests
-- enter ni_subordinate_top through its NoC receive side, and responses leave
-- through its NoC injection side. The loopback therefore emulates the manager
-- side of the NoC transaction while the local AXI slave model supplies the
-- subordinate-side core response.
entity subordinate_noc_loopback is
  generic(
    p_DEST_X : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_DEST_Y : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_X  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1')
  );
  port(
    ACLK    : in std_logic;
    ARESETn : in std_logic;

    start_i   : in std_logic;
    is_read_i : in std_logic;
    id_i      : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    address_i : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    seed_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    done_o     : out std_logic;
    mismatch_o : out std_logic;

    -- Request stream from the emulated manager/NoC into the subordinate NI.
    noc_req_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    noc_req_val_o  : out std_logic;
    noc_req_ack_i  : in  std_logic;

    -- Response stream from the subordinate NI back to the emulated manager/NoC.
    noc_resp_data_i : in  std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    noc_resp_val_i  : in  std_logic;
    noc_resp_ack_o  : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_loopback is
  signal gen_done_w : std_logic;
  signal mon_done_w : std_logic;
  signal gen_done_seen_r : std_logic := '0';
  signal mon_done_seen_r : std_logic := '0';
begin
  u_request_gen: entity work.subordinate_noc_traffic_gen_top
    generic map(
      p_DEST_X => p_DEST_X,
      p_DEST_Y => p_DEST_Y,
      p_SRC_X  => p_SRC_X,
      p_SRC_Y  => p_SRC_Y
    )
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      id_i => id_i,
      address_i => address_i,
      seed_i => seed_i,
      done_o => gen_done_w,
      l_out_data_o => noc_req_data_o,
      l_out_val_o  => noc_req_val_o,
      l_out_ack_i  => noc_req_ack_i
    );

  u_response_mon: entity work.subordinate_noc_traffic_mon_top
    port map(
      ACLK    => ACLK,
      ARESETn => ARESETn,
      start_i => start_i,
      is_read_i => is_read_i,
      expected_id_i => id_i,
      seed_i => seed_i,
      done_o => mon_done_w,
      mismatch_o => mismatch_o,
      l_in_data_i => noc_resp_data_i,
      l_in_val_i  => noc_resp_val_i,
      l_in_ack_o  => noc_resp_ack_o
    );

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        gen_done_seen_r <= '0';
        mon_done_seen_r <= '0';
      elsif start_i = '1' then
        gen_done_seen_r <= '0';
        mon_done_seen_r <= '0';
      else
        if gen_done_w = '1' then
          gen_done_seen_r <= '1';
        end if;
        if mon_done_w = '1' then
          mon_done_seen_r <= '1';
        end if;
      end if;
    end if;
  end process;

  done_o <= gen_done_seen_r and mon_done_seen_r;
end architecture;
