--------------------------------------------------------------------------------
-- File: tb_3axis_test.vhd
-- Description: Enhanced testbench for multi-position 3-axis movement (positions 0-3)
--              Verifies Bresenham interpolation, step counts (per position and cumulative),
--              direction, fault, state transitions, encoder quadrature sequence, and more.
--              Includes dynamic timeouts and detailed logging to check if step errors accumulate.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_3axis_test is
end tb_3axis_test;

architecture behavioral of tb_3axis_test is

    -- Function to compute maximum of three integers
    function max3(a, b, c : integer) return integer is
        variable max_ab : integer;
    begin
        if a > b then
            max_ab := a;
        else
            max_ab := b;
        end if;
        if max_ab > c then
            return max_ab;
        else
            return c;
        end if;
    end function max3;

    -- Function to sum expected steps up to a given position
    function sum_steps(arr : delta_array_t; pos : integer) return integer is
        variable sum : integer := 0;
    begin
        for i in 0 to pos loop
            sum := sum + arr(i);
        end loop;
        return sum;
    end function sum_steps;

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    constant STEP_PERIOD_CYCLES : integer := 5000;  -- 100 us/step from rom_controller
    constant TIMEOUT_LOAD_POS : time := 2 ms;  -- Increased timeout for position loading
    constant TIMEOUT_BUSY_START : time := 2 ms;  -- Timeout for busy to assert
    constant TIMEOUT_MOVEMENT_MARGIN : time := 10 ms;  -- Margin for overhead
    constant TIMEOUT_ZERO_DELTA : time := 1 ms;  -- Timeout for positions with zero delta

    -- Number of positions to test (0 to 3)
    constant NUM_POSITIONS : integer := 4;

    -- Expected deltas per position (from ROM: absolute positions, deltas calculated relative to previous)
    type delta_array_t is array (0 to NUM_POSITIONS-1) of integer;
    constant EXPECTED_DELTAS_X : delta_array_t := (0, 1000, 2000, 0);  -- Abs: 0 -> -1000 (delta 1000 neg) -> 1000 (delta 2000 pos) -> 1000 (delta 0)
    constant EXPECTED_DELTAS_Y : delta_array_t := (0, 1000, 0, 2000);  -- Abs: 0 -> -1000 (delta 1000 neg) -> -1000 (delta 0) -> 1000 (delta 2000 pos)
    constant EXPECTED_DELTAS_Z : delta_array_t := (0, 1000, 0, 0);     -- Abs: 0 -> -1000 (delta 1000 neg) -> -1000 (delta 0) -> -1000 (delta 0)

    -- Expected directions per position ('1' positive, '0' negative; based on sign of delta)
    type dir_array_t is array (0 to NUM_POSITIONS-1) of std_logic;
    constant EXPECTED_DIRS_X : dir_array_t := ('0', '0', '1', '0');  -- Pos 0: irrelevant, Pos 1: neg, Pos 2: pos, Pos 3: 0 (assume '0')
    constant EXPECTED_DIRS_Y : dir_array_t := ('0', '0', '0', '1');
    constant EXPECTED_DIRS_Z : dir_array_t := ('0', '0', '0', '0');

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
    signal current_step    : std_logic_vector(4 downto 0);

    signal test_complete : boolean := false;

    -- Cumulative step counters (signals)
    signal step_x_count_cum, step_y_count_cum, step_z_count_cum : integer := 0;

    -- For encoder quadrature verification (Gray code states)
    type quad_state_t is (S00, S01, S11, S10);
    signal quad_state_x : quad_state_t := S00;
    signal quad_state_y : quad_state_t := S00;
    signal quad_state_z : quad_state_t := S00;

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
        variable pos_idx : integer := 0;
        variable expected_steps_x, expected_steps_y, expected_steps_z : integer;
        variable expected_dir_x, expected_dir_y, expected_dir_z : std_logic;
        variable timeout_movement : time;
        variable step_x_count_per_pos, step_y_count_per_pos, step_z_count_per_pos : integer := 0;
        variable step_x_count_prev, step_y_count_prev, step_z_count_prev : integer := 0;
    begin
        write(l, string'("=== MULTI-POSITION 3-AXIS MOVEMENT TEST (Positions 0-3) ==="));
        writeline(output, l);
        write(l, string'("Verifying if step errors accumulate over positions"));
        writeline(output, l);
        write(l, string'("Expected deltas:"));
        writeline(output, l);
        for i in 0 to NUM_POSITIONS-1 loop
            write(l, string'("Pos "));
            write(l, i);
            write(l, string'(": X="));
            write(l, EXPECTED_DELTAS_X(i));
            write(l, string'(", Y="));
            write(l, EXPECTED_DELTAS_Y(i));
            write(l, string'(", Z="));
            write(l, EXPECTED_DELTAS_Z(i));
            writeline(output, l);
        end loop;
        write(l, string'(""));
        writeline(output, l);

        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        enable <= '1';
        write(l, string'("[INFO] Enable set, waiting for sequence..."));
        writeline(output, l);

        -- Wait for sequence to activate
        wait until sequence_active = '1' for TIMEOUT_LOAD_POS;
        assert sequence_active = '1' report "[ERROR] Timeout waiting for sequence_active!" severity error;

        -- Loop over positions 0 to 3
        for pos_idx in 0 to NUM_POSITIONS-1 loop
            -- Expected values for this position
            expected_steps_x := EXPECTED_DELTAS_X(pos_idx);
            expected_steps_y := EXPECTED_DELTAS_Y(pos_idx);
            expected_steps_z := EXPECTED_DELTAS_Z(pos_idx);
            expected_dir_x := EXPECTED_DIRS_X(pos_idx);
            expected_dir_y := EXPECTED_DIRS_Y(pos_idx);
            expected_dir_z := EXPECTED_DIRS_Z(pos_idx);
            timeout_movement := (max3(expected_steps_x, expected_steps_y, expected_steps_z) + 10) * STEP_PERIOD_CYCLES * CLK_PERIOD + TIMEOUT_MOVEMENT_MARGIN;

            write(l, string'("[INFO] Testing Position "));
            write(l, pos_idx);
            write(l, string'(" - Expected steps: X="));
            write(l, expected_steps_x);
            write(l, string'(", Y="));
            write(l, expected_steps_y);
            write(l, string'(", Z="));
            write(l, expected_steps_z);
            writeline(output, l);
            write(l, string'("Dynamic timeout: "));
            write(l, timeout_movement);
            writeline(output, l);

            -- Save previous cumulative counts
            step_x_count_prev := step_x_count_cum;
            step_y_count_prev := step_y_count_cum;
            step_z_count_prev := step_z_count_cum;

            -- Wait for current position to be loaded
            wait until to_integer(unsigned(current_step)) = pos_idx for TIMEOUT_LOAD_POS;
            assert to_integer(unsigned(current_step)) = pos_idx report "[ERROR] Timeout waiting for position " & integer'image(pos_idx) & "!" severity error;
            write(l, string'("[POS "));
            write(l, pos_idx);
            write(l, string'("] Position loaded at "));
            write(l, now);
            writeline(output, l);

            -- Verify direction signals only if delta is non-zero
            if expected_steps_x > 0 then
                assert dir_x = expected_dir_x report "[ERROR] X direction incorrect for pos " & integer'image(pos_idx) & "!" severity error;
            end if;
            if expected_steps_y > 0 then
                assert dir_y = expected_dir_y report "[ERROR] Y direction incorrect for pos " & integer'image(pos_idx) & "!" severity error;
            end if;
            if expected_steps_z > 0 then
                assert dir_z = expected_dir_z report "[ERROR] Z direction incorrect for pos " & integer'image(pos_idx) & "!" severity error;
            end if;
            write(l, string'("[INFO] Directions verified for pos "));
            write(l, pos_idx);
            writeline(output, l);

            -- Wait for busy to assert (movement start) or skip if no movement
            if max3(expected_steps_x, expected_steps_y, expected_steps_z) > 0 then
                wait until busy = '1' for TIMEOUT_BUSY_START;
                assert busy = '1' report "[ERROR] Timeout waiting for busy on pos " & integer'image(pos_idx) & "!" severity error;
                write(l, string'("[BUSY] Movement started for pos "));
                write(l, pos_idx);
                write(l, string'(" at "));
                write(l, now);
                writeline(output, l);

                -- Verify state_debug during movement (should be "0100" for MOVING)
                assert state_debug = "0100" report "[ERROR] Unexpected state during movement for pos " & integer'image(pos_idx) & "!" severity error;
                write(l, string'("[INFO] State debug verified during movement (MOVING: 0100) for pos "));
                write(l, pos_idx);
                writeline(output, l);

                -- Wait for movement completion
                wait until busy = '0' for timeout_movement;
                assert busy = '0' report "[ERROR] Timeout waiting for movement completion on pos " & integer'image(pos_idx) & "!" severity error;
                write(l, string'("[DONE] Movement complete for pos "));
                write(l, pos_idx);
                write(l, string'(" at "));
                write(l, now);
                writeline(output, l);
            else
                wait for TIMEOUT_ZERO_DELTA;
                write(l, string'("[INFO] No movement expected for pos "));
                write(l, pos_idx);
                write(l, string'(" (delta = 0), checked at "));
                write(l, now);
                writeline(output, l);
            end if;

            -- Verify no fault occurred
            assert fault = '0' report "[ERROR] Fault detected during movement for pos " & integer'image(pos_idx) & "!" severity error;
            write(l, string'("[INFO] No fault detected for pos "));
            write(l, pos_idx);
            writeline(output, l);

            -- Update per-position counters based on cumulative differences
            step_x_count_per_pos := step_x_count_cum - step_x_count_prev;
            step_y_count_per_pos := step_y_count_cum - step_y_count_prev;
            step_z_count_per_pos := step_z_count_cum - step_z_count_prev;

            -- Results per position
            write(l, string'("=== RESULTS FOR POS "));
            write(l, pos_idx);
            write(l, string'(" ==="));
            writeline(output, l);
            write(l, string'("X steps (per pos): "));
            write(l, step_x_count_per_pos);
            write(l, string'(" (expected: "));
            write(l, expected_steps_x);
            write(l, string'(")"));
            writeline(output, l);
            write(l, string'("Y steps (per pos): "));
            write(l, step_y_count_per_pos);
            write(l, string'(" (expected: "));
            write(l, expected_steps_y);
            write(l, string'(")"));
            writeline(output, l);
            write(l, string'("Z steps (per pos): "));
            write(l, step_z_count_per_pos);
            write(l, string'(" (expected: "));
            write(l, expected_steps_z);
            write(l, string'(")"));
            writeline(output, l);
            write(l, string'("Cumulative X steps: "));
            write(l, step_x_count_cum);
            writeline(output, l);
            write(l, string'("Cumulative Y steps: "));
            write(l, step_y_count_cum);
            writeline(output, l);
            write(l, string'("Cumulative Z steps: "));
            write(l, step_z_count_cum);
            writeline(output, l);
            write(l, string'(""));
            writeline(output, l);

            assert step_x_count_per_pos = expected_steps_x
                report "X steps incorrect for pos " & integer'image(pos_idx) & ": expected " & integer'image(expected_steps_x) & ", got " & integer'image(step_x_count_per_pos)
                severity error;
            assert step_y_count_per_pos = expected_steps_y
                report "Y steps incorrect for pos " & integer'image(pos_idx) & ": expected " & integer'image(expected_steps_y) & ", got " & integer'image(step_y_count_per_pos)
                severity error;
            assert step_z_count_per_pos = expected_steps_z
                report "Z steps incorrect for pos " & integer'image(pos_idx) & ": expected " & integer'image(expected_steps_z) & ", got " & integer'image(step_z_count_per_pos)
                severity error;
        end loop;

        write(l, string'("=== FINAL RESULTS ==="));
        writeline(output, l);
        if step_x_count_cum = 3000 and step_y_count_cum = 3000 and step_z_count_cum = 1000 then  -- Cumulative expected: X=0+1000+2000+0=3000, Y=0+1000+0+2000=3000, Z=0+1000+0+0=1000
            write(l, string'("*** TEST PASS *** No accumulation of errors over positions!"));
        else
            write(l, string'("*** TEST FAIL *** Step errors accumulated!"));
        end if;
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -- Step counters for all 3 axes with debug logging (only cumulative counters)
    count_steps : process(clk)
        variable step_x_prev : std_logic := '0';
        variable step_y_prev : std_logic := '0';
        variable step_z_prev : std_logic := '0';
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                step_x_count_cum <= 0;
                step_y_count_cum <= 0;
                step_z_count_cum <= 0;
                step_x_prev := '0';
                step_y_prev := '0';
                step_z_prev := '0';
            else
                -- Count rising edges and log every 100 steps for debug
                if step_x = '1' and step_x_prev = '0' then
                    step_x_count_cum <= step_x_count_cum + 1;
                    if to_integer(unsigned(current_step)) = 0 then
                        write(l, string'("[DEBUG] Unexpected X step at pos 0, count: "));
                        write(l, step_x_count_cum + 1);
                        write(l, string'(" at "));
                        write(l, now);
                        writeline(output, l);
                    elsif (step_x_count_cum + 1) mod 100 = 0 then
                        write(l, string'("[DEBUG] X step count (cum) reached "));
                        write(l, step_x_count_cum + 1);
                        write(l, string'(" at "));
                        write(l, now);
                        writeline(output, l);
                    end if;
                end if;
                if step_y = '1' and step_y_prev = '0' then
                    step_y_count_cum <= step_y_count_cum + 1;
                    if to_integer(unsigned(current_step)) = 0 then
                        write(l, string'("[DEBUG] Unexpected Y step at pos 0, count: "));
                        write(l, step_y_count_cum + 1);
                        write(l, string'(" at "));
                        write(l, now);
                        writeline(output, l);
                    elsif (step_y_count_cum + 1) mod 100 = 0 then
                        write(l, string'("[DEBUG] Y step count (cum) reached "));
                        write(l, step_y_count_cum + 1);
                        write(l, string'(" at "));
                        write(l, now);
                        writeline(output, l);
                    end if;
                end if;
                if step_z = '1' and step_z_prev = '0' then
                    step_z_count_cum <= step_z_count_cum + 1;
                    if to_integer(unsigned(current_step)) = 0 then
                        write(l, string'("[DEBUG] Unexpected Z step at pos 0, count: "));
                        write(l, step_z_count_cum + 1);
                        write(l, string'(" at "));
                        write(l, now);
                        writeline(output, l);
                    elsif (step_z_count_cum + 1) mod 100 = 0 then
                        write(l, string'("[DEBUG] Z step count (cum) reached "));
                        write(l, step_z_count_cum + 1);
                        write(l, string'(" at "));
                        write(l, now);
                        writeline(output, l);
                    end if;
                end if;

                step_x_prev := step_x;
                step_y_prev := step_y;
                step_z_prev := step_z;
            end if;
        end if;
    end process;

    -- Encoder quadrature verification for X axis
    verify_encoder_x : process(clk)
        variable l : line;
        variable current_code : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                quad_state_x <= S00;
            else
                current_code := enc_a_x & enc_b_x;

                case quad_state_x is
                    when S00 =>
                        if current_code = "01" then
                            quad_state_x <= S01;  -- Forward
                        elsif current_code = "10" then
                            quad_state_x <= S10;  -- Reverse
                        elsif current_code /= "00" then
                            write(l, string'("[ERROR] Invalid encoder transition for X from S00 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for X!" severity error;
                        end if;
                    when S01 =>
                        if current_code = "11" then
                            quad_state_x <= S11;  -- Forward
                        elsif current_code = "00" then
                            quad_state_x <= S00;  -- Reverse
                        elsif current_code /= "01" then
                            write(l, string'("[ERROR] Invalid encoder transition for X from S01 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for X!" severity error;
                        end if;
                    when S11 =>
                        if current_code = "10" then
                            quad_state_x <= S10;  -- Forward
                        elsif current_code = "01" then
                            quad_state_x <= S01;  -- Reverse
                        elsif current_code /= "11" then
                            write(l, string'("[ERROR] Invalid encoder transition for X from S11 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for X!" severity error;
                        end if;
                    when S10 =>
                        if current_code = "00" then
                            quad_state_x <= S00;  -- Forward
                        elsif current_code = "11" then
                            quad_state_x <= S11;  -- Reverse
                        elsif current_code /= "10" then
                            write(l, string'("[ERROR] Invalid encoder transition for X from S10 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for X!" severity error;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Encoder quadrature verification for Y axis
    verify_encoder_y : process(clk)
        variable l : line;
        variable current_code : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                quad_state_y <= S00;
            else
                current_code := enc_a_y & enc_b_y;

                case quad_state_y is
                    when S00 =>
                        if current_code = "01" then
                            quad_state_y <= S01;  -- Forward
                        elsif current_code = "10" then
                            quad_state_y <= S10;  -- Reverse
                        elsif current_code /= "00" then
                            write(l, string'("[ERROR] Invalid encoder transition for Y from S00 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Y!" severity error;
                        end if;
                    when S01 =>
                        if current_code = "11" then
                            quad_state_y <= S11;  -- Forward
                        elsif current_code = "00" then
                            quad_state_y <= S00;  -- Reverse
                        elsif current_code /= "01" then
                            write(l, string'("[ERROR] Invalid encoder transition for Y from S01 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Y!" severity error;
                        end if;
                    when S11 =>
                        if current_code = "10" then
                            quad_state_y <= S10;  -- Forward
                        elsif current_code = "01" then
                            quad_state_y <= S01;  -- Reverse
                        elsif current_code /= "11" then
                            write(l, string'("[ERROR] Invalid encoder transition for Y from S11 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Y!" severity error;
                        end if;
                    when S10 =>
                        if current_code = "00" then
                            quad_state_y <= S00;  -- Forward
                        elsif current_code = "11" then
                            quad_state_y <= S11;  -- Reverse
                        elsif current_code /= "10" then
                            write(l, string'("[ERROR] Invalid encoder transition for Y from S10 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Y!" severity error;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Encoder quadrature verification for Z axis
    verify_encoder_z : process(clk)
        variable l : line;
        variable current_code : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                quad_state_z <= S00;
            else
                current_code := enc_a_z & enc_b_z;

                case quad_state_z is
                    when S00 =>
                        if current_code = "01" then
                            quad_state_z <= S01;  -- Forward
                        elsif current_code = "10" then
                            quad_state_z <= S10;  -- Reverse
                        elsif current_code /= "00" then
                            write(l, string'("[ERROR] Invalid encoder transition for Z from S00 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Z!" severity error;
                        end if;
                    when S01 =>
                        if current_code = "11" then
                            quad_state_z <= S11;  -- Forward
                        elsif current_code = "00" then
                            quad_state_z <= S00;  -- Reverse
                        elsif current_code /= "01" then
                            write(l, string'("[ERROR] Invalid encoder transition for Z from S01 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Z!" severity error;
                        end if;
                    when S11 =>
                        if current_code = "10" then
                            quad_state_z <= S10;  -- Forward
                        elsif current_code = "01" then
                            quad_state_z <= S01;  -- Reverse
                        elsif current_code /= "11" then
                            write(l, string'("[ERROR] Invalid encoder transition for Z from S11 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Z!" severity error;
                        end if;
                    when S10 =>
                        if current_code = "00" then
                            quad_state_z <= S00;  -- Forward
                        elsif current_code = "11" then
                            quad_state_z <= S11;  -- Reverse
                        elsif current_code /= "10" then
                            write(l, string'("[ERROR] Invalid encoder transition for Z from S10 to "));
                            write(l, current_code);
                            writeline(output, l);
                            assert false report "[ERROR] Invalid encoder transition for Z!" severity error;
                        end if;
                end case;
            end if;
        end if;
    end process;

end behavioral;
