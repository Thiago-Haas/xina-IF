library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Ultra-simple self-test controller:
--   * After reset, triggers TG then TM.
--   * When both are done, increments addr/seed and repeats FOREVER.
--   * Latches o_error if TM reports mismatch (but keeps running).

entity tg_tm_lb_selftest_ctrl is
  port (
    ACLK    : in  std_logic;
    ARESETn : in  std_logic;

    -- TG control
    o_tg_start : out std_logic;
    i_tg_done  : in  std_logic;
    o_tg_addr  : out std_logic_vector(63 downto 0);
    o_tg_seed  : out std_logic_vector(31 downto 0);

    -- TM control
    o_tm_start : out std_logic;
    i_tm_done  : in  std_logic;
    o_tm_addr  : out std_logic_vector(63 downto 0);
    o_tm_seed  : out std_logic_vector(31 downto 0);

    -- TM result
    i_tm_mismatch : in  std_logic;
    o_error       : out std_logic
  );
end entity;

architecture rtl of tg_tm_lb_selftest_ctrl is

  -- Edit these three constants if you want different stepping
  constant c_ADDR_STEP : unsigned(63 downto 0) := to_unsigned(16, 64); -- 0x10
  constant c_ADDR_INIT : unsigned(63 downto 0) := to_unsigned(16#100#, 64);
  constant c_SEED_INIT : unsigned(31 downto 0) := to_unsigned(16#1ACEB00C#, 32);

  signal r_addr   : unsigned(63 downto 0) := c_ADDR_INIT;
  signal r_seed   : unsigned(31 downto 0) := c_SEED_INIT;

  type t_state is (S_TG_PULSE, S_WAIT_TG, S_TM_PULSE, S_WAIT_TM);
  signal r_state : t_state := S_TG_PULSE;

  signal r_tg_start : std_logic := '0';
  signal r_tm_start : std_logic := '0';
  signal r_error    : std_logic := '0';

begin

  -- Current vectors (TG and TM use the same addr/seed each iteration)
  o_tg_addr <= std_logic_vector(r_addr);
  o_tm_addr <= std_logic_vector(r_addr);
  o_tg_seed <= std_logic_vector(r_seed);
  o_tm_seed <= std_logic_vector(r_seed);

  o_tg_start <= r_tg_start;
  o_tm_start <= r_tm_start;
  o_error    <= r_error;

  process(ACLK)
  begin
    if rising_edge(ACLK) then
      if ARESETn = '0' then
        r_state    <= S_TG_PULSE;
        r_tg_start <= '0';
        r_tm_start <= '0';
        r_error    <= '0';
        r_addr     <= c_ADDR_INIT;
        r_seed     <= c_SEED_INIT;
      else
        -- one-cycle pulse defaults
        r_tg_start <= '0';
        r_tm_start <= '0';

        case r_state is
          when S_TG_PULSE =>
            r_tg_start <= '1';
            r_state    <= S_WAIT_TG;

          when S_WAIT_TG =>
            if i_tg_done = '1' then
              r_state <= S_TM_PULSE;
            end if;

          when S_TM_PULSE =>
            r_tm_start <= '1';
            r_state    <= S_WAIT_TM;

          when S_WAIT_TM =>
            if i_tm_done = '1' then
              -- latch error, but keep running forever
              if i_tm_mismatch = '1' then
                r_error <= '1';
              end if;

              -- next iteration
              r_addr  <= r_addr + c_ADDR_STEP;
              r_seed  <= r_seed + 1;
              r_state <= S_TG_PULSE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
