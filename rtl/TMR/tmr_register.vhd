library IEEE;
use IEEE.std_logic_1164.all;

entity tmr_register is
  generic(
    p_WIDTH   : positive := 1;
    p_USE_TMR : boolean := true
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    write_en_i       : in  std_logic;
    data_i           : in  std_logic_vector(p_WIDTH - 1 downto 0);
    correct_enable_i : in  std_logic := '1';

    data_o  : out std_logic_vector(p_WIDTH - 1 downto 0);
    error_o : out std_logic := '0'
  );
end entity;

architecture rtl of tmr_register is
begin
  gen_tmr: if p_USE_TMR generate
    type t_reg_tmr is array (2 downto 0) of std_logic_vector(p_WIDTH - 1 downto 0);

    signal reg_tmr_r : t_reg_tmr := (others => (others => '0'));
    signal corr_w    : std_logic_vector(p_WIDTH - 1 downto 0);

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of reg_tmr_r : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of reg_tmr_r : signal is true;
  begin
    process(ACLK)
    begin
      if rising_edge(ACLK) then
        if ARESETn = '0' then
          reg_tmr_r <= (others => (others => '0'));
        elsif write_en_i = '1' then
          reg_tmr_r <= (others => data_i);
        end if;
      end if;
    end process;

    u_tmr_voter_block: entity work.tmr_voter_block
      generic map(
        p_WIDTH => p_WIDTH
      )
      port map(
        A_i => reg_tmr_r(0),
        B_i => reg_tmr_r(1),
        C_i => reg_tmr_r(2),
        correct_enable_i => correct_enable_i,
        corrected_o => corr_w,
        error_bits_o => open,
        error_o => error_o
      );

    data_o <= corr_w;
  end generate;

  gen_plain: if not p_USE_TMR generate
    signal reg_r : std_logic_vector(p_WIDTH - 1 downto 0) := (others => '0');

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of reg_r : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of reg_r : signal is true;
  begin
    process(ACLK)
    begin
      if rising_edge(ACLK) then
        if ARESETn = '0' then
          reg_r <= (others => '0');
        elsif write_en_i = '1' then
          reg_r <= data_i;
        end if;
      end if;
    end process;

    data_o <= reg_r;
    error_o <= '0';
  end generate;
end architecture;
