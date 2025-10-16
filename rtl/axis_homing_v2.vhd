--------------------------------------------------------------------------------
-- File: axis_homing_v2.vhd
-- Description: Advanced axis homing with Bresenham integration
--              Sequence: HOMING → RELEASE → OFFSET (200 steps) → ZERO
--              Uses bresenham_axis for accurate step generation
--
-- Procedure:
--   1. Move towards limit_min until hit (limit='0')
--   2. Move forward until switch released (limit='1')
--   3. Move additional 200 steps forward
--   4. Set current position = 0
--   5. Signal axis_homed='1' to enable next axis
--
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-16
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_homing_v2 is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- 50 MHz
        OFFSET_STEPS    : integer := 200;         -- Steps from limit switch to zero
        AXIS_NAME       : string  := "Z"          -- For debug
    );
    port (
        -- System
        clk             : in  std_logic;
        rst             : in  std_logic;          -- Active high

        -- Control
        enable_homing   : in  std_logic;          -- From previous axis (or reset release)

        -- Limit switch input
        limit_min       : in  std_logic;          -- Active low: 0=hit, 1=not hit

        -- Encoder feedback (for closed-loop with Bresenham)
        enc_a           : in  std_logic;
        enc_b           : in  std_logic;

        -- Motor control outputs
        step_out        : out std_logic;
        dir_out         : out std_logic;
        enable_out      : out std_logic;

        -- Position feedback
        current_pos     : out signed(31 downto 0);  -- Current position (0 after homing)

        -- Status
        axis_homed      : out std_logic;          -- High when homing complete
        homing_active   : out std_logic;          -- High during homing sequence

        -- Debug
        current_state   : out std_logic_vector(2 downto 0)  -- For monitoring
    );
end axis_homing_v2;

architecture rtl of axis_homing_v2 is

    -- State machine
    type state_type is (
        IDLE,           -- Waiting for enable_homing='1'
        HOMING,         -- Moving towards limit_min (negative direction)
        DEBOUNCE_HIT,   -- Debounce after limit hit
        RELEASE,        -- Moving forward until switch released
        OFFSET,         -- Moving additional 200 steps forward
        SET_ZERO,       -- Reset position counter to 0
        COMPLETE        -- Homing complete, axis_homed='1'
    );

    signal state : state_type := IDLE;

    -- Bresenham control signals
    signal target_position  : signed(31 downto 0) := (others => '0');
    signal step_period      : unsigned(15 downto 0) := to_unsigned(5000, 16);  -- 100us/step
    signal move_start       : std_logic := '0';
    signal move_abort       : std_logic := '0';
    signal busy             : std_logic;

    -- Position tracking
    signal position         : signed(31 downto 0) := (others => '0');
    signal encoder_position : signed(31 downto 0);

    -- Step counter for RELEASE and OFFSET phases
    signal step_count       : integer range 0 to OFFSET_STEPS := 0;

    -- Debounce counter
    constant DEBOUNCE_CYCLES : integer := 1000;  -- ~20us @ 50MHz
    signal debounce_counter  : integer range 0 to DEBOUNCE_CYCLES := 0;

    -- Internal motor signals (from Bresenham)
    signal step_int         : std_logic;
    signal dir_int          : std_logic;
    signal enable_int       : std_logic;

    -- State encoding for debug
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
    -- Bresenham Axis Instance (single axis movement)
    -------------------------------------------------------------------------
    u_bresenham : entity work.bresenham_axis
        port map (
            clk          => clk,
            rst          => rst,

            -- Control
            move_start   => move_start,
            move_abort   => move_abort,

            -- Target (relative movement)
            target       => target_position,
            step_period  => step_period,

            -- Encoder feedback
            enc_a        => enc_a,
            enc_b        => enc_b,

            -- Motor outputs
            step_out     => step_int,
            dir_out      => dir_int,
            enable_out   => enable_int,

            -- Status
            busy         => busy,
            position     => encoder_position,

            -- Unused
            error        => open,
            fault        => open
        );

    -------------------------------------------------------------------------
    -- Main State Machine
    -------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state            <= IDLE;
            position         <= (others => '0');
            target_position  <= (others => '0');
            move_start       <= '0';
            move_abort       <= '0';
            step_count       <= 0;
            debounce_counter <= 0;

        elsif rising_edge(clk) then

            -- Default: clear one-cycle pulses
            move_start <= '0';

            case state is

                when IDLE =>
                    -- Wait for enable_homing='1' from previous axis
                    position    <= (others => '0');
                    step_count  <= 0;
                    move_abort  <= '0';

                    if enable_homing = '1' then
                        state <= HOMING;
                    end if;

                when HOMING =>
                    -- Move towards limit_min (very large negative target)
                    -- Bresenham will stop when we abort or when limit hit

                    if busy = '0' then
                        -- Start movement towards negative (large negative target)
                        target_position <= to_signed(-100000, 32);  -- Large negative
                        move_start      <= '1';
                    end if;

                    -- Check if limit switch hit (active low: 0=hit)
                    if limit_min = '0' then
                        -- Limit hit! Abort movement and debounce
                        move_abort       <= '1';
                        debounce_counter <= 0;
                        state            <= DEBOUNCE_HIT;
                    end if;

                when DEBOUNCE_HIT =>
                    -- Debounce limit switch after hit
                    move_abort <= '0';  -- Release abort

                    if debounce_counter < DEBOUNCE_CYCLES - 1 then
                        debounce_counter <= debounce_counter + 1;
                    else
                        debounce_counter <= 0;
                        step_count       <= 0;
                        state            <= RELEASE;
                    end if;

                when RELEASE =>
                    -- Move forward until switch released (limit='1')
                    -- Use small positive movements

                    if limit_min = '1' then
                        -- Switch released! Move to OFFSET phase
                        state <= OFFSET;
                    else
                        -- Continue moving forward slowly
                        if busy = '0' then
                            target_position <= to_signed(10, 32);  -- Small forward movement
                            move_start      <= '1';
                        end if;
                    end if;

                when OFFSET =>
                    -- Move additional 200 steps forward from switch release point

                    if step_count < OFFSET_STEPS then
                        if busy = '0' then
                            -- Move 1 step at a time for precise count
                            target_position <= to_signed(1, 32);
                            move_start      <= '1';
                            step_count      <= step_count + 1;
                        end if;
                    else
                        -- 200 steps complete, proceed to set zero
                        state <= SET_ZERO;
                    end if;

                when SET_ZERO =>
                    -- Set current position to 0 (this is our home position)
                    position  <= (others => '0');
                    state     <= COMPLETE;

                when COMPLETE =>
                    -- Homing complete, axis_homed='1' enables next axis
                    -- Stay here until next reset
                    null;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

    -------------------------------------------------------------------------
    -- Position Update from Encoder
    -------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rising_edge(clk) then
            if state = SET_ZERO then
                -- Reset position to 0
                position <= (others => '0');
            elsif state = COMPLETE then
                -- Track position from encoder after homing
                position <= encoder_position;
            end if;
        end if;
    end process;

end rtl;
