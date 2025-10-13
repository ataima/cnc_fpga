-- ============================================================================
-- CNC 3-Axis Controller - Synthesis-Only Top Level
-- ============================================================================
-- Versione ridotta per sintesi senza i bus dati (target/pos)
-- I parametri sono hardcoded per verificare la sintesi del core
-- Per l'uso reale serve interfaccia SPI/UART
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity cnc_3axis_controller_synth is
    port (
        -- Clock e reset
        clk           : in  std_logic;  -- 50 MHz
        rst           : in  std_logic;  -- Reset asincrono attivo alto

        -- ====================================================================
        -- ENCODER INPUT (3 assi)
        -- ====================================================================
        enc_x_a       : in  std_logic;
        enc_x_b       : in  std_logic;
        enc_y_a       : in  std_logic;
        enc_y_b       : in  std_logic;
        enc_z_a       : in  std_logic;
        enc_z_b       : in  std_logic;

        -- ====================================================================
        -- LIMIT SWITCHES (3 assi, min/max)
        -- ====================================================================
        limit_x_min   : in  std_logic;
        limit_x_max   : in  std_logic;
        limit_y_min   : in  std_logic;
        limit_y_max   : in  std_logic;
        limit_z_min   : in  std_logic;
        limit_z_max   : in  std_logic;

        -- ====================================================================
        -- STEP/DIR OUTPUT (3 assi)
        -- ====================================================================
        step_x        : out std_logic;
        dir_x         : out std_logic;
        enable_x      : out std_logic;

        step_y        : out std_logic;
        dir_y         : out std_logic;
        enable_y      : out std_logic;

        step_z        : out std_logic;
        dir_z         : out std_logic;
        enable_z      : out std_logic;

        -- ====================================================================
        -- CONTROL INTERFACE (ridotto)
        -- ====================================================================
        move_start    : in  std_logic;
        move_abort    : in  std_logic;
        enable        : in  std_logic;

        -- ====================================================================
        -- STATUS OUTPUT (ridotto)
        -- ====================================================================
        busy          : out std_logic;
        fault         : out std_logic;
        state_debug   : out std_logic_vector(3 downto 0)
    );
end cnc_3axis_controller_synth;

architecture rtl of cnc_3axis_controller_synth is

    -- Istanza del controller completo
    component cnc_3axis_controller is
        port (
            clk            : in  std_logic;
            rst            : in  std_logic;
            enc_x_a        : in  std_logic;
            enc_x_b        : in  std_logic;
            enc_y_a        : in  std_logic;
            enc_y_b        : in  std_logic;
            enc_z_a        : in  std_logic;
            enc_z_b        : in  std_logic;
            limit_x_min    : in  std_logic;
            limit_x_max    : in  std_logic;
            limit_y_min    : in  std_logic;
            limit_y_max    : in  std_logic;
            limit_z_min    : in  std_logic;
            limit_z_max    : in  std_logic;
            step_x         : out std_logic;
            dir_x          : out std_logic;
            enable_x       : out std_logic;
            step_y         : out std_logic;
            dir_y          : out std_logic;
            enable_y       : out std_logic;
            step_z         : out std_logic;
            dir_z          : out std_logic;
            enable_z       : out std_logic;
            move_start     : in  std_logic;
            move_abort     : in  std_logic;
            target_x       : in  signed(POSITION_WIDTH-1 downto 0);
            target_y       : in  signed(POSITION_WIDTH-1 downto 0);
            target_z       : in  signed(POSITION_WIDTH-1 downto 0);
            step_period_in : in  unsigned(15 downto 0);
            enable         : in  std_logic;
            pos_x          : out signed(POSITION_WIDTH-1 downto 0);
            pos_y          : out signed(POSITION_WIDTH-1 downto 0);
            pos_z          : out signed(POSITION_WIDTH-1 downto 0);
            busy           : out std_logic;
            fault          : out std_logic;
            state_debug    : out std_logic_vector(3 downto 0)
        );
    end component;

    -- Parametri hardcoded per test sintesi
    -- In un sistema reale questi verrebbero da SPI/UART
    constant TARGET_X_TEST : signed(POSITION_WIDTH-1 downto 0) := to_signed(1000, POSITION_WIDTH);
    constant TARGET_Y_TEST : signed(POSITION_WIDTH-1 downto 0) := to_signed(500, POSITION_WIDTH);
    constant TARGET_Z_TEST : signed(POSITION_WIDTH-1 downto 0) := to_signed(0, POSITION_WIDTH);
    constant STEP_PERIOD_TEST : unsigned(15 downto 0) := to_unsigned(5000, 16);  -- 10k steps/sec @ 50MHz

    -- Output non usati (interni)
    signal pos_x_internal : signed(POSITION_WIDTH-1 downto 0);
    signal pos_y_internal : signed(POSITION_WIDTH-1 downto 0);
    signal pos_z_internal : signed(POSITION_WIDTH-1 downto 0);

begin

    -- ========================================================================
    -- Istanza del controller completo con parametri fissi
    -- ========================================================================
    controller_inst : cnc_3axis_controller
        port map (
            clk            => clk,
            rst            => rst,

            -- Encoder
            enc_x_a        => enc_x_a,
            enc_x_b        => enc_x_b,
            enc_y_a        => enc_y_a,
            enc_y_b        => enc_y_b,
            enc_z_a        => enc_z_a,
            enc_z_b        => enc_z_b,

            -- Limit switches
            limit_x_min    => limit_x_min,
            limit_x_max    => limit_x_max,
            limit_y_min    => limit_y_min,
            limit_y_max    => limit_y_max,
            limit_z_min    => limit_z_min,
            limit_z_max    => limit_z_max,

            -- Step/Dir output
            step_x         => step_x,
            dir_x          => dir_x,
            enable_x       => enable_x,
            step_y         => step_y,
            dir_y          => dir_y,
            enable_y       => enable_y,
            step_z         => step_z,
            dir_z          => dir_z,
            enable_z       => enable_z,

            -- Control (da pin esterni)
            move_start     => move_start,
            move_abort     => move_abort,
            enable         => enable,

            -- Target hardcoded (in futuro da SPI/UART)
            target_x       => TARGET_X_TEST,
            target_y       => TARGET_Y_TEST,
            target_z       => TARGET_Z_TEST,
            step_period_in => STEP_PERIOD_TEST,

            -- Position output (interno, non esposto)
            pos_x          => pos_x_internal,
            pos_y          => pos_y_internal,
            pos_z          => pos_z_internal,

            -- Status
            busy           => busy,
            fault          => fault,
            state_debug    => state_debug
        );

    -- Note: pos_x/y/z_internal non sono esposti su pin esterni
    -- In un sistema reale verrebbero letti via SPI/UART

end rtl;
