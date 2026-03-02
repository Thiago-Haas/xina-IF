library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity tmr_register is
  generic (
    DATA_WIDTH    : integer;
    TMR_ENABLE    : boolean;
    RESET_VALUE   : std_logic_vector;
    INJECT_ERROR  : boolean
  );
  port (
    correct_en_i : in  std_logic;
    clear_i      : in  std_logic;
    write_en_i   : in  std_logic;
    valid_i      : in  std_logic;
    data_i       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    rstn_i       : in  std_logic;
    clk_i        : in  std_logic;
    error_o      : out std_logic;
    data_err_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    data_o       : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end entity;

architecture arch of tmr_register is

begin

  -----------------------------------------------------------------------------------------------
  --------------------------------------- TMR DISABLED ------------------------------------------
  -----------------------------------------------------------------------------------------------

  normal_g : if not TMR_ENABLE generate
    signal reg_r : std_logic_vector(DATA_WIDTH-1 downto 0);
    -- Synplify flags
    attribute syn_preserve : boolean;
    attribute syn_preserve of reg_r : signal is true;
  begin
    p_REG : process(clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        reg_r <= RESET_VALUE;
      elsif rising_edge(clk_i) then
        if clear_i = '1' then
          reg_r <= RESET_VALUE;
        elsif write_en_i = '1' then
          reg_r <= data_i;
        end if;
      end if;
    end process;
    error_o <= '0';
    data_err_o <= (others => '0');
    data_o  <= reg_r;
  end generate;

  -----------------------------------------------------------------------------------------------
  ---------------------------------------- TMR ENABLED ------------------------------------------
  -----------------------------------------------------------------------------------------------

  tmr_g : if TMR_ENABLE generate
    signal reg0_r           : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal reg1_r           : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal reg2_r           : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal wdata_w          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal corrected_data_w : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal error_w          : std_logic;

    -- Xilinx attributes to prevent optimization of TMR
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of reg0_r : signal is "TRUE";
    attribute DONT_TOUCH of reg1_r : signal is "TRUE";
    attribute DONT_TOUCH of reg2_r : signal is "TRUE";
    -- Synplify attributes to prevent optimization of TMR
    attribute syn_preserve : boolean;
    attribute syn_preserve of reg0_r : signal is true;
    attribute syn_preserve of reg1_r : signal is true;
    attribute syn_preserve of reg2_r : signal is true;
  begin
    p_REG : process(clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        reg0_r <= RESET_VALUE;
        reg1_r <= RESET_VALUE;
        reg2_r <= RESET_VALUE;
      elsif rising_edge(clk_i) then
        if clear_i = '1' then
          reg0_r <= RESET_VALUE;
          reg1_r <= RESET_VALUE;
          reg2_r <= RESET_VALUE;
        -- write operation
        elsif write_en_i = '1' then
          reg0_r <= wdata_w;
          reg1_r <= data_i;
          reg2_r <= data_i;
        -- if there is one or more errors
        elsif correct_en_i = '1' and error_w = '1' then
          -- rewrite registers with corrected data
          reg0_r <= corrected_data_w;
          reg1_r <= corrected_data_w;
          reg2_r <= corrected_data_w;
        end if;
      end if;
    end process;


    inject_error_g : if INJECT_ERROR generate
      signal inj_counter_r : std_logic_vector(15 downto 0);
    begin
      -- Inject errors based on counter
      inj_counter_p : process (rstn_i, clk_i)
      begin
        if rstn_i = '0' then
          inj_counter_r <= (others => '0');
        elsif falling_edge(clk_i) then
          if write_en_i = '1' and clear_i = '0' then
            if inj_counter_r(inj_counter_r'length-1) = '0' then -- injects only once
              inj_counter_r <= std_logic_vector(unsigned(inj_counter_r) + 1);
            end if;
          end if;
        end if;
      end process;

      wdata_w <= (data_i xor (data_i'high downto 1 => '0') & '1') when inj_counter_r = ("00" & (inj_counter_r'length-3 downto 0 => '1')) else -- inject one bit error
                 data_i;

    else generate
      -- NORMAL OPERATION: no error injection
      wdata_w <= data_i;
    end generate;

    -- error is one if any value is different
    error_w <= or_reduce((reg0_r xor reg1_r) or (reg0_r xor reg2_r) or (reg1_r xor reg2_r));
    -- output with error
    data_err_o <= (reg0_r xor reg1_r) or (reg0_r xor reg2_r) or (reg1_r xor reg2_r);
    -- voting result is the corrected_data
    corrected_data_w <= (reg0_r and reg1_r) or (reg0_r and reg2_r) or (reg1_r and reg2_r);
    error_o <= error_w and valid_i;
    data_o <= corrected_data_w when correct_en_i = '1' else reg0_r;
  end generate;
  
end architecture;
