--------------------------------------------------------------------------------
-- File: axis_homing.vhd
-- Description: Generic axis homing module (reusable for X, Y, Z)
--              Moves axis towards negative limit until switch is hit
--              Part of cascaded homing sequence: Z → Y → X → ROM
--
-- Usage: Instantiate 3 times with enable_homing in cascade
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-16
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_homing is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- 50 MHz
        STEP_PERIOD_CYC : integer := 5000;        -- 100 us/step
        AXIS_NAME       : string  := "Z"          -- For debug messages
    );
    port (
        -- System
        clk             : in  std_logic;
        rst             : in  std_logic;          -- Active high

        -- Control
        enable_homing   : in  std_logic;          -- From previous axis (or reset release)

        -- Limit switch input
        limit_min       : in  std_logic;          -- Active low: 0=hit, 1=not hit

        -- Motor control outputs
        step_out        : out std_logic;
        dir_out         : out std_logic;          -- 0=negative (towards home)
        enable_out      : out std_logic;          -- Motor enable

        -- Status
        axis_homed      : out std_logic;          -- High when homing complete (enables next axis)
        homing_active   : out std_logic           -- High during homing sequence
    );
end axis_homing;

architecture rtl of axis_homing is

    -- State machine
    type state_type is (
        IDLE,           -- Waiting for enable_homing='1'
        HOMING,         -- Moving towards limit_min
        DEBOUNCE,       -- Limit hit, debouncing
        COMPLETE        -- Homing complete, axis_homed='1'
    );

    signal state : state_type := IDLE;

    -- Counters
    constant DEBOUNCE_CYCLES : integer := 1000;  -- ~20us @ 50MHz
    signal debounce_counter  : integer range 0 to DEBOUNCE_CYCLES := 0;
    signal step_counter      : integer range 0 to STEP_PERIOD_CYC := 0;

    -- Step pulse generation
    signal step_pulse   : std_logic := '0';

begin

    -- Output assignments
    step_out      <= step_pulse;
    dir_out       <= '0';  -- Always negative direction (towards home)
    enable_out    <= '1' when (state = HOMING or state = DEBOUNCE) else '0';
    axis_homed    <= '1' when state = COMPLETE else '0';
    homing_active <= '1' when (state = HOMING or state = DEBOUNCE) else '0';

    -- Main state machine
    process(clk, rst)
    begin
        if rst = '1' then
            -- Reset active: go to IDLE
            state            <= IDLE;
            step_counter     <= 0;
            debounce_counter <= 0;
            step_pulse       <= '0';

        elsif rising_edge(clk) then

            -- Default: clear step pulse
            step_pulse <= '0';

            case state is

                when IDLE =>
                    -- Wait for enable_homing='1' from previous axis
                    step_counter     <= 0;
                    debounce_counter <= 0;

                    if enable_homing = '1' then
                        state <= HOMING;
                    end if;

                when HOMING =>
                    -- Check if limit switch hit (active low: 0=hit)
                    if limit_min = '0' then
                        -- Limit hit! Stop and debounce
                        step_counter     <= 0;
                        debounce_counter <= 0;
                        state <= DEBOUNCE;
                    else
                        -- Continue generating step pulses
                        if step_counter < STEP_PERIOD_CYC - 1 then
                            step_counter <= step_counter + 1;
                        else
                            -- Period complete, generate step pulse
                            step_counter <= 0;
                            step_pulse <= '1';
                        end if;
                    end if;

                when DEBOUNCE =>
                    -- Debounce limit switch
                    if debounce_counter < DEBOUNCE_CYCLES - 1 then
                        debounce_counter <= debounce_counter + 1;
                    else
                        -- Debounce complete, declare homing complete
                        debounce_counter <= 0;
                        state <= COMPLETE;
                    end if;

                when COMPLETE =>
                    -- Homing complete, axis_homed='1' enables next axis
                    -- Stay here until next reset
                    null;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

end rtl;
