--------------------------------------------------------------------------------
-- File: rom_controller.vhd
-- Description: Automatic sequencer for trajectory ROM playback
--              Auto-advances through 64 positions, triggers movements
--              Modes: LOOP (infinite) or ONE_SHOT (run once)
--
-- Usage: Connects trajectory_rom to cnc_3axis_controller
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-12
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rom_controller is
    generic (
        LOOP_MODE : boolean := true  -- true = infinite loop, false = run once
    );
    port (
        -- System
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- Control
        enable          : in  std_logic;  -- Enable playback
        pause           : in  std_logic;  -- Pause playback (optional)

        -- ROM interface
        rom_address     : out unsigned(5 downto 0);  -- 0 to 63
        rom_target_x    : in  signed(31 downto 0);
        rom_target_y    : in  signed(31 downto 0);
        rom_target_z    : in  signed(31 downto 0);

        -- CNC Controller interface
        target_x        : out signed(31 downto 0);
        target_y        : out signed(31 downto 0);
        target_z        : out signed(31 downto 0);
        step_period_out : out unsigned(15 downto 0);
        move_start      : out std_logic;
        busy            : in  std_logic;

        -- Status
        sequence_active : out std_logic;  -- High when running
        sequence_done   : out std_logic;  -- Pulse when complete (ONE_SHOT mode)
        current_step    : out unsigned(5 downto 0)  -- Debug: current position index
    );
end rom_controller;

architecture rtl of rom_controller is

    -- State machine
    type state_type is (
        IDLE,           -- Waiting for enable
        LOAD_POSITION,  -- Read position from ROM (1 cycle latency)
        WAIT_READY,     -- Wait for CNC controller ready (busy='0')
        START_MOVE,     -- Trigger move_start pulse
        WAIT_DONE,      -- Wait for movement completion
        ADVANCE,        -- Increment to next position
        COMPLETE        -- Sequence complete (ONE_SHOT mode)
    );

    signal state      : state_type := IDLE;
    signal next_state : state_type;

    -- Position counter
    signal position_counter : unsigned(5 downto 0) := (others => '0');

    -- Target registers (loaded from ROM - absolute positions)
    signal target_x_reg : signed(31 downto 0) := (others => '0');
    signal target_y_reg : signed(31 downto 0) := (others => '0');
    signal target_z_reg : signed(31 downto 0) := (others => '0');

    -- Previous position (to calculate relative delta)
    signal prev_x : signed(31 downto 0) := (others => '0');
    signal prev_y : signed(31 downto 0) := (others => '0');
    signal prev_z : signed(31 downto 0) := (others => '0');

    -- Delta (relative movement for CNC controller) - REGISTERED
    signal delta_x : signed(31 downto 0) := (others => '0');
    signal delta_y : signed(31 downto 0) := (others => '0');
    signal delta_z : signed(31 downto 0) := (others => '0');

    -- Fixed step period (10000 steps/sec @ 50MHz)
    -- step_period = 50_000_000 / 10_000 = 5000 cycles
    constant STEP_PERIOD : unsigned(15 downto 0) := to_unsigned(5000, 16);

    -- Move start pulse generation
    signal move_start_pulse : std_logic := '0';

    -- Done flag
    signal done_flag : std_logic := '0';

begin

    -- Output assignments
    rom_address     <= position_counter;
    target_x        <= delta_x;  -- Output relative delta, not absolute
    target_y        <= delta_y;
    target_z        <= delta_z;
    step_period_out <= STEP_PERIOD;
    move_start      <= move_start_pulse;
    current_step    <= position_counter;
    sequence_active <= '1' when (state /= IDLE and state /= COMPLETE) else '0';
    sequence_done   <= done_flag;

    -- State machine: sequential logic
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            position_counter <= (others => '0');
            target_x_reg <= (others => '0');
            target_y_reg <= (others => '0');
            target_z_reg <= (others => '0');
            prev_x <= (others => '0');
            prev_y <= (others => '0');
            prev_z <= (others => '0');
            move_start_pulse <= '0';
            done_flag <= '0';

        elsif rising_edge(clk) then
            -- Default: clear one-cycle pulses
            move_start_pulse <= '0';
            done_flag <= '0';

            case state is

                when IDLE =>
                    position_counter <= (others => '0');
                    if enable = '1' and pause = '0' then
                        state <= LOAD_POSITION;
                    end if;

                when LOAD_POSITION =>
                    -- ROM has 1-cycle latency, wait for data
                    state <= WAIT_READY;

                when WAIT_READY =>
                    -- Capture ROM data
                    target_x_reg <= rom_target_x;
                    target_y_reg <= rom_target_y;
                    target_z_reg <= rom_target_z;

                    -- Calculate delta (relative movement) - REGISTERED FOR STABILITY
                    delta_x <= rom_target_x - prev_x;
                    delta_y <= rom_target_y - prev_y;
                    delta_z <= rom_target_z - prev_z;

                    -- Check if CNC controller is ready
                    if busy = '0' then
                        state <= START_MOVE;
                    end if;
                    -- else stay in WAIT_READY

                when START_MOVE =>
                    -- Issue move_start pulse (1 cycle)
                    move_start_pulse <= '1';
                    state <= WAIT_DONE;

                when WAIT_DONE =>
                    -- Wait for movement completion
                    if busy = '0' then
                        -- Update previous position (for next delta calculation)
                        prev_x <= target_x_reg;
                        prev_y <= target_y_reg;
                        prev_z <= target_z_reg;
                        state <= ADVANCE;
                    end if;

                when ADVANCE =>
                    -- Check if sequence complete
                    if position_counter = 63 then
                        if LOOP_MODE then
                            -- Loop back to start
                            position_counter <= (others => '0');
                            state <= LOAD_POSITION;
                        else
                            -- ONE_SHOT mode: finish
                            done_flag <= '1';
                            state <= COMPLETE;
                        end if;
                    else
                        -- Increment to next position
                        position_counter <= position_counter + 1;
                        state <= LOAD_POSITION;
                    end if;

                when COMPLETE =>
                    -- Stay here until reset or enable='0'
                    if enable = '0' then
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;

            end case;

            -- Pause logic (can pause in any state except START_MOVE)
            if pause = '1' and state /= START_MOVE then
                -- Hold current state
                null;  -- State doesn't advance
            end if;

            -- Disable logic (override)
            if enable = '0' and state /= IDLE then
                state <= IDLE;
            end if;

        end if;
    end process;

end rtl;
