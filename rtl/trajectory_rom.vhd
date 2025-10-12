--------------------------------------------------------------------------------
-- File: trajectory_rom.vhd
-- Description: Pre-programmed trajectory ROM for CNC testing
--              Stores 64 fixed positions (X, Y, Z) @ 32-bit each
--              Total: 64 × 3 × 4 bytes = 768 bytes
--
-- Usage: Provides hardcoded trajectory for FPGA testing without external interface
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-12
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trajectory_rom is
    port (
        clk         : in  std_logic;
        address     : in  unsigned(5 downto 0);  -- 0 to 63
        target_x    : out signed(31 downto 0);
        target_y    : out signed(31 downto 0);
        target_z    : out signed(31 downto 0)
    );
end trajectory_rom;

architecture rtl of trajectory_rom is

    -- ROM type: 64 positions × 3 coordinates
    type position_array is array (0 to 63) of signed(31 downto 0);

    -- Pre-programmed trajectory: Square pattern with Z lift
    -- Pattern: 50mm square (assuming 200 steps/mm = 10000 steps per side)
    constant ROM_X : position_array := (
        -- Home position and lift Z (0-3)
        to_signed(0, 32),       -- 0: Origin
        to_signed(0, 32),       -- 1: Stay
        to_signed(0, 32),       -- 2: Stay
        to_signed(0, 32),       -- 3: Stay

        -- First side: Move +X (4-7)
        to_signed(2500, 32),    -- 4: +X quarter
        to_signed(5000, 32),    -- 5: +X half
        to_signed(7500, 32),    -- 6: +X three-quarter
        to_signed(10000, 32),   -- 7: +X full (50mm)

        -- Second side: Move +Y (8-11)
        to_signed(10000, 32),   -- 8: Stay X
        to_signed(10000, 32),   -- 9: Stay X
        to_signed(10000, 32),   -- 10: Stay X
        to_signed(10000, 32),   -- 11: Stay X

        -- Third side: Move -X (12-15)
        to_signed(7500, 32),    -- 12: -X quarter
        to_signed(5000, 32),    -- 13: -X half
        to_signed(2500, 32),    -- 14: -X three-quarter
        to_signed(0, 32),       -- 15: -X back to origin

        -- Fourth side: Move -Y (16-19)
        to_signed(0, 32),       -- 16: Stay X
        to_signed(0, 32),       -- 17: Stay X
        to_signed(0, 32),       -- 18: Stay X
        to_signed(0, 32),       -- 19: Stay X

        -- Diagonal test (20-27)
        to_signed(5000, 32),    -- 20: Diagonal +X+Y
        to_signed(10000, 32),   -- 21: Diagonal continue
        to_signed(10000, 32),   -- 22: To corner
        to_signed(5000, 32),    -- 23: Diagonal -X-Y
        to_signed(0, 32),       -- 24: Back to origin
        to_signed(-5000, 32),   -- 25: Diagonal -X-Y continue
        to_signed(0, 32),       -- 26: Back to origin
        to_signed(0, 32),       -- 27: Stay

        -- Circle approximation (8 points, 28-35)
        to_signed(10000, 32),   -- 28: 0°   (R=10000)
        to_signed(7071, 32),    -- 29: 45°  (R*cos(45))
        to_signed(0, 32),       -- 30: 90°
        to_signed(-7071, 32),   -- 31: 135°
        to_signed(-10000, 32),  -- 32: 180°
        to_signed(-7071, 32),   -- 33: 225°
        to_signed(0, 32),       -- 34: 270°
        to_signed(7071, 32),    -- 35: 315°

        -- Return home and rest (36-63)
        to_signed(5000, 32),    -- 36: Move to center
        to_signed(0, 32),       -- 37: Return X
        to_signed(0, 32),       -- 38: Stay
        to_signed(0, 32),       -- 39: Stay

        -- Fill remaining with zeros
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 40-43
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 44-47
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 48-51
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 52-55
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 56-59
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32)   -- 60-63
    );

    constant ROM_Y : position_array := (
        -- Home position and lift Z (0-3)
        to_signed(0, 32),       -- 0: Origin
        to_signed(0, 32),       -- 1: Stay
        to_signed(0, 32),       -- 2: Stay
        to_signed(0, 32),       -- 3: Stay

        -- First side: Move +X, Y stays (4-7)
        to_signed(0, 32),       -- 4
        to_signed(0, 32),       -- 5
        to_signed(0, 32),       -- 6
        to_signed(0, 32),       -- 7

        -- Second side: Move +Y (8-11)
        to_signed(2500, 32),    -- 8: +Y quarter
        to_signed(5000, 32),    -- 9: +Y half
        to_signed(7500, 32),    -- 10: +Y three-quarter
        to_signed(10000, 32),   -- 11: +Y full

        -- Third side: Move -X, Y stays (12-15)
        to_signed(10000, 32),   -- 12: Stay Y
        to_signed(10000, 32),   -- 13: Stay Y
        to_signed(10000, 32),   -- 14: Stay Y
        to_signed(10000, 32),   -- 15: Stay Y

        -- Fourth side: Move -Y (16-19)
        to_signed(7500, 32),    -- 16: -Y quarter
        to_signed(5000, 32),    -- 17: -Y half
        to_signed(2500, 32),    -- 18: -Y three-quarter
        to_signed(0, 32),       -- 19: -Y back to origin

        -- Diagonal test (20-27)
        to_signed(5000, 32),    -- 20: Diagonal +X+Y
        to_signed(10000, 32),   -- 21: Diagonal continue
        to_signed(10000, 32),   -- 22: To corner
        to_signed(5000, 32),    -- 23: Diagonal -X-Y
        to_signed(0, 32),       -- 24: Back to origin
        to_signed(-5000, 32),   -- 25: Diagonal -X-Y continue
        to_signed(0, 32),       -- 26: Back to origin
        to_signed(0, 32),       -- 27: Stay

        -- Circle approximation (8 points, 28-35)
        to_signed(0, 32),       -- 28: 0°
        to_signed(7071, 32),    -- 29: 45°
        to_signed(10000, 32),   -- 30: 90°
        to_signed(7071, 32),    -- 31: 135°
        to_signed(0, 32),       -- 32: 180°
        to_signed(-7071, 32),   -- 33: 225°
        to_signed(-10000, 32),  -- 34: 270°
        to_signed(-7071, 32),   -- 35: 315°

        -- Return home (36-63)
        to_signed(-5000, 32),   -- 36: Move to center
        to_signed(0, 32),       -- 37: Return Y
        to_signed(0, 32),       -- 38: Stay
        to_signed(0, 32),       -- 39: Stay

        -- Fill remaining with zeros
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 40-43
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 44-47
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 48-51
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 52-55
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 56-59
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32)   -- 60-63
    );

    constant ROM_Z : position_array := (
        -- Z lift sequence (0-3)
        to_signed(0, 32),       -- 0: Z down (start)
        to_signed(1000, 32),    -- 1: Z up 5mm (clearance)
        to_signed(1000, 32),    -- 2: Z stay up
        to_signed(1000, 32),    -- 3: Z stay up

        -- Z stays up during XY movements (4-35)
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 4-7
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 8-11
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 12-15
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 16-19
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 20-23
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 24-27
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 28-31
        to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32), to_signed(1000, 32),  -- 32-35

        -- Z down at end (36-39)
        to_signed(500, 32),     -- 36: Z halfway down
        to_signed(0, 32),       -- 37: Z fully down
        to_signed(0, 32),       -- 38: Z stay down
        to_signed(0, 32),       -- 39: Z stay down

        -- Fill remaining with zeros
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 40-43
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 44-47
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 48-51
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 52-55
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32),  -- 56-59
        to_signed(0, 32), to_signed(0, 32), to_signed(0, 32), to_signed(0, 32)   -- 60-63
    );

begin

    -- Synchronous ROM read
    process(clk)
    begin
        if rising_edge(clk) then
            target_x <= ROM_X(to_integer(address));
            target_y <= ROM_Y(to_integer(address));
            target_z <= ROM_Z(to_integer(address));
        end if;
    end process;

end rtl;
