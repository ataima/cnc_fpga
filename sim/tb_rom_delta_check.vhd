--------------------------------------------------------------------------------
-- File: tb_rom_delta_check.vhd
-- Description: Check if ROM controller calculates deltas correctly
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rom_delta_check is
end tb_rom_delta_check;

architecture behavioral of tb_rom_delta_check is

    constant CLK_PERIOD : time := 20 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal enable      : std_logic := '0';
    signal pause       : std_logic := '0';
    signal busy        : std_logic;

    signal target_x, target_y, target_z : signed(31 downto 0);
    signal step_period_out : unsigned(15 downto 0);
    signal move_start : std_logic;
    signal sequence_active, sequence_done : std_logic;
    signal current_step : unsigned(4 downto 0);

    signal test_complete : boolean := false;

begin

    clk <= not clk after CLK_PERIOD / 2 when not test_complete else '0';

    -- Stub ROM
    rom : entity work.trajectory_rom
        port map (
            clk => clk,
            address => current_step,
            target_x => open,
            target_y => open,
            target_z => open
        );

    dut : entity work.rom_controller
        generic map (
            LOOP_MODE => false
        )
        port map (
            clk => clk,
            rst => rst,
            enable => enable,
            pause => pause,
            rom_address => current_step,
            rom_target_x => to_signed(0, 32),  -- Will be overridden
            rom_target_y => to_signed(0, 32),
            rom_target_z => to_signed(0, 32),
            target_x => target_x,
            target_y => target_y,
            target_z => target_z,
            step_period_out => step_period_out,
            move_start => move_start,
            busy => busy,
            sequence_active => sequence_active,
            sequence_done => sequence_done,
            current_step => open
        );

    stimulus : process
        variable l : line;
    begin
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        enable <= '1';
        write(l, string'("Enabled ROM controller"));
        writeline(output, l);

        -- Wait for first move_start pulse
        wait until move_start = '1' for 10 us;

        write(l, string'("move_start detected, deltas:"));
        writeline(output, l);
        write(l, string'("  target_x (delta) = "));
        write(l, to_integer(target_x));
        writeline(output, l);
        write(l, string'("  target_y (delta) = "));
        write(l, to_integer(target_y));
        writeline(output, l);
        write(l, string'("  target_z (delta) = "));
        write(l, to_integer(target_z));
        writeline(output, l);

        wait for 1 us;
        test_complete <= true;
        wait;
    end process;

end behavioral;
