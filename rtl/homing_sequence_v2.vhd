--------------------------------------------------------------------------------
-- File: homing_sequence_v2.vhd
-- Description: Complete 3-axis homing with release and offset
--              Sequence per axis: HOMING → RELEASE → OFFSET (200) → ZERO
--              Cascade: Z → Y → X → ROM enabled
--
-- Each axis procedure:
--   1. Move to limit_min until hit
--   2. Move forward until switch released
--   3. Move additional 200 steps forward
--   4. Set position = 0
--   5. Enable next axis
--
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-16
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity homing_sequence_v2 is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- 50 MHz
        WAIT_TIME_MS    : integer := 1;           -- Wait after reset
        OFFSET_STEPS    : integer := 200          -- Steps from limit to zero
    );
    port (
        -- System
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- Limit switches (active low: 0=hit, 1=not hit)
        limit_min_x     : in  std_logic;
        limit_min_y     : in  std_logic;
        limit_min_z     : in  std_logic;

        -- Motor control outputs
        step_x          : out std_logic;
        dir_x           : out std_logic;
        enable_x        : out std_logic;

        step_y          : out std_logic;
        dir_y           : out std_logic;
        enable_y        : out std_logic;

        step_z          : out std_logic;
        dir_z           : out std_logic;
        enable_z        : out std_logic;

        -- Position feedback (all zero after homing)
        pos_x           : out signed(31 downto 0);
        pos_y           : out signed(31 downto 0);
        pos_z           : out signed(31 downto 0);

        -- Homing status outputs
        pos_z_zero      : out std_logic;          -- Z axis homed
        pos_y_zero      : out std_logic;          -- Y axis homed
        pos_x_zero      : out std_logic;          -- X axis homed (enables ROM)

        -- Overall status
        all_axes_homed  : out std_logic;          -- All 3 axes homed
        all_axes_homed_n : out std_logic;         -- All 3 axes homed (active low)
        homing_active   : out std_logic;          -- High during any homing

        -- Debug outputs
        state_z         : out std_logic_vector(2 downto 0);
        state_y         : out std_logic_vector(2 downto 0);
        state_x         : out std_logic_vector(2 downto 0)
    );
end homing_sequence_v2;

architecture structural of homing_sequence_v2 is

    -- Cascaded enable signals
    signal enable_z_homing  : std_logic := '0';
    signal enable_y_homing  : std_logic;
    signal enable_x_homing  : std_logic;

    -- Homing status per axis
    signal z_homed : std_logic;
    signal y_homed : std_logic;
    signal x_homed : std_logic;

    -- Activity flags
    signal z_active : std_logic;
    signal y_active : std_logic;
    signal x_active : std_logic;

    -- Wait timer
    constant WAIT_CYCLES : integer := (CLK_FREQ_HZ / 1000) * WAIT_TIME_MS;
    signal wait_counter  : integer range 0 to WAIT_CYCLES := 0;
    signal wait_done     : std_logic := '0';

begin

    -- Output assignments
    pos_z_zero       <= z_homed;
    pos_y_zero       <= y_homed;
    pos_x_zero       <= x_homed;
    all_axes_homed   <= x_homed;
    all_axes_homed_n <= not x_homed;  -- Negated (active low)
    homing_active    <= z_active or y_active or x_active;

    -- Cascaded enable
    enable_z_homing <= wait_done;       -- Z starts after 1ms
    enable_y_homing <= z_homed;         -- Y starts when Z complete
    enable_x_homing <= y_homed;         -- X starts when Y complete

    -- Wait timer
    process(clk, rst)
    begin
        if rst = '1' then
            wait_counter <= 0;
            wait_done    <= '0';
        elsif rising_edge(clk) then
            if wait_counter < WAIT_CYCLES - 1 then
                wait_counter <= wait_counter + 1;
                wait_done    <= '0';
            else
                wait_done <= '1';
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Z Axis Homing (first in sequence)
    -------------------------------------------------------------------------
    u_homing_z : entity work.axis_homing_v3
        generic map (
            CLK_FREQ_HZ     => CLK_FREQ_HZ,
            STEP_PERIOD_CYC => 5000,
            OFFSET_STEPS    => OFFSET_STEPS,
            AXIS_NAME       => "Z"
        )
        port map (
            clk           => clk,
            rst           => rst,
            enable_homing => enable_z_homing,
            limit_min     => limit_min_z,
            step_out      => step_z,
            dir_out       => dir_z,
            enable_out    => enable_z,
            current_pos   => pos_z,
            axis_homed    => z_homed,
            homing_active => z_active,
            current_state => state_z
        );

    -------------------------------------------------------------------------
    -- Y Axis Homing (second in sequence)
    -------------------------------------------------------------------------
    u_homing_y : entity work.axis_homing_v3
        generic map (
            CLK_FREQ_HZ     => CLK_FREQ_HZ,
            STEP_PERIOD_CYC => 5000,
            OFFSET_STEPS    => OFFSET_STEPS,
            AXIS_NAME       => "Y"
        )
        port map (
            clk           => clk,
            rst           => rst,
            enable_homing => enable_y_homing,
            limit_min     => limit_min_y,
            step_out      => step_y,
            dir_out       => dir_y,
            enable_out    => enable_y,
            current_pos   => pos_y,
            axis_homed    => y_homed,
            homing_active => y_active,
            current_state => state_y
        );

    -------------------------------------------------------------------------
    -- X Axis Homing (third in sequence)
    -------------------------------------------------------------------------
    u_homing_x : entity work.axis_homing_v3
        generic map (
            CLK_FREQ_HZ     => CLK_FREQ_HZ,
            STEP_PERIOD_CYC => 5000,
            OFFSET_STEPS    => OFFSET_STEPS,
            AXIS_NAME       => "X"
        )
        port map (
            clk           => clk,
            rst           => rst,
            enable_homing => enable_x_homing,
            limit_min     => limit_min_x,
            step_out      => step_x,
            dir_out       => dir_x,
            enable_out    => enable_x,
            current_pos   => pos_x,
            axis_homed    => x_homed,
            homing_active => x_active,
            current_state => state_x
        );

end structural;
