library IEEE;
use IEEE.std_logic_1164.all;

-- Small optionally-TMR protected register for narrow control/status fields.
-- When TMR is enabled, data_o is majority-voted if correct_enable_i='1' and
-- replica 0 otherwise. error_o reports any replica disagreement.
entity small_tmr_register is
  generic(
    p_WIDTH   : positive := 1;
    p_USE_TMR : boolean := true
  );
  port(
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    write_en_i      : in  std_logic;
    data_i          : in  std_logic_vector(p_WIDTH - 1 downto 0);
    correct_enable_i: in  std_logic := '1';

    data_o  : out std_logic_vector(p_WIDTH - 1 downto 0);
    error_o : out std_logic := '0'
  );
end entity;

architecture rtl of small_tmr_register is
begin
  gen_tmr: if p_USE_TMR generate
    type t_reg_tmr is array (2 downto 0) of std_logic_vector(p_WIDTH - 1 downto 0);

    signal reg_tmr_r : t_reg_tmr := (others => (others => '0'));
    signal corr_w    : std_logic_vector(p_WIDTH - 1 downto 0);
    signal err_w     : std_logic_vector(p_WIDTH - 1 downto 0);

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of reg_tmr_r : signal is "TRUE";

    attribute syn_preserve : boolean;
    attribute syn_preserve of reg_tmr_r : signal is true;
  begin
    gen_vote: for i in p_WIDTH - 1 downto 0 generate
      corr_w(i) <= (reg_tmr_r(0)(i) and reg_tmr_r(1)(i)) or
                   (reg_tmr_r(0)(i) and reg_tmr_r(2)(i)) or
                   (reg_tmr_r(1)(i) and reg_tmr_r(2)(i));

      err_w(i) <= (reg_tmr_r(0)(i) xor reg_tmr_r(1)(i)) or
                  (reg_tmr_r(0)(i) xor reg_tmr_r(2)(i)) or
                  (reg_tmr_r(1)(i) xor reg_tmr_r(2)(i));
    end generate;

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

    data_o <= corr_w when correct_enable_i = '1' else reg_tmr_r(0);
    error_o <= '1' when err_w /= (err_w'range => '0') else '0';
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
