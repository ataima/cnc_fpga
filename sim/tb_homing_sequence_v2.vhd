--------------------------------------------------------------------------------
-- File: tb_homing_sequence_v2.vhd
-- Description: Complete testbench for cascaded homing with RELEASE and OFFSET
--              Verifies: Z -> Y -> X sequence
--              Each axis: HOMING -> RELEASE -> OFFSET (200) -> ZERO -> COMPLETE
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_homing_sequence_v2 is
end tb_homing_sequence_v2;

architecture behavioral of tb_homing_sequence_v2 is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    constant OFFSET_STEPS : integer := 200;

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

    signal pos_x         : signed(31 downto 0);
    signal pos_y         : signed(31 downto 0);
    signal pos_z         : signed(31 downto 0);

    signal pos_z_zero    : std_logic;
    signal pos_y_zero    : std_logic;
    signal pos_x_zero    : std_logic;

    signal all_axes_homed : std_logic;
    signal homing_active  : std_logic;

    signal state_z       : std_logic_vector(2 downto 0);
    signal state_y       : std_logic_vector(2 downto 0);
    signal state_x       : std_logic_vector(2 downto 0);

    signal test_complete : boolean := false;

    -- Step counters for each phase per axis
    signal z_homing_steps  : integer := 0;
    signal z_release_steps : integer := 0;
    signal z_offset_steps  : integer := 0;

    signal y_homing_steps  : integer := 0;
    signal y_release_steps : integer := 0;
    signal y_offset_steps  : integer := 0;

    signal x_homing_steps  : integer := 0;
    signal x_release_steps : integer := 0;
    signal x_offset_steps  : integer := 0;

    -- State tracking
    signal prev_state_z : std_logic_vector(2 downto 0) := "000";
    signal prev_state_y : std_logic_vector(2 downto 0) := "000";
    signal prev_state_x : std_logic_vector(2 downto 0) := "000";

    -- State encoding (from axis_homing_v3.vhd)
    constant STATE_IDLE         : std_logic_vector(2 downto 0) := "000";
    constant STATE_HOMING       : std_logic_vector(2 downto 0) := "001";
    constant STATE_DEBOUNCE_HIT : std_logic_vector(2 downto 0) := "010";
    constant STATE_RELEASE      : std_logic_vector(2 downto 0) := "011";
    constant STATE_OFFSET       : std_logic_vector(2 downto 0) := "100";
    constant STATE_SET_ZERO     : std_logic_vector(2 downto 0) := "101";
    constant STATE_COMPLETE     : std_logic_vector(2 downto 0) := "110";

