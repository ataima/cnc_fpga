--------------------------------------------------------------------------------
-- File: tb_rom_full.vhd
-- Description: Complete testbench for visualizing all 64 ROM positions
--              Shows X/Y/Z coordinates and step counts for each position
--              Includes detailed position tracking and visualization
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rom_full is
end tb_rom_full;

architecture behavioral of tb_rom_full is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    -- DUT signals
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal enable      : std_logic := '0';
    signal pause       : std_logic := '0';
    signal open_loop   : std_logic := '0';  -- 0=simulated encoders

    -- Encoder/limit inputs (tied inactive)
    signal enc_a_x, enc_b_x, enc_a_y, enc_b_y, enc_a_z, enc_b_z : std_logic := '0';
    signal limit_min_x, limit_max_x, limit_min_y, limit_max_y, limit_min_z, limit_max_z : std_logic := '1';  -- Active-low: '1'=not hit

    -- Motor outputs
    signal step_x, dir_x, enable_x : std_logic;
    signal step_y, dir_y, enable_y : std_logic;
    signal step_z, dir_z, enable_z : std_logic;

    -- Status
    signal busy            : std_logic;
    signal fault           : std_logic;
    signal state_debug     : std_logic_vector(3 downto 0);
    signal sequence_active : std_logic;
    signal sequence_done   : std_logic;
    signal current_step    : std_logic_vector(5 downto 0);

    signal test_complete : boolean := false;

    -- Step counters (for position tracking)
    signal step_x_count : integer := 0;
    signal step_y_count : integer := 0;
    signal step_z_count : integer := 0;

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
    -- DUT instantiation (ONE_SHOT mode to stop after 64 positions)
    -------------------------------------------------------------------------
    dut : entity work.cnc_3axis_rom_top
        generic map (
            LOOP_MODE   => false  -- ONE_SHOT: Run once and stop
        )
        port map (
            clk              => clk,
            rst              => rst,
            enable           => enable,
            pause            => pause,
            open_loop        => open_loop,

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
    -- Test stimulus - Monitor all 64 positions
    -------------------------------------------------------------------------
    stimulus : process
        variable l : line;
        variable prev_step : integer := -1;
        variable timeout_counter : integer;
    begin
        write(l, string'("================================================================================"));
        writeline(output, l);
        write(l, string'("  ROM FULL TRAJECTORY TEST - All 64 Positions"));
        writeline(output, l);
        write(l, string'("  Mode: ONE_SHOT (stops after sequence complete)"));
        writeline(output, l);
        write(l, string'("  Closed-loop: Simulated encoders (10us delay)"));
        writeline(output, l);
        write(l, string'("================================================================================"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Reset
        rst <= '1';
        enable <= '0';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        write(l, string'("[INFO] Reset complete, starting ROM playback..."));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        write(l, string'("Pos#  |   Target X  |   Target Y  |   Target Z  | Steps X | Steps Y | Steps Z | Time"));
        writeline(output, l);
        write(l, string'("------|-------------|-------------|-------------|---------|---------|---------|--------"));
        writeline(output, l);

        -- Enable ROM playback
        enable <= '1';

        -- Monitor all position changes until sequence_done
        for position in 0 to 63 loop
            -- Wait for current_step to change to this position
            timeout_counter := 0;
            while to_integer(unsigned(current_step)) /= position and timeout_counter < 100000 loop
                wait for 10 us;
                timeout_counter := timeout_counter + 1;
            end loop;

            if timeout_counter >= 100000 then
                write(l, string'("[ERROR] Timeout waiting for position "));
                write(l, position);
                writeline(output, l);
                exit;
            end if;

            -- Position loaded, print info
            write(l, string'(" "));
            if position < 10 then
                write(l, string'(" "));
            end if;
            write(l, position);
            write(l, string'("   | "));

            -- Wait a bit for ROM data to be read
            wait for 100 ns;

            -- Print placeholder (actual target values are internal)
            write(l, string'("  ROM["));
            write(l, position);
            write(l, string'("]  | "));
            write(l, string'("  ROM["));
            write(l, position);
            write(l, string'("]  | "));
            write(l, string'("  ROM["));
            write(l, position);
            write(l, string'("]  | "));

            -- Wait for movement to start
            wait until busy = '1' or sequence_done = '1' for 20 us;

            if sequence_done = '1' and position > 0 then
                write(l, string'("  DONE  |  DONE   |  DONE   | "));
                write(l, now);
                writeline(output, l);
                exit;
            end if;

            if busy = '0' then
                write(l, string'("   0    |    0    |    0    | "));
                write(l, now);
                write(l, string'(" (no move)"));
                writeline(output, l);
            else
                -- Movement in progress, wait for completion
                -- Max movement: 10000 steps @ 100us/step = 1 second
                wait until busy = '0' or sequence_done = '1' for 2 sec;

                if busy = '0' or sequence_done = '1' then
                    write(l, string'("  "));
                    write(l, step_x_count);
                    write(l, string'("  |  "));
                    write(l, step_y_count);
                    write(l, string'("  |  "));
                    write(l, step_z_count);
                    write(l, string'("  | "));
                    write(l, now);
                    writeline(output, l);
                else
                    write(l, string'(" TIMEOUT | TIMEOUT | TIMEOUT | "));
                    write(l, now);
                    writeline(output, l);
                    exit;
                end if;
            end if;
        end loop;

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("================================================================================"));
        writeline(output, l);

        if sequence_done = '1' then
            write(l, string'("  TEST COMPLETE: All 64 positions executed successfully!"));
            writeline(output, l);
            write(l, string'("  sequence_done = '1' detected"));
        else
            write(l, string'("  TEST INCOMPLETE: Stopped at position "));
            write(l, to_integer(unsigned(current_step)));
            writeline(output, l);
        end if;

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("  Final position: X="));
        write(l, step_x_count);
        write(l, string'(" steps, Y="));
        write(l, step_y_count);
        write(l, string'(" steps, Z="));
        write(l, step_z_count);
        write(l, string'(" steps"));
        writeline(output, l);
        write(l, string'("================================================================================"));
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -------------------------------------------------------------------------
    -- Step pulse counter (tracks accumulated position)
    -------------------------------------------------------------------------
    count_steps : process(clk)
        variable step_x_prev : std_logic := '0';
        variable step_y_prev : std_logic := '0';
        variable step_z_prev : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rst = '1' then
                step_x_count <= 0;
                step_y_count <= 0;
                step_z_count <= 0;
                step_x_prev := '0';
                step_y_prev := '0';
                step_z_prev := '0';
            else
                -- Count rising edges on step signals
                if step_x = '1' and step_x_prev = '0' then
                    if dir_x = '1' then
                        step_x_count <= step_x_count + 1;
                    else
                        step_x_count <= step_x_count - 1;
                    end if;
                end if;

                if step_y = '1' and step_y_prev = '0' then
                    if dir_y = '1' then
                        step_y_count <= step_y_count + 1;
                    else
                        step_y_count <= step_y_count - 1;
                    end if;
                end if;

                if step_z = '1' and step_z_prev = '0' then
                    if dir_z = '1' then
                        step_z_count <= step_z_count + 1;
                    else
                        step_z_count <= step_z_count - 1;
                    end if;
                end if;

                step_x_prev := step_x;
                step_y_prev := step_y;
                step_z_prev := step_z;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Position reporter (every 1000 steps)
    -------------------------------------------------------------------------
    report_progress : process(clk)
        variable last_report_x : integer := 0;
        variable last_report_y : integer := 0;
        variable last_report_z : integer := 0;
        variable l : line;
    begin
        if rising_edge(clk) then
            if (abs(step_x_count - last_report_x) >= 1000) or
               (abs(step_y_count - last_report_y) >= 1000) or
               (abs(step_z_count - last_report_z) >= 1000) then

                write(l, string'("    [PROGRESS] X="));
                write(l, step_x_count);
                write(l, string'(", Y="));
                write(l, step_y_count);
                write(l, string'(", Z="));
                write(l, step_z_count);
                write(l, string'(" @ "));
                write(l, now);
                writeline(output, l);

                last_report_x := step_x_count;
                last_report_y := step_y_count;
                last_report_z := step_z_count;
            end if;
        end if;
    end process;

end behavioral;
