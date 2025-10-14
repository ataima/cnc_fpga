--------------------------------------------------------------------------------
-- File: tb_single_move.vhd
-- Description: Minimal testbench - tests a single movement to debug step generation
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_single_move is
end tb_single_move;

architecture behavioral of tb_single_move is

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
    signal current_step    : std_logic_vector(4 downto 0);

    signal test_complete : boolean := false;

    -- Step counters
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
        write(l, string'("=== SINGLE MOVEMENT TEST ==="));
        writeline(output, l);
        write(l, string'("Testing position 0->1 (Z: 0->10000)"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

        enable <= '1';
        write(l, string'("[INFO] Enable set, waiting for position 1..."));
        writeline(output, l);

        -- Wait for position 1 to be loaded
        wait until to_integer(unsigned(current_step)) = 1 for 10 us;

        write(l, string'("[POS 1] Loaded at "));
        write(l, now);
        writeline(output, l);

        -- Wait for busy
        wait until busy = '1' for 10 us;
        write(l, string'("[BUSY] High at "));
        write(l, now);
        writeline(output, l);

        -- Wait for first step pulse
        wait until step_z = '1' for 500 us;
        if step_z = '1' then
            write(l, string'("[STEP] First Z step at "));
            write(l, now);
            writeline(output, l);
        else
            write(l, string'("[ERROR] No Z step pulse detected!"));
            writeline(output, l);
        end if;

        -- Wait a bit more to see multiple steps
        wait for 1 ms;

        write(l, string'("[INFO] Z step count = "));
        write(l, step_z_count);
        write(l, string'(" at "));
        write(l, now);
        writeline(output, l);

        test_complete <= true;
        wait;
    end process;

    -- Step counter
    count_z_steps : process(clk)
        variable step_prev : std_logic := '0';
    begin
        if rising_edge(clk) then
            if step_z = '1' and step_prev = '0' then
                step_z_count <= step_z_count + 1;
            end if;
            step_prev := step_z;
        end if;
    end process;

end behavioral;
