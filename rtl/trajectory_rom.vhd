--------------------------------------------------------------------------------
-- File: trajectory_rom.vhd
-- Description: Pre-programmed trajectory ROM for CNC testing
--              Stores 24 fixed positions (X, Y, Z) @ 32-bit each
--              Total: 24 × 3 × 4 bytes = 288 bytes
--              Geometry: Cube (2000x2000x2000) + Double Pyramid (1000x1000x1000)
--
-- Usage: Provides hardcoded trajectory for FPGA testing without external interface
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-13 (Updated from 64 to 24 positions)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trajectory_rom is
    port (
        clk         : in  std_logic;
        address     : in  unsigned(4 downto 0);  -- 0 to 23 (5 bits)
        target_x    : out signed(31 downto 0);
        target_y    : out signed(31 downto 0);
        target_z    : out signed(31 downto 0)
    );
end trajectory_rom;

architecture rtl of trajectory_rom is

    -- ROM type: 24 positions × 3 coordinates
    type position_array is array (0 to 23) of signed(31 downto 0);

    -- Pre-programmed trajectory: Cube (2000×2000×2000) + Double Pyramid (1000×1000×1000)
    -- Cube centered at origin, vertices at (±1000, ±1000, ±1000)
    -- Inferior pyramid: base at Z=-1000 (500×500), vertex at (0,0,0)
    -- Superior pyramid: base at Z=+1000 (500×500), vertex at (0,0,0)
    -- Optimized path to minimize travel distance
    constant ROM_X : position_array := (
        -- Start at origin (0)
        to_signed(0, 32),           -- 0: Origin (0, 0, 0)

        -- Cube bottom vertices (1-4): Z = -1000
        to_signed(-1000, 32),       -- 1: Bottom-front-left
        to_signed(1000, 32),        -- 2: Bottom-front-right
        to_signed(1000, 32),        -- 3: Bottom-back-right
        to_signed(-1000, 32),       -- 4: Bottom-back-left

        -- Inferior pyramid base vertices (5-8): Z = -1000
        to_signed(-500, 32),        -- 5: Inferior pyramid base vertex 1
        to_signed(500, 32),         -- 6: Inferior pyramid base vertex 2
        to_signed(500, 32),         -- 7: Inferior pyramid base vertex 3
        to_signed(-500, 32),        -- 8: Inferior pyramid base vertex 4

        -- Return to center (9): inferior pyramid vertex
        to_signed(0, 32),           -- 9: Center (0, 0, 0) - inferior pyramid vertex

        -- Superior pyramid base vertices (10-13): Z = +1000
        to_signed(-500, 32),        -- 10: Superior pyramid base vertex 1
        to_signed(500, 32),         -- 11: Superior pyramid base vertex 2
        to_signed(500, 32),         -- 12: Superior pyramid base vertex 3
        to_signed(-500, 32),        -- 13: Superior pyramid base vertex 4

        -- Return to center (14): superior pyramid vertex
        to_signed(0, 32),           -- 14: Center (0, 0, 0) - superior pyramid vertex

        -- Cube top vertices (15-18): Z = +1000
        to_signed(-1000, 32),       -- 15: Top-front-left
        to_signed(1000, 32),        -- 16: Top-front-right
        to_signed(1000, 32),        -- 17: Top-back-right
        to_signed(-1000, 32),       -- 18: Top-back-left

        -- Diagonal traversals (19-22)
        to_signed(-1000, 32),       -- 19: Diagonal to bottom-front-left
        to_signed(1000, 32),        -- 20: Diagonal to top-back-right
        to_signed(-1000, 32),       -- 21: Diagonal to bottom-back-left
        to_signed(1000, 32),        -- 22: Diagonal to top-front-right

        -- Final return to origin (23)
        to_signed(0, 32)            -- 23: Return to origin (0, 0, 0)
    );

    constant ROM_Y : position_array := (
        -- Start at origin (0)
        to_signed(0, 32),           -- 0: Origin (0, 0, 0)

        -- Cube bottom vertices (1-4): Z = -1000
        to_signed(-1000, 32),       -- 1: Bottom-front-left
        to_signed(-1000, 32),       -- 2: Bottom-front-right
        to_signed(1000, 32),        -- 3: Bottom-back-right
        to_signed(1000, 32),        -- 4: Bottom-back-left

        -- Inferior pyramid base vertices (5-8): Z = -1000
        to_signed(-500, 32),        -- 5: Inferior pyramid base vertex 1
        to_signed(-500, 32),        -- 6: Inferior pyramid base vertex 2
        to_signed(500, 32),         -- 7: Inferior pyramid base vertex 3
        to_signed(500, 32),         -- 8: Inferior pyramid base vertex 4

        -- Return to center (9): inferior pyramid vertex
        to_signed(0, 32),           -- 9: Center (0, 0, 0) - inferior pyramid vertex

        -- Superior pyramid base vertices (10-13): Z = +1000
        to_signed(-500, 32),        -- 10: Superior pyramid base vertex 1
        to_signed(-500, 32),        -- 11: Superior pyramid base vertex 2
        to_signed(500, 32),         -- 12: Superior pyramid base vertex 3
        to_signed(500, 32),         -- 13: Superior pyramid base vertex 4

        -- Return to center (14): superior pyramid vertex
        to_signed(0, 32),           -- 14: Center (0, 0, 0) - superior pyramid vertex

        -- Cube top vertices (15-18): Z = +1000
        to_signed(-1000, 32),       -- 15: Top-front-left
        to_signed(-1000, 32),       -- 16: Top-front-right
        to_signed(1000, 32),        -- 17: Top-back-right
        to_signed(1000, 32),        -- 18: Top-back-left

        -- Diagonal traversals (19-22)
        to_signed(-1000, 32),       -- 19: Diagonal to bottom-front-left
        to_signed(1000, 32),        -- 20: Diagonal to top-back-right
        to_signed(1000, 32),        -- 21: Diagonal to bottom-back-left
        to_signed(-1000, 32),       -- 22: Diagonal to top-front-right

        -- Final return to origin (23)
        to_signed(0, 32)            -- 23: Return to origin (0, 0, 0)
    );

    constant ROM_Z : position_array := (
        -- Start at origin (0)
        to_signed(0, 32),           -- 0: Origin (0, 0, 0)

        -- Cube bottom vertices (1-4): Z = -1000
        to_signed(-1000, 32),       -- 1: Bottom-front-left
        to_signed(-1000, 32),       -- 2: Bottom-front-right
        to_signed(-1000, 32),       -- 3: Bottom-back-right
        to_signed(-1000, 32),       -- 4: Bottom-back-left

        -- Inferior pyramid base vertices (5-8): Z = -1000
        to_signed(-1000, 32),       -- 5: Inferior pyramid base vertex 1
        to_signed(-1000, 32),       -- 6: Inferior pyramid base vertex 2
        to_signed(-1000, 32),       -- 7: Inferior pyramid base vertex 3
        to_signed(-1000, 32),       -- 8: Inferior pyramid base vertex 4

        -- Return to center (9): inferior pyramid vertex
        to_signed(0, 32),           -- 9: Center (0, 0, 0) - inferior pyramid vertex

        -- Superior pyramid base vertices (10-13): Z = +1000
        to_signed(1000, 32),        -- 10: Superior pyramid base vertex 1
        to_signed(1000, 32),        -- 11: Superior pyramid base vertex 2
        to_signed(1000, 32),        -- 12: Superior pyramid base vertex 3
        to_signed(1000, 32),        -- 13: Superior pyramid base vertex 4

        -- Return to center (14): superior pyramid vertex
        to_signed(0, 32),           -- 14: Center (0, 0, 0) - superior pyramid vertex

        -- Cube top vertices (15-18): Z = +1000
        to_signed(1000, 32),        -- 15: Top-front-left
        to_signed(1000, 32),        -- 16: Top-front-right
        to_signed(1000, 32),        -- 17: Top-back-right
        to_signed(1000, 32),        -- 18: Top-back-left

        -- Diagonal traversals (19-22)
        to_signed(-1000, 32),       -- 19: Diagonal to bottom-front-left
        to_signed(1000, 32),        -- 20: Diagonal to top-back-right
        to_signed(-1000, 32),       -- 21: Diagonal to bottom-back-left
        to_signed(1000, 32),        -- 22: Diagonal to top-front-right

        -- Final return to origin (23)
        to_signed(0, 32)            -- 23: Return to origin (0, 0, 0)
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
