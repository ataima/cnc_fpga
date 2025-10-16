--------------------------------------------------------------------------------
-- File: reset_z.vhd
-- Description: Automatic Z-axis homing sequence
--              After reset, waits 1ms then moves Z towards negative limit
--              until limit_min_z is hit. Sets pos_z_zero='1' when complete.
--
-- Usage: Provides automatic zero-finding for Z axis at power-on
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-16
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_z is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- 50 MHz
        WAIT_TIME_MS    : integer := 1;           -- Wait 1ms after reset
        STEP_PERIOD_CYC : integer := 5000         -- 100 us/step (same as system)
    );
    port (
        -- System
        clk             : in  std_logic;
        rst             : in  std_logic;          -- Active high

        -- Limit switch input
        limit_min_z     : in  std_logic;          -- Active low: 0=hit, 1=not hit

        -- Motor control outputs (to Z axis)
        step_z          : out std_logic;
        dir_z           : out std_logic;          -- 0=negative (towards home)
        enable_z        : out std_logic;          -- Motor enable

        -- Status outputs
        pos_z_zero      : out std_logic;          -- High when homing complete
        homing_active   : out std_logic           -- High during homing sequence
    );
end reset_z;

architecture rtl of reset_z is

    -- State machine
    type state_type is (
        IDLE,           -- Waiting for reset
        WAIT_1MS,       -- Wait 1ms after reset release
        HOMING,         -- Moving towards limit_min_z
        LIMIT_HIT,      -- Limit switch hit, stop movement
        COMPLETE        -- Homing complete, pos_z_zero='1'
    );

    signal state : state_type := IDLE;

    -- Timing constants
    constant WAIT_CYCLES : integer := (CLK_FREQ_HZ / 1000) * WAIT_TIME_MS;  -- 50,000 cycles for 1ms @ 50MHz

    -- Counters
    signal wait_counter : integer range 0 to WAIT_CYCLES := 0;
    signal step_counter : integer range 0 to STEP_PERIOD_CYC := 0;

    -- Step pulse generation
    signal step_pulse   : std_logic := '0';
    signal step_phase   : std_logic := '0';  -- 0=low, 1=high

begin

    -- Output assignments
    step_z        <= step_pulse;
    dir_z         <= '0';  -- Always negative direction (towards home)
    enable_z      <= '1' when (state = HOMING or state = LIMIT_HIT) else '0';
    pos_z_zero    <= '1' when state = COMPLETE else '0';
    homing_active <= '1' when (state = WAIT_1MS or state = HOMING or state = LIMIT_HIT) else '0';

    -- Main state machine
    process(clk, rst)
    begin
        if rst = '1' then
            -- Reset active: go to IDLE
            state        <= IDLE;
            wait_counter <= 0;
            step_counter <= 0;
            step_pulse   <= '0';
            step_phase   <= '0';

        elsif rising_edge(clk) then

            -- Default: clear step pulse
            step_pulse <= '0';

            case state is

                when IDLE =>
                    -- Transition to WAIT_1MS immediately (reset released)
                    wait_counter <= 0;
                    step_counter <= 0;
                    step_phase   <= '0';
                    state <= WAIT_1MS;

                when WAIT_1MS =>
                    -- Wait 1ms before starting homing
                    if wait_counter < WAIT_CYCLES - 1 then
                        wait_counter <= wait_counter + 1;
                    else
                        -- 1ms elapsed, start homing
                        wait_counter <= 0;
                        state <= HOMING;
                    end if;

                when HOMING =>
                    -- Check if limit switch hit (active low: 0=hit)
                    if limit_min_z = '0' then
                        -- Limit hit! Stop and transition
                        step_counter <= 0;
                        step_phase   <= '0';
                        state <= LIMIT_HIT;
                    else
                        -- Continue generating step pulses
                        if step_counter < STEP_PERIOD_CYC - 1 then
                            step_counter <= step_counter + 1;
                        else
                            -- Period complete, toggle step phase
                            step_counter <= 0;
                            step_phase <= not step_phase;

                            -- Generate step pulse on rising edge of phase
                            if step_phase = '0' then
                                step_pulse <= '1';  -- Rising edge
                            end if;
                        end if;
                    end if;

                when LIMIT_HIT =>
                    -- Limit hit detected, wait a few cycles for debounce
                    if wait_counter < 1000 then  -- ~20us debounce @ 50MHz
                        wait_counter <= wait_counter + 1;
                    else
                        -- Debounce complete, declare homing complete
                        wait_counter <= 0;
                        state <= COMPLETE;
                    end if;

                when COMPLETE =>
                    -- Homing complete, stay here
                    -- pos_z_zero='1' enables rest of system
                    -- Stay until next reset
                    null;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

end rtl;
