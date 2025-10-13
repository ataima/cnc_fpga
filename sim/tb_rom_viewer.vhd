--------------------------------------------------------------------------------
-- File: tb_rom_viewer.vhd
-- Description: ROM content viewer - prints all 64 positions without execution
--              Quick way to see what trajectory is programmed in ROM
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rom_viewer is
end tb_rom_viewer;

architecture behavioral of tb_rom_viewer is

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    signal clk     : std_logic := '0';
    signal address : unsigned(5 downto 0) := (others => '0');

    signal target_x : signed(31 downto 0);
    signal target_y : signed(31 downto 0);
    signal target_z : signed(31 downto 0);

    signal done : boolean := false;

begin

    -------------------------------------------------------------------------
    -- Clock generation
    -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2 when not done else '0';

    -------------------------------------------------------------------------
    -- ROM instantiation
    -------------------------------------------------------------------------
    rom : entity work.trajectory_rom
        port map (
            clk      => clk,
            address  => address,
            target_x => target_x,
            target_y => target_y,
            target_z => target_z
        );

    -------------------------------------------------------------------------
    -- ROM content viewer
    -------------------------------------------------------------------------
    viewer : process
        variable l : line;
        variable delta_x, delta_y, delta_z : signed(31 downto 0);
        variable prev_x, prev_y, prev_z : signed(31 downto 0) := (others => '0');
    begin
        wait for 50 ns;  -- Initial delay

        write(l, string'("================================================================================"));
        writeline(output, l);
        write(l, string'("  ROM TRAJECTORY CONTENT - All 64 Positions"));
        writeline(output, l);
        write(l, string'("  File: trajectory_rom.vhd"));
        writeline(output, l);
        write(l, string'("================================================================================"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);

        write(l, string'("Pos | Absolute Position (steps)    | Delta from Previous (steps)  | Description"));
        writeline(output, l);
        write(l, string'("----+--------------------------------+------------------------------+------------------"));
        writeline(output, l);

        -- Read all 64 positions
        for i in 0 to 63 loop
            address <= to_unsigned(i, 6);
            wait until rising_edge(clk);
            wait for 1 ns;  -- Let signals settle

            -- Calculate deltas
            delta_x := target_x - prev_x;
            delta_y := target_y - prev_y;
            delta_z := target_z - prev_z;

            -- Print position
            write(l, string'(" "));
            if i < 10 then
                write(l, string'(" "));
            end if;
            write(l, i);
            write(l, string'(" | X="));
            write(l, to_integer(target_x));
            write(l, string'(", Y="));
            write(l, to_integer(target_y));
            write(l, string'(", Z="));
            write(l, to_integer(target_z));

            -- Pad spacing
            write(l, string'("          "));

            -- Print deltas
            write(l, string'("| dX="));
            write(l, to_integer(delta_x));
            write(l, string'(", dY="));
            write(l, to_integer(delta_y));
            write(l, string'(", dZ="));
            write(l, to_integer(delta_z));

            write(l, string'("        "));

            -- Add description
            write(l, string'("| "));
            if i = 0 then
                write(l, string'("Home/Origin"));
            elsif i >= 1 and i <= 3 then
                write(l, string'("Z lift prep"));
            elsif i >= 4 and i <= 7 then
                write(l, string'("Square: +X side"));
            elsif i >= 8 and i <= 11 then
                write(l, string'("Square: +Y side"));
            elsif i >= 12 and i <= 15 then
                write(l, string'("Square: -X side"));
            elsif i >= 16 and i <= 19 then
                write(l, string'("Square: -Y side"));
            elsif i >= 20 and i <= 27 then
                write(l, string'("Diagonal tests"));
            elsif i >= 28 and i <= 35 then
                write(l, string'("Circle (8-point)"));
            elsif i >= 36 and i <= 39 then
                write(l, string'("Return home"));
            else
                write(l, string'("Padding (no move)"));
            end if;

            writeline(output, l);

            -- Update previous values
            prev_x := target_x;
            prev_y := target_y;
            prev_z := target_z;
        end loop;

        write(l, string'(""));
        writeline(output, l);
        write(l, string'("================================================================================"));
        writeline(output, l);
        write(l, string'("  ROM Content Display Complete"));
        writeline(output, l);
        write(l, string'(""));
        writeline(output, l);
        write(l, string'("  Trajectory Summary:"));
        writeline(output, l);
        write(l, string'("    - Positions 0-3:   Home and Z lift preparation"));
        writeline(output, l);
        write(l, string'("    - Positions 4-19:  Square pattern (50mm sides, 10000 steps)"));
        writeline(output, l);
        write(l, string'("    - Positions 20-27: Diagonal movements"));
        writeline(output, l);
        write(l, string'("    - Positions 28-35: Circle approximation (8 points)"));
        writeline(output, l);
        write(l, string'("    - Positions 36-39: Return to home and Z down"));
        writeline(output, l);
        write(l, string'("    - Positions 40-63: Padding (all zeros)"));
        writeline(output, l);
        write(l, string'("================================================================================"));
        writeline(output, l);

        done <= true;
        wait;
    end process;

end behavioral;
