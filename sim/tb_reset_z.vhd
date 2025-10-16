--------------------------------------------------------------------------------
-- File: tb_reset_z.vhd
-- Description: Testbench for reset_z.vhd (Z-axis homing sequence)
--              Tests automatic homing after reset
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_reset_z is
end tb_reset_z;

architecture behavioral of tb_reset_z is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal limit_min_z   : std_logic := '1';  -- '1' = not hit, '0' = hit

    signal step_z        : std_logic;
    signal dir_z         : std_logic;
    signal enable_z      : std_logic;
    signal pos_z_zero    : std_logic;
    signal homing_active : std_logic;

    signal test_complete : boolean := false;

    -- Step counter
    signal step_count    : integer := 0;

begin

    clk <= not clk after CLK_PERIOD / 2 when not test_complete else '0';

    dut : entity work.reset_z
        generic map (
            CLK_FREQ_HZ     => 50_000_000,
            WAIT_TIME_MS    => 1,
            STEP_PERIOD_CYC => 5000  -- 100 us/step
        )
        port map (
            clk           => clk,
            rst           => rst,
            limit_min_z   => limit_min_z,
            step_z        => step_z,
            dir_z         => dir_z,
            enable_z      => enable_z,
            pos_z_zero    => pos_z_zero,
            homing_active => homing_active
        );

    stimulus : process
        variable l : line;
    begin
        write(l, string'("=== RESET_Z HOMING SEQUENCE TEST ==="));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Test 1: Initial state during reset
        write(l, string'("[TEST 1] Verify initial state during reset"));
        writeline(output, l);
        rst <= '1';
        wait for 500 ns;

        assert pos_z_zero = '0' report "[ERROR] pos_z_zero should be 0 during reset!" severity error;
        assert homing_active = '0' report "[ERROR] homing_active should be 0 during reset!" severity error;
        assert enable_z = '0' report "[ERROR] enable_z should be 0 during reset!" severity error;

        write(l, string'("[TEST 1] PASS: System idle during reset"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Test 2: Release reset and wait 1ms
        write(l, string'("[TEST 2] Release reset, waiting for 1ms delay..."));
        writeline(output, l);
        rst <= '0';
        wait for 100 ns;

        assert homing_active = '1' report "[ERROR] homing_active should be 1 after reset release!" severity error;
        assert pos_z_zero = '0' report "[ERROR] pos_z_zero should still be 0!" severity error;

        write(l, string'("[INFO] homing_active='1', waiting 1ms for WAIT_1MS state..."));
        writeline(output, l);

        -- Wait for 1ms
        wait for 1 ms;
        wait for 200 ns;  -- Extra margin

        write(l, string'("[TEST 2] PASS: 1ms delay complete, checking for step generation..."));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Test 3: Verify step generation during homing
        write(l, string'("[TEST 3] Verify STEP pulse generation"));
        writeline(output, l);

        assert enable_z = '1' report "[ERROR] enable_z should be 1 during homing!" severity error;
        assert dir_z = '0' report "[ERROR] dir_z should be 0 (negative direction)!" severity error;

        write(l, string'("[INFO] enable_z='1', dir_z='0' (negative) - OK"));
        writeline(output, l);
        write(l, string'("[INFO] Counting steps for 10ms (expecting ~100 steps)..."));
        writeline(output, l);

        -- Wait 10ms and count steps (counter is reset by rst signal)
        wait for 10 ms;

        write(l, string'("[INFO] Step count after 10ms: "));
        write(l, step_count);
        write(l, string'(" (expected ~100)"));
        writeline(output, l);

        -- Verify step count in reasonable range (95-105 steps)
        assert step_count >= 95 and step_count <= 105
            report "[ERROR] Step count out of range! Expected ~100, got " & integer'image(step_count)
            severity error;

        write(l, string'("[TEST 3] PASS: Step generation working correctly"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Test 4: Trigger limit switch
        write(l, string'("[TEST 4] Triggering limit switch (limit_min_z='0')..."));
        writeline(output, l);

        limit_min_z <= '0';  -- Simulate limit switch hit
        wait for 50 us;  -- Wait for debounce

        write(l, string'("[INFO] Limit switch hit at step count: "));
        write(l, step_count);
        writeline(output, l);

        assert homing_active = '1' report "[ERROR] homing_active should still be 1 during debounce!" severity error;

        -- Wait for debounce and transition to COMPLETE
        wait for 100 us;

        assert pos_z_zero = '1' report "[ERROR] pos_z_zero should be 1 after homing complete!" severity error;
        assert enable_z = '0' report "[ERROR] enable_z should be 0 after homing complete!" severity error;

        write(l, string'("[TEST 4] PASS: Homing sequence complete"));
        writeline(output, l);
        write(l, string'("[INFO] pos_z_zero='1' - System ready for operation"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Test 5: Verify system stays in COMPLETE state
        write(l, string'("[TEST 5] Verify system remains stable"));
        writeline(output, l);

        wait for 1 ms;

        assert pos_z_zero = '1' report "[ERROR] pos_z_zero should remain 1!" severity error;
        assert enable_z = '0' report "[ERROR] enable_z should remain 0!" severity error;
        assert homing_active = '0' report "[ERROR] homing_active should be 0 after complete!" severity error;

        write(l, string'("[TEST 5] PASS: System stable in COMPLETE state"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Final summary
        write(l, string'("=== ALL TESTS PASS ==="));
        writeline(output, l);
        write(l, string'("Total steps generated: "));
        write(l, step_count);
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -- Step counter process
    count_steps : process(clk)
        variable step_prev : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rst = '1' then
                step_count <= 0;
                step_prev := '0';
            else
                -- Count rising edges of step_z
                if step_z = '1' and step_prev = '0' then
                    step_count <= step_count + 1;
                end if;
                step_prev := step_z;
            end if;
        end if;
    end process;

end behavioral;
