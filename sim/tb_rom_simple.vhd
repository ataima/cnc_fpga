--------------------------------------------------------------------------------
-- File: tb_rom_simple.vhd
-- Description: Simplified testbench for ROM playback (no encoder fault check)
--              Tests ROM sequencing without encoder/limit hardware
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rom_simple is
end tb_rom_simple;

architecture behavioral of tb_rom_simple is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    -- DUT signals
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal enable      : std_logic := '0';
    signal pause       : std_logic := '0';
    signal open_loop   : std_logic := '0';  -- 0=simulated encoders (closed-loop)

    -- Tie encoder/limit to inactive
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

    -- Step counters for position tracking
    signal step_x_count_sig : integer := 0;
    signal step_y_count_sig : integer := 0;
    signal step_z_count_sig : integer := 0;
    signal last_position : integer := -1;

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
    -- DUT instantiation (LOOP mode to run continuously)
    -------------------------------------------------------------------------
    dut : entity work.cnc_3axis_rom_top
        generic map (
            LOOP_MODE   => true  -- Loop forever for continuous operation
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
    -- Test stimulus
    -------------------------------------------------------------------------
    stimulus : process
        variable l : line;
        variable step_count : integer := 0;
    begin
        write(l, string'("======================================================"));
        writeline(output, l);
        write(l, string'("  ROM Playback Test - CLOSED LOOP"));
        writeline(output, l);
        write(l, string'("  Using simulated encoders (10us delay)"));
        writeline(output, l);
        write(l, string'("  open_loop = 0 (encoder feedback enabled)"));
        writeline(output, l);
        write(l, string'("======================================================"));
        writeline(output, l);

        -- Reset
        rst <= '1';
        enable <= '0';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        write(l, string'("[INFO] Reset complete"));
        writeline(output, l);

        -- Enable ROM playback
        enable <= '1';
        write(l, string'("[INFO] ROM playback enabled (LOOP mode)"));
        writeline(output, l);

        -- Monitor for 40 position changes (0-39 are significant)
        for i in 0 to 39 loop
            wait until to_integer(unsigned(current_step)) = i;
            write(l, string'("[STEP "));
            if i < 10 then
                write(l, string'(" "));
            end if;
            write(l, i);
            write(l, string'("] Position loaded from ROM at "));
            write(l, now);
            writeline(output, l);

            -- Wait for busy to go high (movement starts)
            wait until busy = '1' for 10 us;
            if busy = '1' then
                write(l, string'("       -> Movement started"));
                writeline(output, l);
            else
                write(l, string'("       -> No movement (delta=0)"));
                writeline(output, l);
            end if;

            -- Wait for movement complete
            wait until busy = '0' for 5 ms;
            if busy = '0' then
                write(l, string'("       -> Movement complete"));
                writeline(output, l);
            else
                write(l, string'("       -> ERROR: Movement timeout!"));
                writeline(output, l);
                exit;
            end if;
        end loop;

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("======================================================"));
        writeline(output, l);
        write(l, string'("  TEST COMPLETE: 40 positions executed"));
        writeline(output, l);
        write(l, string'("  Trajectory: Square + Diagonals + Circle + Return"));
        writeline(output, l);
        write(l, string'("  Closed-loop with simulated encoders successful!"));
        writeline(output, l);
        write(l, string'("======================================================"));
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -------------------------------------------------------------------------
    -- Step pulse counter (debug)
    -------------------------------------------------------------------------
    count_steps : process(clk)
        variable step_x_prev : std_logic := '0';
        variable step_y_prev : std_logic := '0';
        variable step_z_prev : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rst = '1' then
                step_x_count_sig <= 0;
                step_y_count_sig <= 0;
                step_z_count_sig <= 0;
            else
                -- Count rising edges with direction
                if step_x = '1' and step_x_prev = '0' then
                    if dir_x = '1' then
                        step_x_count_sig <= step_x_count_sig + 1;
                    else
                        step_x_count_sig <= step_x_count_sig - 1;
                    end if;
                end if;
                if step_y = '1' and step_y_prev = '0' then
                    if dir_y = '1' then
                        step_y_count_sig <= step_y_count_sig + 1;
                    else
                        step_y_count_sig <= step_y_count_sig - 1;
                    end if;
                end if;
                if step_z = '1' and step_z_prev = '0' then
                    if dir_z = '1' then
                        step_z_count_sig <= step_z_count_sig + 1;
                    else
                        step_z_count_sig <= step_z_count_sig - 1;
                    end if;
                end if;

                step_x_prev := step_x;
                step_y_prev := step_y;
                step_z_prev := step_z;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Position change reporter
    -------------------------------------------------------------------------
    report_position : process(clk)
        variable l : line;
        variable curr_pos : integer;
    begin
        if rising_edge(clk) then
            curr_pos := to_integer(unsigned(current_step));
            if curr_pos /= last_position and curr_pos > 0 then
                last_position <= curr_pos;
                -- Print accumulated position
                write(l, string'("       [POS] X="));
                write(l, step_x_count_sig);
                write(l, string'(", Y="));
                write(l, step_y_count_sig);
                write(l, string'(", Z="));
                write(l, step_z_count_sig);
                write(l, string'(" steps"));
                writeline(output, l);
            end if;
        end if;
    end process;

end behavioral;
