-- ============================================================================
-- STEP/DIR Signal Generator
-- ============================================================================
-- Genera segnali STEP e DIR compatibili con driver stepper (es. TB6600)
-- - Pulse stretching per STEP (min 2.5us per TB6600)
-- - Setup/Hold time per DIR rispetto a STEP
-- - Enable con pull-down
-- - Limit switch active-low ('0' = hit)
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity step_dir_generator is
    generic (
        CLK_FREQ_HZ   : integer := 50_000_000;  -- Frequenza clock
        STEP_WIDTH_US : integer := 5;           -- Larghezza pulse STEP (microsec)
        DIR_SETUP_US  : integer := 1;           -- Setup time DIR prima STEP
        DIR_HOLD_US   : integer := 1            -- Hold time DIR dopo STEP (opzionale)
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;

        -- Input da Bresenham core
        step_req      : in  std_logic;
        direction     : in  std_logic;  -- '1' = CW, '0' = CCW
        enable_in     : in  std_logic;

        -- Limit switch feedback (active-low: '0' = hit)
        limit_min     : in  std_logic;
        limit_max     : in  std_logic;

        -- Output fisici per driver
        step_out      : out std_logic;
        dir_out       : out std_logic;
        enable_out    : out std_logic;

        -- Status
        fault         : out std_logic   -- Limit hit durante movimento
    );
end step_dir_generator;

architecture rtl of step_dir_generator is

    -- Calcola cicli clock per timing (con ceil per safety)
    function calc_cycles (freq_hz, us : integer) return integer is
    begin
        return (freq_hz * us + 999999) / 1_000_000;
    end function;

    constant STEP_WIDTH_CYCLES : integer := calc_cycles(CLK_FREQ_HZ, STEP_WIDTH_US);
    constant DIR_SETUP_CYCLES  : integer := calc_cycles(CLK_FREQ_HZ, DIR_SETUP_US);
    constant DIR_HOLD_CYCLES   : integer := calc_cycles(CLK_FREQ_HZ, DIR_HOLD_US);

    type state_t is (IDLE, DIR_SETUP, STEP_PULSE, STEP_HOLD);
    signal state : state_t;

    signal step_counter : unsigned(31 downto 0);  -- Più largo per safety
    signal dir_internal : std_logic;
    signal step_internal : std_logic;
    signal fault_flag : std_logic;

begin

    -- ========================================================================
    -- Generatore pulse STEP con timing garantito
    -- ========================================================================
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            step_counter <= (others => '0');
            dir_internal <= '0';
            step_internal <= '0';
            fault_flag <= '0';

        elsif rising_edge(clk) then

            case state is

                when IDLE =>
                    step_internal <= '0';
                    if step_req = '0' then
                        fault_flag <= '0';  -- Clear fault se no req
                    end if;

                    if step_req = '1' and enable_in = '1' then
                        -- Check limit switch PRIMA di muoversi (active-low: '0'=hit)
                        if (direction = '1' and limit_max = '0') or  -- CW verso max, hit se '0'
                           (direction = '0' and limit_min = '0') then -- CCW verso min, hit se '0'
                            -- Limit hit: blocca movimento
                            fault_flag <= '1';
                        else
                            -- OK: inizia sequenza
                            fault_flag <= '0';
                            dir_internal <= direction;
                            state <= DIR_SETUP;
                            step_counter <= (others => '0');
                        end if;
                    end if;

                when DIR_SETUP =>
                    -- Attendi setup time per DIR
                    if step_counter < DIR_SETUP_CYCLES then
                        step_counter <= step_counter + 1;
                    else
                        state <= STEP_PULSE;
                        step_counter <= (others => '0');
                    end if;

                when STEP_PULSE =>
                    -- Pulse STEP alto
                    step_internal <= '1';

                    if step_counter < STEP_WIDTH_CYCLES then
                        step_counter <= step_counter + 1;
                    else
                        state <= STEP_HOLD;
                        step_counter <= (others => '0');
                    end if;

                when STEP_HOLD =>
                    -- Pulse STEP basso (hold time) + hold DIR
                    step_internal <= '0';

                    if step_counter < (STEP_WIDTH_CYCLES + DIR_HOLD_CYCLES) then  -- Hold DIR extra
                        step_counter <= step_counter + 1;
                    else
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- ========================================================================
    -- Output
    -- ========================================================================
    step_out <= step_internal;
    dir_out <= dir_internal;
    enable_out <= enable_in;
    fault <= fault_flag;

end rtl;
