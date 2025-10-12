--------------------------------------------------------------------------------
-- File: cnc_3axis_rom_top.vhd
-- Description: Top-level integration with ROM-based trajectory playback
--              Connects: trajectory_rom → rom_controller → cnc_3axis_controller
--              Solves pin count issue: only 38 external pins needed!
--
-- Pin Count:
--   - Encoders: 6 (X/Y/Z A/B channels)
--   - Limit switches: 6 (X/Y/Z min/max)
--   - Motor outputs: 9 (X/Y/Z STEP/DIR/ENABLE)
--   - Control: 4 (clk, rst, enable, pause)
--   - Status: 7 (busy, fault, state_debug[3:0], sequence_active, sequence_done)
--   - Debug: 6 (current_step[5:0])
--   TOTAL: 38 pins (vs 211 in original design!)
--
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-12
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cnc_pkg.all;

entity cnc_3axis_rom_top is
    generic (
        LOOP_MODE   : boolean := true  -- true = infinite loop
    );
    port (
        -- System
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Control (simplified interface)
        enable      : in  std_logic;  -- Master enable + ROM playback enable
        pause       : in  std_logic;  -- Pause ROM playback
        open_loop   : in  std_logic;  -- 0=simulated encoders, 1=external encoders

        -- Encoder inputs (6 pins)
        enc_a_x     : in  std_logic;
        enc_b_x     : in  std_logic;
        enc_a_y     : in  std_logic;
        enc_b_y     : in  std_logic;
        enc_a_z     : in  std_logic;
        enc_b_z     : in  std_logic;

        -- Limit switch inputs (6 pins)
        limit_min_x : in  std_logic;
        limit_max_x : in  std_logic;
        limit_min_y : in  std_logic;
        limit_max_y : in  std_logic;
        limit_min_z : in  std_logic;
        limit_max_z : in  std_logic;

        -- Motor outputs (9 pins)
        step_x      : out std_logic;
        dir_x       : out std_logic;
        enable_x    : out std_logic;
        step_y      : out std_logic;
        dir_y       : out std_logic;
        enable_y    : out std_logic;
        step_z      : out std_logic;
        dir_z       : out std_logic;
        enable_z    : out std_logic;

        -- Status outputs (7 pins)
        busy             : out std_logic;
        fault            : out std_logic;
        state_debug      : out std_logic_vector(3 downto 0);
        sequence_active  : out std_logic;  -- ROM playback active
        sequence_done    : out std_logic;  -- ROM playback complete (ONE_SHOT)

        -- Debug outputs (6 pins)
        current_step     : out std_logic_vector(5 downto 0)  -- Current ROM position
    );
end cnc_3axis_rom_top;

architecture structural of cnc_3axis_rom_top is

    -- Internal signals: ROM interface
    signal rom_address   : unsigned(5 downto 0);
    signal rom_target_x  : signed(31 downto 0);
    signal rom_target_y  : signed(31 downto 0);
    signal rom_target_z  : signed(31 downto 0);

    -- Internal signals: CNC controller interface
    signal target_x      : signed(31 downto 0);
    signal target_y      : signed(31 downto 0);
    signal target_z      : signed(31 downto 0);
    signal step_period   : unsigned(15 downto 0);
    signal move_start    : std_logic;
    signal move_abort    : std_logic := '0';  -- Not used in ROM mode
    signal busy_int      : std_logic;

    -- Internal signals: position feedback (not used externally)
    signal pos_x         : signed(31 downto 0);
    signal pos_y         : signed(31 downto 0);
    signal pos_z         : signed(31 downto 0);

    -- Debug
    signal current_step_int : unsigned(5 downto 0);

    -- Encoder simulator signals
    signal sim_enc_a_x, sim_enc_b_x : std_logic;
    signal sim_enc_a_y, sim_enc_b_y : std_logic;
    signal sim_enc_a_z, sim_enc_b_z : std_logic;

    -- Muxed encoder signals (simulated or external)
    signal enc_a_x_mux, enc_b_x_mux : std_logic;
    signal enc_a_y_mux, enc_b_y_mux : std_logic;
    signal enc_a_z_mux, enc_b_z_mux : std_logic;

    -- Motor output buffers (VHDL-93: cannot read output ports)
    signal step_x_int, dir_x_int, enable_x_int : std_logic;
    signal step_y_int, dir_y_int, enable_y_int : std_logic;
    signal step_z_int, dir_z_int, enable_z_int : std_logic;

