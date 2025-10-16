--------------------------------------------------------------------------------
-- File: axis_homing_v3.vhd
-- Description: Complete axis homing with release and offset
--              Sequence: HOMING → RELEASE → OFFSET (200 steps) → ZERO → COMPLETE
--              Uses step_dir_generator for reliable step generation
--
-- Procedure per ogni asse:
--   1. HOMING:  Muove verso limit_min finché hit (limit='0')
--   2. RELEASE: Muove in avanti finché switch rilasciato (limit='1')
--   3. OFFSET:  Muove ulteriori 200 step in avanti
--   4. ZERO:    Imposta posizione corrente = 0
--   5. COMPLETE: axis_homed='1' → abilita asse successivo
--
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-16
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_homing_v3 is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- 50 MHz
        STEP_PERIOD_CYC : integer := 5000;        -- 100 us/step
        OFFSET_STEPS    : integer := 200;         -- Steps from limit to zero position
        AXIS_NAME       : string  := "Z"          -- For debug
    );
    port (
        -- System
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- Control
        enable_homing   : in  std_logic;          -- From previous axis

        -- Limit switch input
        limit_min       : in  std_logic;          -- Active low: 0=hit, 1=not hit

        -- Motor control outputs
        step_out        : out std_logic;
        dir_out         : out std_logic;
        enable_out      : out std_logic;

        -- Position feedback
        current_pos     : out signed(31 downto 0);  -- Current position (0 after homing)

        -- Status
        axis_homed      : out std_logic;          -- High when homing complete
        homing_active   : out std_logic;          -- High during homing

        -- Debug
        current_state   : out std_logic_vector(2 downto 0)
    );
end axis_homing_v3;

architecture rtl of axis_homing_v3 is

    -- State machine
    type state_type is (
        IDLE,           -- 000
        HOMING,         -- 001
        DEBOUNCE_HIT,   -- 010
        RELEASE,        -- 011
        OFFSET,         -- 100
        SET_ZERO,       -- 101
        COMPLETE        -- 110
    );

    signal state : state_type := IDLE;

    -- Step generation
    signal step_req         : std_logic := '0';
    signal direction        : std_logic := '0';
    signal enable_motor     : std_logic := '0';
    signal step_timer       : integer range 0 to STEP_PERIOD_CYC := 0;

    -- Position and counters
    signal position         : signed(31 downto 0) := (others => '0');
    signal step_count       : integer range 0 to OFFSET_STEPS + 10 := 0;

    -- Debounce
    constant DEBOUNCE_CYCLES : integer := 1000;  -- ~20us @ 50MHz
    signal debounce_counter  : integer range 0 to DEBOUNCE_CYCLES := 0;

    -- Internal motor signals
    signal step_int         : std_logic;
    signal dir_int          : std_logic;
    signal enable_int       : std_logic;
    signal fault            : std_logic;

    -- State encoding
    signal state_code       : std_logic_vector(2 downto 0);

begin

    -- Output assignments
    step_out      <= step_int;
    dir_out       <= dir_int;
    enable_out    <= enable_int;
    current_pos   <= position;
    axis_homed    <= '1' when state = COMPLETE else '0';
    homing_active <= '1' when (state /= IDLE and state /= COMPLETE) else '0';
    current_state <= state_code;

    -- State encoding for debug
    with state select state_code <=
        "000" when IDLE,
        "001" when HOMING,
        "010" when DEBOUNCE_HIT,
        "011" when RELEASE,
        "100" when OFFSET,
        "101" when SET_ZERO,
        "110" when COMPLETE,
        "111" when others;

    -------------------------------------------------------------------------
    -- Step/Dir Generator Instance
    -------------------------------------------------------------------------
    u_step_dir : entity work.step_dir_generator
        generic map (
            CLK_FREQ_HZ   => CLK_FREQ_HZ,
            STEP_WIDTH_US => 5,
            DIR_SETUP_US  => 1,
            DIR_HOLD_US   => 1
        )
        port map (
            clk        => clk,
            rst        => rst,
            step_req   => step_req,
            direction  => direction,
            enable_in  => enable_motor,
            limit_min  => limit_min,
            limit_max  => '1',  -- Not used for homing (always towards min)
            step_out   => step_int,
            dir_out    => dir_int,
            enable_out => enable_int,
            fault      => fault
        );

    -------------------------------------------------------------------------
    -- Main State Machine
    -------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state            <= IDLE;
            position         <= (others => '0');
            step_req         <= '0';
            direction        <= '0';
            enable_motor     <= '0';
            step_timer       <= 0;
            step_count       <= 0;
            debounce_counter <= 0;

        elsif rising_edge(clk) then

            -- Default: clear step_req (pulse)
            step_req <= '0';

            case state is

                when IDLE =>
                    position      <= (others => '0');
                    step_timer    <= 0;
                    step_count    <= 0;
                    enable_motor  <= '0';

                    if enable_homing = '1' then
                        state <= HOMING;
                    end if;

                when HOMING =>
                    -- Move towards limit_min (negative direction)
                    direction    <= '0';  -- Negative
                    enable_motor <= '1';

                    -- Check if limit switch hit
                    if limit_min = '0' then
                        -- Limit hit! Stop and debounce
                        enable_motor     <= '0';
                        step_timer       <= 0;
                        debounce_counter <= 0;
                        state            <= DEBOUNCE_HIT;
                    else
                        -- Generate step requests at fixed rate
                        if step_timer < STEP_PERIOD_CYC - 1 then
                            step_timer <= step_timer + 1;
                        else
                            step_timer <= 0;
                            step_req   <= '1';  -- Request step
                        end if;
                    end if;

                when DEBOUNCE_HIT =>
                    -- Debounce limit switch
                    if debounce_counter < DEBOUNCE_CYCLES - 1 then
                        debounce_counter <= debounce_counter + 1;
                    else
                        debounce_counter <= 0;
                        step_timer       <= 0;
                        state            <= RELEASE;
                    end if;

                when RELEASE =>
                    -- Move forward until switch released
                    direction    <= '1';  -- Positive (away from limit)
                    enable_motor <= '1';

                    if limit_min = '1' then
                        -- Switch released! Proceed to OFFSET
                        step_timer   <= 0;
                        step_count   <= 0;
                        state        <= OFFSET;
                    else
                        -- Continue moving forward
                        if step_timer < STEP_PERIOD_CYC - 1 then
                            step_timer <= step_timer + 1;
                        else
                            step_timer <= 0;
                            step_req   <= '1';
                        end if;
                    end if;

                when OFFSET =>
                    -- Move additional OFFSET_STEPS forward
                    direction    <= '1';  -- Positive
                    enable_motor <= '1';

                    if step_count < OFFSET_STEPS then
                        if step_timer < STEP_PERIOD_CYC - 1 then
                            step_timer <= step_timer + 1;
                        else
                            step_timer <= 0;
                            step_req   <= '1';
                            step_count <= step_count + 1;
                        end if;
                    else
                        -- OFFSET complete
                        enable_motor <= '0';
                        state        <= SET_ZERO;
                    end if;

                when SET_ZERO =>
                    -- Set position to 0 (this is home)
                    position <= (others => '0');
                    state    <= COMPLETE;

                when COMPLETE =>
                    -- Homing complete, axis_homed='1'
                    enable_motor <= '0';
                    -- Stay here until reset
                    null;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

end rtl;
