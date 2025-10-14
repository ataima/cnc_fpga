--------------------------------------------------------------------------------
-- File: tb_rom_debug.vhd
-- Description: Debug testbench - monitors internal signals to understand
--              why movements are not generating steps
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rom_debug is
end tb_rom_debug;

architecture behavioral of tb_rom_debug is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal enable      : std_logic := '0';
    signal pause       : std_logic := '0';
    signal open_loop   : std_logic := '0';

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
    signal current_step    : std_logic_vector(4 downto 0);

    signal test_complete : boolean := false;

begin

    -------------------------------------------------------------------------
    -- Clock generation
    -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2 when not test_complete else '0';

    -------------------------------------------------------------------------
    -- DUT instantiation
    -------------------------------------------------------------------------
    dut : entity work.cnc_3axis_rom_top
        generic map (
            LOOP_MODE   => false  -- ONE_SHOT for controlled testing
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
    begin
        write(l, string'("================================================================"));
        writeline(output, l);
        write(l, string'("  ROM DEBUG TEST - Monitoring first 10 positions"));
        writeline(output, l);
        write(l, string'("================================================================"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Reset
        rst <= '1';
        enable <= '0';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        write(l, string'("[INFO] Starting ROM playback..."));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        -- Enable
        enable <= '1';
        wait for 100 us;  -- Wait for first few positions

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("================================================================"));
        writeline(output, l);
        write(l, string'("  Check transcript above for delta values and busy behavior"));
        writeline(output, l);
        write(l, string'("================================================================"));
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -------------------------------------------------------------------------
    -- Signal monitor - prints deltas and busy transitions
    -------------------------------------------------------------------------
    monitor : process
        variable l : line;
        variable last_step : integer := -1;
        variable last_busy : std_logic := '0';
        variable step_count : integer := 0;
    begin
        wait until rising_edge(clk);

        -- Monitor position changes
        if to_integer(unsigned(current_step)) /= last_step then
            last_step := to_integer(unsigned(current_step));
            write(l, string'("[POS "));
            if last_step < 10 then
                write(l, string'(" "));
            end if;
            write(l, last_step);
            write(l, string'("] Loaded at "));
            write(l, now);
            writeline(output, l);
        end if;

        -- Monitor busy transitions
        if busy /= last_busy then
            if busy = '1' then
                write(l, string'("      BUSY='1' (movement starting) @ "));
                write(l, now);
                writeline(output, l);
            else
                write(l, string'("      BUSY='0' (movement done) @ "));
                write(l, now);
                write(l, string'(" - steps="));
                write(l, step_count);
                writeline(output, l);
                step_count := 0;  -- Reset for next movement
            end if;
            last_busy := busy;
        end if;

        -- Count steps
        if busy = '1' then
            if step_x = '1' or step_y = '1' or step_z = '1' then
                step_count := step_count + 1;
            end if;
        end if;

    end process;

end behavioral;