begin

    -- Output assignments
    busy <= busy_int;
    current_step <= std_logic_vector(current_step_int);

    -- Motor outputs (buffered)
    step_x   <= step_x_int;
    dir_x    <= dir_x_int;
    enable_x <= enable_x_int;
    step_y   <= step_y_int;
    dir_y    <= dir_y_int;
    enable_y <= enable_y_int;
    step_z   <= step_z_int;
    dir_z    <= dir_z_int;
    enable_z <= enable_z_int;

    -------------------------------------------------------------------------
    -- Encoder MUX: Select simulated or external encoders
    -------------------------------------------------------------------------
    enc_a_x_mux <= sim_enc_a_x when open_loop = '0' else enc_a_x;
    enc_b_x_mux <= sim_enc_b_x when open_loop = '0' else enc_b_x;
    enc_a_y_mux <= sim_enc_a_y when open_loop = '0' else enc_a_y;
    enc_b_y_mux <= sim_enc_b_y when open_loop = '0' else enc_b_y;
    enc_a_z_mux <= sim_enc_a_z when open_loop = '0' else enc_a_z;
    enc_b_z_mux <= sim_enc_b_z when open_loop = '0' else enc_b_z;

    -------------------------------------------------------------------------
    -- Trajectory ROM (768 bytes)
    -------------------------------------------------------------------------
    u_trajectory_rom : entity work.trajectory_rom
        port map (
            clk      => clk,
            address  => rom_address,
            target_x => rom_target_x,
            target_y => rom_target_y,
            target_z => rom_target_z
        );

    -------------------------------------------------------------------------
    -- ROM Controller (auto-sequencer)
    -------------------------------------------------------------------------
    u_rom_controller : entity work.rom_controller
        generic map (
            LOOP_MODE => LOOP_MODE
        )
        port map (
            clk             => clk,
            rst             => rst,
            enable          => enable,
            pause           => pause,

            -- ROM interface
            rom_address     => rom_address,
            rom_target_x    => rom_target_x,
            rom_target_y    => rom_target_y,
            rom_target_z    => rom_target_z,

            -- CNC controller interface
            target_x        => target_x,
            target_y        => target_y,
            target_z        => target_z,
            step_period_out => step_period,
            move_start      => move_start,
            busy            => busy_int,

            -- Status
            sequence_active => sequence_active,
            sequence_done   => sequence_done,
            current_step    => current_step_int
        );

    -------------------------------------------------------------------------
    -- Encoder Simulators (3 axes)
    -------------------------------------------------------------------------
    u_encoder_sim_x : entity work.encoder_simulator
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            DELAY_US    => 10
        )
        port map (
            clk       => clk,
            rst       => rst,
            step_in   => step_x_int,
            dir_in    => dir_x_int,
            enable_in => enable_x_int,
            enc_a_out => sim_enc_a_x,
            enc_b_out => sim_enc_b_x
        );

    u_encoder_sim_y : entity work.encoder_simulator
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            DELAY_US    => 10
        )
        port map (
            clk       => clk,
            rst       => rst,
            step_in   => step_y_int,
            dir_in    => dir_y_int,
            enable_in => enable_y_int,
            enc_a_out => sim_enc_a_y,
            enc_b_out => sim_enc_b_y
        );

    u_encoder_sim_z : entity work.encoder_simulator
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            DELAY_US    => 10
        )
        port map (
            clk       => clk,
            rst       => rst,
            step_in   => step_z_int,
            dir_in    => dir_z_int,
            enable_in => enable_z_int,
            enc_a_out => sim_enc_a_z,
            enc_b_out => sim_enc_b_z
        );

    -------------------------------------------------------------------------
    -- CNC 3-Axis Controller (existing design, no modifications)
    -------------------------------------------------------------------------
    u_cnc_controller : entity work.cnc_3axis_controller
        port map (
            clk            => clk,
            rst            => rst,

            -- Control
            move_start     => move_start,
            move_abort     => move_abort,
            enable         => enable,

            -- Target positions (from ROM controller)
            target_x       => target_x,
            target_y       => target_y,
            target_z       => target_z,
            step_period_in => step_period,

            -- Encoder inputs (muxed: simulated or external)
            enc_x_a        => enc_a_x_mux,
            enc_x_b        => enc_b_x_mux,
            enc_y_a        => enc_a_y_mux,
            enc_y_b        => enc_b_y_mux,
            enc_z_a        => enc_a_z_mux,
            enc_z_b        => enc_b_z_mux,

            -- Limit switches (note: different naming convention)
            limit_x_min    => limit_min_x,
            limit_x_max    => limit_max_x,
            limit_y_min    => limit_min_y,
            limit_y_max    => limit_max_y,
            limit_z_min    => limit_min_z,
            limit_z_max    => limit_max_z,

            -- Motor outputs (buffered signals)
            step_x         => step_x_int,
            dir_x          => dir_x_int,
            enable_x       => enable_x_int,
            step_y         => step_y_int,
            dir_y          => dir_y_int,
            enable_y       => enable_y_int,
            step_z         => step_z_int,
            dir_z          => dir_z_int,
            enable_z       => enable_z_int,

            -- Position feedback (internal, not exposed)
            pos_x          => pos_x,
            pos_y          => pos_y,
            pos_z          => pos_z,

            -- Status
            busy           => busy_int,
            fault          => fault,
            state_debug    => state_debug
        );

end structural;
