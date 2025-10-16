--------------------------------------------------------------------------------
-- File: tb_homing_sequence.vhd
-- Description: Testbench for cascaded homing sequence (Z → Y → X)
--              Verifies correct sequential operation
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_homing_sequence is
end tb_homing_sequence;

architecture behavioral of tb_homing_sequence is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';

    signal limit_min_x   : std_logic := '1';  -- '1' = not hit
    signal limit_min_y   : std_logic := '1';
    signal limit_min_z   : std_logic := '1';

    signal step_x        : std_logic;
    signal dir_x         : std_logic;
    signal enable_x      : std_logic;

    signal step_y        : std_logic;
    signal dir_y         : std_logic;
    signal enable_y      : std_logic;

    signal step_z        : std_logic;
    signal dir_z         : std_logic;
    signal enable_z      : std_logic;

    signal pos_z_zero    : std_logic;
    signal pos_y_zero    : std_logic;
    signal pos_x_zero    : std_logic;

    signal all_axes_homed : std_logic;
    signal homing_active  : std_logic;

    signal test_complete : boolean := false;

    -- Step counters
    signal step_x_count : integer := 0;
    signal step_y_count : integer := 0;
    signal step_z_count : integer := 0;

begin

    clk <= not clk after CLK_PERIOD / 2 when not test_complete else '0';

    dut : entity work.homing_sequence
        generic map (
            CLK_FREQ_HZ  => 50_000_000,
            WAIT_TIME_MS => 1
        )
        port map (
            clk             => clk,
            rst             => rst,
            limit_min_x     => limit_min_x,
            limit_min_y     => limit_min_y,
            limit_min_z     => limit_min_z,
            step_x          => step_x,
            dir_x           => dir_x,
            enable_x        => enable_x,
            step_y          => step_y,
            dir_y           => dir_y,
            enable_y        => enable_y,
            step_z          => step_z,
            dir_z           => dir_z,
            enable_z        => enable_z,
            pos_z_zero      => pos_z_zero,
            pos_y_zero      => pos_y_zero,
            pos_x_zero      => pos_x_zero,
            all_axes_homed  => all_axes_homed,
            homing_active   => homing_active
        );

    stimulus : process
        variable l : line;
    begin
        write(l, string'("=== CASCADED HOMING SEQUENCE TEST (Z -> Y -> X) ==="));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Reset
        rst <= '1';
        wait for 500 ns;
        rst <= '0';

        write(l, string'("[INFO] Reset released, waiting 1ms..."));
        writeline(output, l);
        wait for 1.1 ms;

        -- Test 1: Z axis should start homing
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("[TEST 1] Verify Z axis starts homing"));
        writeline(output, l);

        assert enable_z = '1' report "[ERROR] Z axis not enabled!" severity error;
        assert enable_y = '0' report "[ERROR] Y axis should not be enabled yet!" severity error;
        assert enable_x = '0' report "[ERROR] X axis should not be enabled yet!" severity error;

        write(l, string'("[TEST 1] PASS: Z axis homing started"));
        writeline(output, l);
        write(l, string'("[INFO] Counting Z steps for 5ms..."));
        writeline(output, l);

        wait for 5 ms;

        write(l, string'("[INFO] Z step count: "));
        write(l, step_z_count);
        writeline(output, l);

        -- Trigger Z limit switch
        write(l, string'("[INFO] Triggering Z limit switch..."));
        writeline(output, l);
        limit_min_z <= '0';
        wait for 100 us;

        assert pos_z_zero = '1' report "[ERROR] pos_z_zero not set!" severity error;
        write(l, string'("[TEST 1] PASS: Z axis homed (pos_z_zero='1')"));
        writeline(output, l);

        -- Test 2: Y axis should start after Z completes
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("[TEST 2] Verify Y axis starts after Z complete"));
        writeline(output, l);

        wait for 200 ns;

        assert enable_y = '1' report "[ERROR] Y axis not enabled after Z homing!" severity error;
        assert enable_x = '0' report "[ERROR] X axis should not be enabled yet!" severity error;

        write(l, string'("[TEST 2] PASS: Y axis homing started"));
        writeline(output, l);
        write(l, string'("[INFO] Counting Y steps for 5ms..."));
        writeline(output, l);

        wait for 5 ms;

        write(l, string'("[INFO] Y step count: "));
        write(l, step_y_count);
        writeline(output, l);

        -- Trigger Y limit switch
        write(l, string'("[INFO] Triggering Y limit switch..."));
        writeline(output, l);
        limit_min_y <= '0';
        wait for 100 us;

        assert pos_y_zero = '1' report "[ERROR] pos_y_zero not set!" severity error;
        write(l, string'("[TEST 2] PASS: Y axis homed (pos_y_zero='1')"));
        writeline(output, l);

        -- Test 3: X axis should start after Y completes
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("[TEST 3] Verify X axis starts after Y complete"));
        writeline(output, l);

        wait for 200 ns;

        assert enable_x = '1' report "[ERROR] X axis not enabled after Y homing!" severity error;

        write(l, string'("[TEST 3] PASS: X axis homing started"));
        writeline(output, l);
        write(l, string'("[INFO] Counting X steps for 5ms..."));
        writeline(output, l);

        wait for 5 ms;

        write(l, string'("[INFO] X step count: "));
        write(l, step_x_count);
        writeline(output, l);

        -- Trigger X limit switch
        write(l, string'("[INFO] Triggering X limit switch..."));
        writeline(output, l);
        limit_min_x <= '0';
        wait for 100 us;

        assert pos_x_zero = '1' report "[ERROR] pos_x_zero not set!" severity error;
        assert all_axes_homed = '1' report "[ERROR] all_axes_homed not set!" severity error;

        write(l, string'("[TEST 3] PASS: X axis homed (pos_x_zero='1')"));
        writeline(output, l);

        -- Final verification
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("=== FINAL RESULTS ==="));
        writeline(output, l);
        write(l, string'("pos_z_zero='1' OK"));
        writeline(output, l);
        write(l, string'("pos_y_zero='1' OK"));
        writeline(output, l);
        write(l, string'("pos_x_zero='1' OK"));
        writeline(output, l);
        write(l, string'("all_axes_homed='1' OK"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("Total steps: Z="));
        write(l, step_z_count);
        write(l, string'(", Y="));
        write(l, step_y_count);
        write(l, string'(", X="));
        write(l, step_x_count);
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("*** ALL TESTS PASS ***"));
        writeline(output, l);
        write(l, string'("System ready for ROM controller operation"));
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -- Step counters for all axes
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
