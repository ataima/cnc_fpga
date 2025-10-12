-- ============================================================================
-- CNC 3-Axis Controller - Package Definitions
-- ============================================================================
-- Definizioni comuni per tutto il progetto CNC
-- Target: Cyclone IV EP4CE6E22C8N
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package cnc_pkg is

    -- Configurazione sistema
    constant CLK_FREQ_HZ      : integer := 50_000_000;  -- 50 MHz clock
    constant POSITION_WIDTH   : integer := 32;          -- Bit per posizione assi
    constant VELOCITY_WIDTH   : integer := 16;          -- Bit per velocità

    -- Configurazione encoder
    constant ENCODER_PPR      : integer := 600;         -- Pulses Per Revolution
    constant ENCODER_FILTER   : integer := 4;           -- Debounce filter stages

    -- Configurazione step generator
    constant MIN_STEP_PERIOD  : integer := 100;         -- Min periodo step (clock cycles)
    constant MAX_STEP_PERIOD  : integer := 65535;       -- Max periodo step

    -- Tipi personalizzati
    subtype step_period_t is unsigned(15 downto 0);

    type axis_position_t is record
        x : signed(POSITION_WIDTH-1 downto 0);
        y : signed(POSITION_WIDTH-1 downto 0);
        z : signed(POSITION_WIDTH-1 downto 0);
    end record;

    type axis_velocity_t is record
        x : unsigned(VELOCITY_WIDTH-1 downto 0);
        y : unsigned(VELOCITY_WIDTH-1 downto 0);
        z : unsigned(VELOCITY_WIDTH-1 downto 0);
    end record;

    type limit_switches_t is record
        x_min : std_logic;
        x_max : std_logic;
        y_min : std_logic;
        y_max : std_logic;
        z_min : std_logic;
        z_max : std_logic;
    end record;

    -- Funzioni utility
    function sign_extend(value : signed; new_width : integer) return signed;
    function clamp(value : signed; min_val : signed; max_val : signed) return signed;
    function clamp_unsigned(value : unsigned; min_val : integer; max_val : integer) return step_period_t;

end package cnc_pkg;

package body cnc_pkg is

    function sign_extend(value : signed; new_width : integer) return signed is
        variable result : signed(new_width-1 downto 0);
    begin
        if new_width < value'length then
            assert false report "sign_extend: Truncation from " & integer'image(value'length) & " to " & integer'image(new_width) severity warning;
        end if;
        result := resize(value, new_width);
        return result;
    end function;

    function clamp(value : signed; min_val : signed; max_val : signed) return signed is
        variable clamped_min : signed(min_val'range);
        variable clamped_max : signed(max_val'range);
    begin
        -- Assicura min <= max
        if min_val > max_val then
            clamped_min := max_val;
            clamped_max := min_val;
        else
            clamped_min := min_val;
            clamped_max := max_val;
        end if;

        if value < clamped_min then
            return clamped_min;
        elsif value > clamped_max then
            return clamped_max;
        else
            return value;
        end if;
    end function;

    function clamp_unsigned(value : unsigned; min_val : integer; max_val : integer) return step_period_t is
        variable clamped : step_period_t;
        variable min_u : unsigned(15 downto 0) := to_unsigned(min_val, 16);
        variable max_u : unsigned(15 downto 0) := to_unsigned(max_val, 16);
    begin
        -- Assicura min <= max
        if to_integer(min_u) > to_integer(max_u) then
            clamped := max_u;
        else
            clamped := min_u;
        end if;

        if value < clamped then
            return clamped;
        elsif value > max_u then
            return max_u;
        else
            return step_period_t(value);
        end if;
    end function;

end package body cnc_pkg;
