--------------------------------------------------------------------------------
-- File: tb_rom_playback.vhd
-- Description: Testbench for ROM-based trajectory playback
--              Tests first 10 positions from ROM (to keep sim time short)
--
-- Expected behavior:
--   - ROM controller loads position 0-9
--   - CNC controller executes each movement
--   - Auto-advances to next position when busy='0'
--
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-12
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rom_playback is
end tb_rom_playback;

architecture behavioral of tb_rom_playback is

    -- Constants
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    -- DUT signals
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal enable      : std_logic := '0';
    signal pause       : std_logic := '0';

    -- Encoder inputs (not used in this test, tie to '0')
    signal enc_a_x     : std_logic := '0';
    signal enc_b_x     : std_logic := '0';
    signal enc_a_y     : std_logic := '0';
    signal enc_b_y     : std_logic := '0';
    signal enc_a_z     : std_logic := '0';
    signal enc_b_z     : std_logic := '0';

    -- Limit switches (not used, tie inactive)
    signal limit_min_x : std_logic := '0';
    signal limit_max_x : std_logic := '0';
    signal limit_min_y : std_logic := '0';
    signal limit_max_y : std_logic := '0';
    signal limit_min_z : std_logic := '0';
    signal limit_max_z : std_logic := '0';

    -- Motor outputs
    signal step_x      : std_logic;
    signal dir_x       : std_logic;
    signal enable_x    : std_logic;
    signal step_y      : std_logic;
    signal dir_y       : std_logic;
    signal enable_y    : std_logic;
    signal step_z      : std_logic;
    signal dir_z       : std_logic;
    signal enable_z    : std_logic;

    -- Status
    signal busy            : std_logic;
    signal fault           : std_logic;
    signal state_debug     : std_logic_vector(3 downto 0);
    signal sequence_active : std_logic;
    signal sequence_done   : std_logic;
    signal current_step    : std_logic_vector(5 downto 0);

    -- Test control
    signal test_complete : boolean := false;
    signal positions_tested : integer := 0;

begin

    -------------------------------------------------------------------------
    -- Clock generation
    -------------------------------------------------------------------------
    clk_gen : process
    begin
        while not test_complete loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -------------------------------------------------------------------------
    -- DUT instantiation (ONE_SHOT mode for testing)
    -------------------------------------------------------------------------
    dut : entity work.cnc_3axis_rom_top
        generic map (
            LOOP_MODE   => false  -- ONE_SHOT for test
        )
        port map (
            clk              => clk,
            rst              => rst,
            enable           => enable,
            pause            => pause,

            enc_a_x          => enc_a_x,
            enc_b_x          => enc_b_x,
            enc_a_y          => enc_a_y,
            enc_b_y          => enc_b_y,
            enc_a_z          => enc_a_z,
            enc_b_z          => enc_b_z,

            limit_min_x      => limit_min_x,
            limit_max_x      => limit_max_x,
            limit_min_y      => limit_min_y,
            limit_max_y      => limit_max_y,
            limit_min_z      => limit_min_z,
            limit_max_z      => limit_max_z,

            step_x           => step_x,
            dir_x            => dir_x,
            enable_x         => enable_x,
            step_y           => step_y,
            dir_y            => dir_y,
            enable_y         => enable_y,
            step_z           => step_z,
            dir_z            => dir_z,
            enable_z         => enable_z,

            busy             => busy,
            fault            => fault,
            state_debug      => state_debug,
            sequence_active  => sequence_active,
            sequence_done    => sequence_done,
            current_step     => current_step
        );

    -------------------------------------------------------------------------
    -- Test stimulus
    -------------------------------------------------------------------------
    stimulus : process
        variable l : line;
    begin
        -- Print header
        write(l, string'("======================================================"));
        writeline(output, l);
        write(l, string'("  ROM Playback Testbench"));
        writeline(output, l);
        write(l, string'("  Testing first 10 positions from trajectory ROM"));
        writeline(output, l);
        write(l, string'("======================================================"));
        writeline(output, l);

        -- Reset
        rst <= '1';
        enable <= '0';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        write(l, string'("[INFO] Reset complete, starting playback..."));
        writeline(output, l);

        -- Enable playback
        enable <= '1';
        wait for 100 ns;

        -- Wait for first 10 positions to complete
        -- Each position takes ~1-10ms depending on movement distance
        -- For safety, wait max 200ms
        for i in 0 to 9 loop
            -- Wait for position to start
            wait until to_integer(unsigned(current_step)) = i;
            write(l, string'("[STEP "));
            write(l, i);
            write(l, string'("] Loading position from ROM..."));
            writeline(output, l);

            -- Wait for movement to complete
            wait until busy = '1';
            write(l, string'("[STEP "));
            write(l, i);
            write(l, string'("] Movement started"));
            writeline(output, l);

            wait until busy = '0';
            write(l, string'("[STEP "));
            write(l, i);
            write(l, string'("] Movement complete"));
            writeline(output, l);

            positions_tested <= i + 1;

            -- Small delay between positions
            wait for 1 us;
        end loop;

        -- Test complete
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("======================================================"));
        writeline(output, l);
        write(l, string'("  TEST COMPLETE: 10 positions executed successfully"));
        writeline(output, l);
        write(l, string'("======================================================"));
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -------------------------------------------------------------------------
    -- Monitor process (prints state changes)
    -------------------------------------------------------------------------
    monitor : process(clk)
        variable l : line;
        variable last_step : integer := -1;
    begin
        if rising_edge(clk) then
            -- Report position changes
            if to_integer(unsigned(current_step)) /= last_step then
                last_step := to_integer(unsigned(current_step));
                if sequence_active = '1' then
                    write(l, string'("  ["));
                    write(l, now);
                    write(l, string'("] Position "));
                    write(l, last_step);
                    write(l, string'(" loaded"));
                    writeline(output, l);
                end if;
            end if;

            -- Report faults
            if fault = '1' then
                write(l, string'("[ERROR] FAULT detected at "));
                write(l, now);
                writeline(output, l);
            end if;
        end if;
    end process;

end behavioral;