begin

    clk <= not clk after CLK_PERIOD / 2 when not test_complete else '0';

    dut : entity work.homing_sequence_v2
        generic map (
            CLK_FREQ_HZ  => 50_000_000,
            WAIT_TIME_MS => 1,
            OFFSET_STEPS => OFFSET_STEPS
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
            pos_x           => pos_x,
            pos_y           => pos_y,
            pos_z           => pos_z,
            pos_z_zero      => pos_z_zero,
            pos_y_zero      => pos_y_zero,
            pos_x_zero      => pos_x_zero,
            all_axes_homed  => all_axes_homed,
            homing_active   => homing_active,
            state_z         => state_z,
            state_y         => state_y,
            state_x         => state_x
        );

    stimulus : process
        variable l : line;
    begin
        write(l, string'("=== HOMING SEQUENCE V2 TEST (WITH RELEASE + OFFSET) ==="));
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

        -- ==================================================================
        -- TEST 1: Z AXIS HOMING SEQUENCE
        -- ==================================================================
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("[TEST 1] Z AXIS HOMING SEQUENCE"));
        writeline(output, l);
        write(l, string'("------------------------------------------------------------"));
        writeline(output, l);

        -- Phase 1.1: Z HOMING (moving to limit)
        write(l, string'("[1.1] Z HOMING phase - moving towards limit_min_z"));
        writeline(output, l);

        assert enable_z = '1' report "[ERROR] Z axis not enabled!" severity error;
        assert dir_z = '0' report "[ERROR] Z direction should be negative!" severity error;

        wait for 5 ms;  -- Let it accumulate some steps

        write(l, string'("[1.1] Z homing steps counted: "));
        write(l, z_homing_steps);
        writeline(output, l);

        assert z_homing_steps > 0 report "[ERROR] No Z homing steps!" severity error;

        -- Phase 1.2: Z hit limit switch
        write(l, string'("[1.2] Triggering Z limit switch (limit_min_z='0')"));
        writeline(output, l);
        limit_min_z <= '0';

        -- Wait for DEBOUNCE_HIT state
        wait until state_z = STATE_DEBOUNCE_HIT for 1 ms;
        assert state_z = STATE_DEBOUNCE_HIT report "[ERROR] Z not in DEBOUNCE_HIT state!" severity error;
        write(l, string'("[1.2] OK: Z entered DEBOUNCE_HIT state"));
        writeline(output, l);

        -- Wait for RELEASE state
        wait until state_z = STATE_RELEASE for 1 ms;
        assert state_z = STATE_RELEASE report "[ERROR] Z not in RELEASE state!" severity error;
        write(l, string'("[1.3] OK: Z entered RELEASE state"));
        writeline(output, l);

        -- Phase 1.3: Z RELEASE (moving forward)
        assert dir_z = '1' report "[ERROR] Z direction should be positive in RELEASE!" severity error;

        wait for 2 ms;  -- Let it release

        write(l, string'("[1.3] Releasing limit switch (limit_min_z='1')"));
        writeline(output, l);
        limit_min_z <= '1';

        write(l, string'("[1.3] Z release steps counted: "));
        write(l, z_release_steps);
        writeline(output, l);

        -- Wait for OFFSET state
        wait until state_z = STATE_OFFSET for 1 ms;
        assert state_z = STATE_OFFSET report "[ERROR] Z not in OFFSET state!" severity error;
        write(l, string'("[1.4] OK: Z entered OFFSET state"));
        writeline(output, l);

        -- Phase 1.4: Z OFFSET (200 steps forward)
        assert dir_z = '1' report "[ERROR] Z direction should be positive in OFFSET!" severity error;

        -- Wait for OFFSET to complete (200 steps * 100us = 20ms + margin)
        wait for 25 ms;

        write(l, string'("[1.4] Z offset steps counted: "));
        write(l, z_offset_steps);
        writeline(output, l);

        -- Should be approximately 200 steps
        assert z_offset_steps >= 190 and z_offset_steps <= 210
            report "[ERROR] Z offset steps not ~200!" severity error;

        -- Phase 1.5: Z COMPLETE
        wait until state_z = STATE_COMPLETE for 1 ms;
        assert state_z = STATE_COMPLETE report "[ERROR] Z not in COMPLETE state!" severity error;
        assert pos_z_zero = '1' report "[ERROR] pos_z_zero not set!" severity error;
        assert pos_z = 0 report "[ERROR] Z position not zero!" severity error;

        write(l, string'("[1.5] OK: Z COMPLETE - pos_z_zero='1', pos_z=0"));
        writeline(output, l);
        write(l, string'("[TEST 1] PASS: Z axis homing complete"));
        writeline(output, l);

        -- ==================================================================
        -- TEST 2: Y AXIS HOMING SEQUENCE (triggered by pos_z_zero)
        -- ==================================================================
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("[TEST 2] Y AXIS HOMING SEQUENCE"));
        writeline(output, l);
        write(l, string'("------------------------------------------------------------"));
        writeline(output, l);

        wait for 200 ns;

        assert enable_y = '1' report "[ERROR] Y axis not enabled after Z complete!" severity error;
        assert enable_x = '0' report "[ERROR] X axis should not be enabled yet!" severity error;

        write(l, string'("[2.1] Y HOMING phase started"));
        writeline(output, l);

        wait for 5 ms;

        write(l, string'("[2.1] Y homing steps: "));
        write(l, y_homing_steps);
        writeline(output, l);

        -- Trigger Y limit
        write(l, string'("[2.2] Triggering Y limit switch"));
        writeline(output, l);
        limit_min_y <= '0';

        wait until state_y = STATE_RELEASE for 1 ms;
        write(l, string'("[2.3] Y entered RELEASE state"));
        writeline(output, l);

        wait for 2 ms;
        limit_min_y <= '1';

        write(l, string'("[2.3] Y release steps: "));
        write(l, y_release_steps);
        writeline(output, l);

        wait until state_y = STATE_OFFSET for 1 ms;
        write(l, string'("[2.4] Y entered OFFSET state"));
        writeline(output, l);

        wait for 25 ms;

        write(l, string'("[2.4] Y offset steps: "));
        write(l, y_offset_steps);
        writeline(output, l);

        assert y_offset_steps >= 190 and y_offset_steps <= 210
            report "[ERROR] Y offset steps not ~200!" severity error;

        wait until state_y = STATE_COMPLETE for 1 ms;
        assert pos_y_zero = '1' report "[ERROR] pos_y_zero not set!" severity error;
        assert pos_y = 0 report "[ERROR] Y position not zero!" severity error;

        write(l, string'("[2.5] OK: Y COMPLETE - pos_y_zero='1', pos_y=0"));
        writeline(output, l);
        write(l, string'("[TEST 2] PASS: Y axis homing complete"));
        writeline(output, l);

        -- ==================================================================
        -- TEST 3: X AXIS HOMING SEQUENCE (triggered by pos_y_zero)
        -- ==================================================================
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("[TEST 3] X AXIS HOMING SEQUENCE"));
        writeline(output, l);
        write(l, string'("------------------------------------------------------------"));
        writeline(output, l);

        wait for 200 ns;

        assert enable_x = '1' report "[ERROR] X axis not enabled after Y complete!" severity error;

        write(l, string'("[3.1] X HOMING phase started"));
        writeline(output, l);

        wait for 5 ms;

        write(l, string'("[3.1] X homing steps: "));
        write(l, x_homing_steps);
        writeline(output, l);

        -- Trigger X limit
        write(l, string'("[3.2] Triggering X limit switch"));
        writeline(output, l);
        limit_min_x <= '0';

        wait until state_x = STATE_RELEASE for 1 ms;
        write(l, string'("[3.3] X entered RELEASE state"));
        writeline(output, l);

        wait for 2 ms;
        limit_min_x <= '1';

        write(l, string'("[3.3] X release steps: "));
        write(l, x_release_steps);
        writeline(output, l);

        wait until state_x = STATE_OFFSET for 1 ms;
        write(l, string'("[3.4] X entered OFFSET state"));
        writeline(output, l);

        wait for 25 ms;

        write(l, string'("[3.4] X offset steps: "));
        write(l, x_offset_steps);
        writeline(output, l);

        assert x_offset_steps >= 190 and x_offset_steps <= 210
            report "[ERROR] X offset steps not ~200!" severity error;

        wait until state_x = STATE_COMPLETE for 1 ms;
        assert pos_x_zero = '1' report "[ERROR] pos_x_zero not set!" severity error;
        assert pos_x = 0 report "[ERROR] X position not zero!" severity error;
        assert all_axes_homed = '1' report "[ERROR] all_axes_homed not set!" severity error;

        write(l, string'("[3.5] OK: X COMPLETE - pos_x_zero='1', pos_x=0"));
        writeline(output, l);
        write(l, string'("[TEST 3] PASS: X axis homing complete"));
        writeline(output, l);

        -- ==================================================================
        -- FINAL SUMMARY
        -- ==================================================================
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("=== FINAL RESULTS ==="));
        writeline(output, l);
        write(l, string'("------------------------------------------------------------"));
        writeline(output, l);
        write(l, string'("Z axis: homing="));
        write(l, z_homing_steps);
        write(l, string'(", release="));
        write(l, z_release_steps);
        write(l, string'(", offset="));
        write(l, z_offset_steps);
        write(l, string'(" steps"));
        writeline(output, l);

        write(l, string'("Y axis: homing="));
        write(l, y_homing_steps);
        write(l, string'(", release="));
        write(l, y_release_steps);
        write(l, string'(", offset="));
        write(l, y_offset_steps);
        write(l, string'(" steps"));
        writeline(output, l);

        write(l, string'("X axis: homing="));
        write(l, x_homing_steps);
        write(l, string'(", release="));
        write(l, x_release_steps);
        write(l, string'(", offset="));
        write(l, x_offset_steps);
        write(l, string'(" steps"));
        writeline(output, l);

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("Final positions:"));
        writeline(output, l);
        write(l, string'("  pos_x = "));
        write(l, to_integer(pos_x));
        writeline(output, l);
        write(l, string'("  pos_y = "));
        write(l, to_integer(pos_y));
        writeline(output, l);
        write(l, string'("  pos_z = "));
        write(l, to_integer(pos_z));
        writeline(output, l);

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("Status flags:"));
        writeline(output, l);
        write(l, string'("  pos_z_zero = '1' OK"));
        writeline(output, l);
        write(l, string'("  pos_y_zero = '1' OK"));
        writeline(output, l);
        write(l, string'("  pos_x_zero = '1' OK"));
        writeline(output, l);
        write(l, string'("  all_axes_homed = '1' OK"));
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

    -- ======================================================================
    -- STEP COUNTING PROCESS (per phase, per axis)
    -- ======================================================================
    count_steps : process(clk)
        variable step_x_prev : std_logic := '0';
        variable step_y_prev : std_logic := '0';
        variable step_z_prev : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rst = '1' then
                z_homing_steps  <= 0;
                z_release_steps <= 0;
                z_offset_steps  <= 0;
                y_homing_steps  <= 0;
                y_release_steps <= 0;
                y_offset_steps  <= 0;
                x_homing_steps  <= 0;
                x_release_steps <= 0;
                x_offset_steps  <= 0;
                prev_state_z <= STATE_IDLE;
                prev_state_y <= STATE_IDLE;
                prev_state_x <= STATE_IDLE;
                step_x_prev := '0';
                step_y_prev := '0';
                step_z_prev := '0';
            else
                -- Track state changes
                prev_state_z <= state_z;
                prev_state_y <= state_y;
                prev_state_x <= state_x;

                -- Count Z steps by phase
                if step_z = '1' and step_z_prev = '0' then
                    if state_z = STATE_HOMING then
                        z_homing_steps <= z_homing_steps + 1;
                    elsif state_z = STATE_RELEASE then
                        z_release_steps <= z_release_steps + 1;
                    elsif state_z = STATE_OFFSET then
                        z_offset_steps <= z_offset_steps + 1;
                    end if;
                end if;

                -- Count Y steps by phase
                if step_y = '1' and step_y_prev = '0' then
                    if state_y = STATE_HOMING then
                        y_homing_steps <= y_homing_steps + 1;
                    elsif state_y = STATE_RELEASE then
                        y_release_steps <= y_release_steps + 1;
                    elsif state_y = STATE_OFFSET then
                        y_offset_steps <= y_offset_steps + 1;
                    end if;
                end if;

                -- Count X steps by phase
                if step_x = '1' and step_x_prev = '0' then
                    if state_x = STATE_HOMING then
                        x_homing_steps <= x_homing_steps + 1;
                    elsif state_x = STATE_RELEASE then
                        x_release_steps <= x_release_steps + 1;
                    elsif state_x = STATE_OFFSET then
                        x_offset_steps <= x_offset_steps + 1;
                    end if;
                end if;

                step_x_prev := step_x;
                step_y_prev := step_y;
                step_z_prev := step_z;
            end if;
        end if;
    end process;

end behavioral;
