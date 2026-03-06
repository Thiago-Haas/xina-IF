library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.hamming_pkg.hamming_encoder;
use work.hamming_pkg.hamming_decoder;
use work.hamming_pkg.get_parity_data_result;
use work.hamming_pkg.get_ecc_size;

entity hamming_register is
  generic (
    DATA_WIDTH     : integer;
    HAMMING_ENABLE : boolean;
    DETECT_DOUBLE  : boolean;
    RESET_VALUE    : std_logic_vector;
    INJECT_ERROR   : boolean
  );
  port (
    correct_en_i : in std_logic;
    write_en_i   : in std_logic;
    data_i       : in std_logic_vector(DATA_WIDTH-1 downto 0);
    rstn_i       : in std_logic;
    clk_i        : in std_logic;
    single_err_o : out std_logic;
    double_err_o : out std_logic;
    enc_data_o   : out std_logic_vector(DATA_WIDTH+get_ecc_size(DATA_WIDTH, DETECT_DOUBLE)-1 downto 0);
    data_o       : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end entity;

architecture arch of hamming_register is
begin

  -----------------------------------------------------------------------------------------------
  ------------------------------------- HAMMING DISABLED ----------------------------------------
  -----------------------------------------------------------------------------------------------

  g_NORMAL_REG : if not HAMMING_ENABLE generate
    signal reg_r : std_logic_vector(DATA_WIDTH-1 downto 0) := RESET_VALUE;
    -- Synplify flags
    attribute syn_preserve : boolean;
    attribute syn_preserve of reg_r : signal is true;
  begin
    p_REG : process(clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        reg_r <= RESET_VALUE;
      elsif rising_edge(clk_i) then
        if write_en_i = '1' then
          reg_r <= data_i;
        end if;
      end if;
    end process;
    single_err_o <= '0';
    double_err_o <= '0';
    data_o       <= reg_r;
    enc_data_o   <= (DATA_WIDTH+get_ecc_size(DATA_WIDTH, DETECT_DOUBLE)-1 downto DATA_WIDTH => '0') & reg_r;
  end generate;

  -----------------------------------------------------------------------------------------------
  -------------------------------------- HAMMING ENABLED ----------------------------------------
  -----------------------------------------------------------------------------------------------
  g_HAMMING_REG : if HAMMING_ENABLE generate
    constant REG_DATA_WIDTH : integer := DATA_WIDTH + get_ecc_size(DATA_WIDTH, DETECT_DOUBLE);
    constant RESET_VALUE_HAMMING : std_logic_vector(REG_DATA_WIDTH-1 downto 0) := get_parity_data_result(RESET_VALUE, DETECT_DOUBLE) & RESET_VALUE;
    signal enc_w : std_logic_vector(REG_DATA_WIDTH-1 downto 0);
    signal reg_r : std_logic_vector(REG_DATA_WIDTH-1 downto 0) := RESET_VALUE_HAMMING;
    -- Synplify flags
    attribute syn_preserve : boolean;
    attribute syn_preserve of reg_r : signal is true;
    signal wdata_w : std_logic_vector(REG_DATA_WIDTH-1 downto 0);
  begin

    -- encode next register data
    hamming_encoder_u : hamming_encoder
    generic map (
      DATA_SIZE     => DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map (
      data_i    => data_i,
      encoded_o => enc_w
    );

    inject_error_g : if INJECT_ERROR generate
      signal inj_counter_r : std_logic_vector(9 downto 0);
    begin
      -- Inject errors based on counter
      inj_counter_p : process (rstn_i, clk_i)
      begin
        if rstn_i = '0' then
          inj_counter_r <= (others => '0');
        elsif rising_edge(clk_i) then
          if write_en_i = '1' then
            if inj_counter_r(inj_counter_r'length-1) = '0' then -- injects only once
              inj_counter_r <= std_logic_vector(unsigned(inj_counter_r) + 1);
            end if;
          end if;
        end if;
      end process;
      wdata_w <= enc_w xor ("000" & x"000008000") when inj_counter_r = ("00" & (inj_counter_r'length-3 downto 0 => '1')) else -- inject one bit error
                 enc_w xor ("110" & x"000000000") when inj_counter_r = ("01" & (inj_counter_r'length-3 downto 0 => '1')) else -- inject two bit errors in parity data
                 enc_w;
    else generate
      wdata_w <= enc_w;
    end generate;

    -- create register
    p_REG : process(clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        reg_r <= RESET_VALUE_HAMMING;
      elsif rising_edge(clk_i) then
        if write_en_i = '1' then
          reg_r <= wdata_w;
        end if;
      end if;
    end process;
    enc_data_o <= reg_r;

    -- decode the data
    hamming_decoder_u : hamming_decoder
    generic map (
      DATA_SIZE     => DATA_WIDTH,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map (
      encoded_i       => reg_r,
      correct_error_i => correct_en_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      data_o          => data_o
    );
  end generate;

end architecture;
