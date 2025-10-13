--------------------------------------------------------------------------------
-- File: tb_3axis_test.vhd
-- Description: Test 3-axis diagonal movement (position 1: 50,50,50)
--              Verifies Bresenham interpolation works on all 3 axes together
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_3axis_test is
end tb_3axis_test;

architecture behavioral of tb_3axis_test is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal enable      : std_logic := '0';
    signal pause       : std_logic := '0';
    signal open_loop   : std_logic := '0';

    signal enc_a_x, enc_b_x, enc_a_y, enc_b_y, enc_a_z, enc_b_z : std_logic := '0';
    -- Limit switches are active-low: '1' = not hit, '0' = hit
    signal limit_min_x, limit_max_x, limit_min_y, limit_max_y, limit_min_z, limit_max_z : std_logic := '1';

    signal step_x, dir_x, enable_x : std_logic;
    signal step_y, dir_y, enable_y : std_logic;
    signal step_z, dir_z, enable_z : std_logic;

    signal busy            : std_logic;
    signal fault           : std_logic;
    signal state_debug     : std_logic_vector(3 downto 0);
    signal sequence_active : std_logic;
    signal sequence_done   : std_logic;
    signal current_step    : std_logic_vector(5 downto 0);

    signal test_complete : boolean := false;

    -- Step counters for all 3 axes
    signal step_x_count : integer := 0;
    signal step_y_count : integer := 0;
    signal step_z_count : integer := 0;

begin

    clk <= not clk after CLK_PERIOD / 2 when not test_complete else '0';

    dut : entity work.cnc_3axis_rom_top
        generic map (
            LOOP_MODE   => false
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

    stimulus : process
        variable l : line;
    begin
        write(l, string'("=== 3-AXIS DIAGONAL MOVEMENT TEST ==="));
        writeline(output, l);
        write(l, string'("Position 1: (50, 50, 50) - diagonal move"));
        writeline(output, l);
        write(l, string'("Expected: All 3 axes move together (Bresenham)"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        enable <= '1';
        write(l, string'("[INFO] Enable set, waiting for movement..."));
        writeline(output, l);

        -- Wait for position 1 to be loaded
        wait until to_integer(unsigned(current_step)) = 1 for 10 us;

        write(l, string'("[POS 1] Position loaded at "));
        write(l, now);
        writeline(output, l);

        -- Wait for busy
        wait until busy = '1' for 10 us;
        write(l, string'("[BUSY] Movement started at "));
        write(l, now);
        writeline(output, l);

        -- Wait for Position 1 to start (after Position 0 completes with delta=0)
        wait for 2 us;

        -- Wait for Position 1 movement (50 steps @ 100us = 5ms)
        wait until busy = '1' for 10 us;

        if busy = '1' then
            write(l, string'("[POS 1] Movement in progress..."));
            writeline(output, l);

            -- Wait for completion
            wait until busy = '0' for 10 ms;
        end if;

        if busy = '0' then
            write(l, string'("[DONE] Movement complete at "));
            write(l, now);
            writeline(output, l);
        else
            write(l, string'("[ERROR] Timeout waiting for completion!"));
            writeline(output, l);
        end if;

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("=== RESULTS ==="));
        writeline(output, l);
        write(l, string'("X steps: "));
        write(l, step_x_count);
        write(l, string'(" (expected: 50)"));
        writeline(output, l);
        write(l, string'("Y steps: "));
        write(l, step_y_count);
        write(l, string'(" (expected: 50)"));
        writeline(output, l);
        write(l, string'("Z steps: "));
        write(l, step_z_count);
        write(l, string'(" (expected: 50)"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        if step_x_count = 50 and step_y_count = 50 and step_z_count = 50 then
            write(l, string'("*** TEST PASS *** All 3 axes moved correctly!"));
        else
            write(l, string'("*** TEST FAIL *** Step counts incorrect!"));
        end if;
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -- Step counters for all 3 axes
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
                -- Count rising edges
                if step_x = '1' and step_x_prev = '0' then
                    step_x_count <= step_x_count + 1;
                end if;
                if step_y = '1' and step_y_prev = '0' then
                    step_y_count <= step_y_count + 1;
                end if;
                if step_z = '1' and step_z_prev = '0' then
                    step_z_count <= step_z_count + 1;
                end if;

                step_x_prev := step_x;
                step_y_prev := step_y;
                step_z_prev := step_z;
            end if;
        end if;
    end process;

end behavioral;
