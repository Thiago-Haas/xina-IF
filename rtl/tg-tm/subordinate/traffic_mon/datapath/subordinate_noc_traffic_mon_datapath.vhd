library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xina_noc_pkg.all;

-- Checks manager-side NoC response flits emitted by the subordinate NI.
entity subordinate_noc_traffic_mon_datapath is
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    is_read_i       : in std_logic;
    expected_id_i   : in std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0);
    seed_i          : in std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

    load_expected_i : in std_logic;
    step_lfsr_i     : in std_logic;
    accept_flit_i   : in std_logic;
    flit_idx_i      : in unsigned(2 downto 0);

    l_in_data_i : in std_logic_vector(c_FLIT_WIDTH - 1 downto 0);
    mismatch_o  : out std_logic
  );
end entity;

architecture rtl of subordinate_noc_traffic_mon_datapath is
  signal expected_id_r      : std_logic_vector(c_AXI_ID_WIDTH - 1 downto 0) := (others => '0');
  signal expected_payload_r : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal mismatch_r         : std_logic := '0';
  signal checksum_r         : unsigned(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

  signal lfsr_state_r  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal lfsr_seeded_r : std_logic := '0';
  signal lfsr_input_w  : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal lfsr_next_w   : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);

  signal flit_payload_w : std_logic_vector(c_AXI_DATA_WIDTH - 1 downto 0);
  signal last_idx_w     : unsigned(2 downto 0);
begin
  flit_payload_w <= l_in_data_i(c_AXI_DATA_WIDTH - 1 downto 0);
  last_idx_w <= to_unsigned(3, last_idx_w'length) when is_read_i = '0' else
                to_unsigned(4, last_idx_w'length);

  lfsr_input_w <= seed_i when lfsr_seeded_r = '0' else lfsr_state_r;

  u_lfsr: entity work.subordinate_noc_traffic_mon_lfsr
    generic map(
      p_WIDTH => c_AXI_DATA_WIDTH
    )
    port map(
      data_i => lfsr_input_w,
      next_o => lfsr_next_w
    );

  mismatch_o <= mismatch_r;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        expected_id_r <= (others => '0');
        expected_payload_r <= (others => '0');
        mismatch_r <= '0';
        checksum_r <= (others => '0');
        lfsr_state_r <= (others => '0');
        lfsr_seeded_r <= '0';
      else
        if load_expected_i = '1' then
          expected_id_r <= expected_id_i;
          mismatch_r <= '0';
          checksum_r <= (others => '0');
          if step_lfsr_i = '1' then
            expected_payload_r <= lfsr_next_w;
          else
            expected_payload_r <= (others => '0');
          end if;
        end if;

        if step_lfsr_i = '1' then
          lfsr_state_r <= lfsr_next_w;
          lfsr_seeded_r <= '1';
        end if;

        if accept_flit_i = '1' then
          if flit_idx_i /= last_idx_w then
            checksum_r <= checksum_r + unsigned(flit_payload_w);
          end if;

          if flit_idx_i = to_unsigned(2, flit_idx_i'length) then
            if flit_payload_w(19 downto 15) /= expected_id_r then
              mismatch_r <= '1';
            end if;
            if flit_payload_w(1) /= is_read_i then
              mismatch_r <= '1';
            end if;
            if flit_payload_w(4 downto 2) /= "000" then
              mismatch_r <= '1';
            end if;
          elsif flit_idx_i = to_unsigned(3, flit_idx_i'length) and is_read_i = '1' then
            if flit_payload_w /= expected_payload_r then
              mismatch_r <= '1';
            end if;
          elsif flit_idx_i = last_idx_w then
            if checksum_r /= unsigned(flit_payload_w) then
              mismatch_r <= '1';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
