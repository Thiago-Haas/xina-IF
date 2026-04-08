library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;

-- Builds manager-style NoC request flits for the subordinate isolation TG.
entity subordinate_noc_traffic_gen_datapath is
  generic(
    p_DEST_X : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_DEST_Y : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_X  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '0');
    p_SRC_Y  : std_logic_vector((c_AXI_ADDR_WIDTH / 4) - 1 downto 0) := (others => '1')
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    is_read_i : in std_logic;
    id_i      : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    address_i : in std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0);
    seed_i    : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    load_request_i : in std_logic;
    step_lfsr_i    : in std_logic;
    flit_idx_i     : in unsigned(2 downto 0);

    l_out_data_o : out std_logic_vector(c_FLIT_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of subordinate_noc_traffic_gen_datapath is
  signal is_read_r : std_logic := '0';
  signal id_r      : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal addr_r    : std_logic_vector(c_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal payload_r : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  signal lfsr_state_r  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal lfsr_seeded_r : std_logic := '0';
  signal lfsr_input_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_next_w   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal h_dest_w      : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_src_w       : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_interface_w : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal h_address_w   : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal payload_w     : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal trailer_w     : std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
  signal checksum_w    : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal payload_checksum_w : unsigned(c_AXI_DATA_WIDTH - 1 downto 0);
begin
  h_dest_w      <= '1' & p_DEST_X & p_DEST_Y;
  h_src_w       <= '0' & p_SRC_X & p_SRC_Y;
  h_interface_w <= '0' & "000000000000" & id_r & x"00" & "01" & "000" & is_read_r & '0';
  h_address_w   <= '0' & addr_r(c_AXI_ADDR_WIDTH - 1 downto c_AXI_DATA_WIDTH);
  payload_w     <= '0' & payload_r;
  payload_checksum_w <= unsigned(payload_r) when is_read_r = '0' else
                        to_unsigned(0, c_AXI_DATA_WIDTH);

  checksum_w <= std_logic_vector(unsigned(h_dest_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_src_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_interface_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 unsigned(h_address_w(c_AXI_DATA_WIDTH - 1 downto 0)) +
                                 payload_checksum_w);
  trailer_w <= '1' & checksum_w;

  lfsr_input_w <= seed_i when lfsr_seeded_r = '0' else lfsr_state_r;

  u_lfsr: entity work.subordinate_noc_traffic_gen_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      data_i => lfsr_input_w,
      next_o => lfsr_next_w
    );

  l_out_data_o <= h_dest_w      when flit_idx_i = to_unsigned(0, flit_idx_i'length) else
                  h_src_w       when flit_idx_i = to_unsigned(1, flit_idx_i'length) else
                  h_interface_w when flit_idx_i = to_unsigned(2, flit_idx_i'length) else
                  h_address_w   when flit_idx_i = to_unsigned(3, flit_idx_i'length) else
                  payload_w     when flit_idx_i = to_unsigned(4, flit_idx_i'length) and is_read_r = '0' else
                  trailer_w;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        is_read_r <= '0';
        id_r <= (others => '0');
        addr_r <= (others => '0');
        payload_r <= (others => '0');
        lfsr_state_r <= (others => '0');
        lfsr_seeded_r <= '0';
      else
        if load_request_i = '1' then
          is_read_r <= is_read_i;
          id_r <= id_i;
          addr_r <= address_i;
          if step_lfsr_i = '1' then
            payload_r <= lfsr_next_w;
          else
            payload_r <= (others => '0');
          end if;
        end if;

        if step_lfsr_i = '1' then
          lfsr_state_r <= lfsr_next_w;
          lfsr_seeded_r <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
