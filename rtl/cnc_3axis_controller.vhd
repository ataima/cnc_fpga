-- ============================================================================
-- CNC 3-Axis Controller - Top Level Entity
-- ============================================================================
-- Integra 3 assi completi (X, Y, Z) con:
-- - Encoder decoder per feedback posizione
-- - Bresenham interpolazione lineare
-- - STEP/DIR generator per driver esterni
-- - Limit switch con safety logic
-- - Interfaccia di controllo semplificata
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity cnc_3axis_controller is
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
        -- CONTROL INTERFACE (da ESP32 o NIOS II)
        -- ====================================================================
        -- Comando movimento
        move_start    : in  std_logic;
        move_abort    : in  std_logic;

        -- Target posizione (relativa)
        target_x      : in  signed(POSITION_WIDTH-1 downto 0);
        target_y      : in  signed(POSITION_WIDTH-1 downto 0);
        target_z      : in  signed(POSITION_WIDTH-1 downto 0);

        -- Parametri movimento
        step_period_in : in  unsigned(15 downto 0);  -- Clock cycles between steps (pre-calculated)

        -- Enable assi
        enable        : in  std_logic;

        -- ====================================================================
        -- STATUS OUTPUT
        -- ====================================================================
        -- Posizione corrente (da encoder)
        pos_x         : out signed(POSITION_WIDTH-1 downto 0);
        pos_y         : out signed(POSITION_WIDTH-1 downto 0);
        pos_z         : out signed(POSITION_WIDTH-1 downto 0);

        -- Status
        busy          : out std_logic;
        fault         : out std_logic;  -- Errore (limit hit, encoder err)

        -- Debug
        state_debug   : out std_logic_vector(3 downto 0)
        

    );
end cnc_3axis_controller;

architecture rtl of cnc_3axis_controller is

    -- ========================================================================
    -- Component declarations
    -- ========================================================================
    component encoder_decoder is
        generic (
            FILTER_STAGES : integer := 4;
            VEL_WINDOW    : integer := 1000
        );
        port (
            clk          : in  std_logic;
            rst          : in  std_logic;
            enc_a        : in  std_logic;
            enc_b        : in  std_logic;
            enable       : in  std_logic;
            position_set : in  std_logic;
            position_val : in  signed(POSITION_WIDTH-1 downto 0);
            position     : out signed(POSITION_WIDTH-1 downto 0);
            velocity     : out signed(VELOCITY_WIDTH-1 downto 0);
            direction    : out std_logic;
            error        : out std_logic
        );
    end component;

    component bresenham_axis is
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            start         : in  std_logic;
            abort         : in  std_logic;
            delta_major   : in  unsigned(POSITION_WIDTH-1 downto 0);
            delta_minor   : in  unsigned(POSITION_WIDTH-1 downto 0);
            is_major_axis : in  std_logic;
            step_period   : in  unsigned(15 downto 0);
            direction     : in  std_logic;
            encoder_pos   : in  signed(POSITION_WIDTH-1 downto 0);
            step_req      : out std_logic;
            busy          : out std_logic;
            position      : out signed(POSITION_WIDTH-1 downto 0);
            steps_done    : out unsigned(POSITION_WIDTH-1 downto 0)
        );
    end component;

    component step_dir_generator is
        generic (
            CLK_FREQ_HZ   : integer := 50_000_000;
            STEP_WIDTH_US : integer := 5;
            DIR_SETUP_US  : integer := 1
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            step_req   : in  std_logic;
            direction  : in  std_logic;
            enable_in  : in  std_logic;
            limit_min  : in  std_logic;
            limit_max  : in  std_logic;
            step_out   : out std_logic;
            dir_out    : out std_logic;
            enable_out : out std_logic;
            fault      : out std_logic
        );
    end component;

    -- ========================================================================
    -- Segnali interni
    -- ========================================================================

    -- Encoder feedback
    signal enc_pos_x, enc_pos_y, enc_pos_z : signed(POSITION_WIDTH-1 downto 0);
    signal enc_vel_x, enc_vel_y, enc_vel_z : signed(VELOCITY_WIDTH-1 downto 0);
    signal enc_err_x, enc_err_y, enc_err_z : std_logic;

    -- Bresenham
    signal bresen_x_req, bresen_y_req, bresen_z_req : std_logic;
    signal bresen_x_busy, bresen_y_busy, bresen_z_busy : std_logic;
    signal bresen_dir_x, bresen_dir_y, bresen_dir_z : std_logic;

    -- Calcolo delta e major axis
    signal delta_x, delta_y, delta_z : unsigned(POSITION_WIDTH-1 downto 0);
    signal delta_max : unsigned(POSITION_WIDTH-1 downto 0);
    signal step_period : unsigned(15 downto 0);
    signal is_major_x, is_major_y, is_major_z : std_logic;

    -- Step generator fault
    signal fault_x, fault_y, fault_z : std_logic;

    -- Controller state
    type ctrl_state_t is (IDLE, CALC_PARAMS, START_MOVEMENT, MOVING, DONE);
    signal ctrl_state : ctrl_state_t;
    signal start_sig : std_logic;


begin

    -- ========================================================================
    -- ENCODER DECODERS (3 assi)
    -- ========================================================================

    enc_x : encoder_decoder
        generic map (
            FILTER_STAGES => 4,
            VEL_WINDOW => 1000
        )
        port map (
            clk => clk,
            rst => rst,
            enc_a => enc_x_a,
            enc_b => enc_x_b,
            enable => enable,
            position_set => '0',
            position_val => (others => '0'),
            position => enc_pos_x,
            velocity => enc_vel_x,
            direction => open,
            error => enc_err_x
        );

    enc_y : encoder_decoder
        generic map (
            FILTER_STAGES => 4,
            VEL_WINDOW => 1000
        )
        port map (
            clk => clk,
            rst => rst,
            enc_a => enc_y_a,
            enc_b => enc_y_b,
            enable => enable,
            position_set => '0',
            position_val => (others => '0'),
            position => enc_pos_y,
            velocity => enc_vel_y,
            direction => open,
            error => enc_err_y
        );

    enc_z : encoder_decoder
        generic map (
            FILTER_STAGES => 4,
            VEL_WINDOW => 1000
        )
        port map (
            clk => clk,
            rst => rst,
            enc_a => enc_z_a,
            enc_b => enc_z_b,
            enable => enable,
            position_set => '0',
            position_val => (others => '0'),
            position => enc_pos_z,
            velocity => enc_vel_z,
            direction => open,
            error => enc_err_z
        );

    -- ========================================================================
    -- MOTION CONTROLLER - Calcolo parametri Bresenham
    -- ========================================================================
    process(clk, rst)
        variable temp_delta_x, temp_delta_y, temp_delta_z : unsigned(POSITION_WIDTH-1 downto 0);
    begin
        if rst = '1' then
            ctrl_state <= IDLE;
            delta_x <= (others => '0');
            delta_y <= (others => '0');
            delta_z <= (others => '0');
            delta_max <= (others => '0');
            is_major_x <= '0';
            is_major_y <= '0';
            is_major_z <= '0';
            bresen_dir_x <= '0';
            bresen_dir_y <= '0';
            bresen_dir_z <= '0';
            step_period <= to_unsigned(1000, 16);

        elsif rising_edge(clk) then

            case ctrl_state is

                when IDLE =>
                    if move_start = '1' then
                        ctrl_state <= CALC_PARAMS;
                    end if;

                when CALC_PARAMS =>
                    -- Calcola delta assoluti e direzioni (usando variabili temporanee)
                    -- IMPORTANTE: abs() per signed → unsigned corretto
                    if target_x >= 0 then
                        temp_delta_x := unsigned(target_x);
                        bresen_dir_x <= '1';
                    else
                        temp_delta_x := unsigned(abs(target_x));
                        bresen_dir_x <= '0';
                    end if;

                    if target_y >= 0 then
                        temp_delta_y := unsigned(target_y);
                        bresen_dir_y <= '1';
                    else
                        temp_delta_y := unsigned(abs(target_y));
                        bresen_dir_y <= '0';
                    end if;

                    if target_z >= 0 then
                        temp_delta_z := unsigned(target_z);
                        bresen_dir_z <= '1';
                    else
                        temp_delta_z := unsigned(abs(target_z));
                        bresen_dir_z <= '0';
                    end if;

                    -- Determina asse principale (major axis) usando le variabili temporanee
                    -- Major = quello con delta maggiore
                    if temp_delta_x >= temp_delta_y and temp_delta_x >= temp_delta_z then
                        delta_max <= temp_delta_x;
                        is_major_x <= '1';
                        is_major_y <= '0';
                        is_major_z <= '0';
                    elsif temp_delta_y >= temp_delta_x and temp_delta_y >= temp_delta_z then
                        delta_max <= temp_delta_y;
                        is_major_x <= '0';
                        is_major_y <= '1';
                        is_major_z <= '0';
                    else
                        delta_max <= temp_delta_z;
                        is_major_x <= '0';
                        is_major_y <= '0';
                        is_major_z <= '1';
                    end if;

                    -- Assegna i delta ai segnali persistenti
                    delta_x <= temp_delta_x;
                    delta_y <= temp_delta_y;
                    delta_z <= temp_delta_z;

                    -- Use pre-calculated step period from external controller
                    -- This avoids expensive hardware division
                    -- External controller calculates: step_period = CLK_FREQ_HZ / feedrate
                    if step_period_in > 0 then
                        step_period <= step_period_in;
                    else
                        step_period <= to_unsigned(1000, 16);  -- Safe default (50 kHz)
                    end if;

                    ctrl_state <= START_MOVEMENT;

                when START_MOVEMENT =>
                    -- Wait one cycle for bresenham cores to see start signal
                    ctrl_state <= MOVING;

                when MOVING =>
                    if move_abort = '1' then
                        ctrl_state <= DONE;
                    elsif bresen_x_busy = '0' and bresen_y_busy = '0' and bresen_z_busy = '0' then
                        ctrl_state <= DONE;
                    end if;

                when DONE =>
                    if move_start = '0' then
                        ctrl_state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- ========================================================================
    -- BRESENHAM CORES (3 assi)
    -- ========================================================================

    start_sig <= '1' when (ctrl_state = START_MOVEMENT or ctrl_state = MOVING) else '0';

    bresen_x : bresenham_axis
        port map (
            clk => clk,
            rst => rst,
            start => start_sig,
            abort => move_abort,
            delta_major => delta_max,
            delta_minor => delta_x,
            is_major_axis => is_major_x,
            step_period => step_period,
            direction => bresen_dir_x,
            encoder_pos => enc_pos_x,
            step_req => bresen_x_req,
            busy => bresen_x_busy,
            position => open,
            steps_done => open
        );

    bresen_y : bresenham_axis
        port map (
            clk => clk,
            rst => rst,
            start => start_sig,
            abort => move_abort,
            delta_major => delta_max,
            delta_minor => delta_y,
            is_major_axis => is_major_y,
            step_period => step_period,
            direction => bresen_dir_y,
            encoder_pos => enc_pos_y,
            step_req => bresen_y_req,
            busy => bresen_y_busy,
            position => open,
            steps_done => open
        );

    bresen_z : bresenham_axis
        port map (
            clk => clk,
            rst => rst,
            start => start_sig,
            abort => move_abort,
            delta_major => delta_max,
            delta_minor => delta_z,
            is_major_axis => is_major_z,
            step_period => step_period,
            direction => bresen_dir_z,
            encoder_pos => enc_pos_z,
            step_req => bresen_z_req,
            busy => bresen_z_busy,
            position => open,
            steps_done => open
        );

    -- ========================================================================
    -- STEP/DIR GENERATORS (3 assi)
    -- ========================================================================

    stepgen_x : step_dir_generator
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            STEP_WIDTH_US => 5,
            DIR_SETUP_US => 1
        )
        port map (
            clk => clk,
            rst => rst,
            step_req => bresen_x_req,
            direction => bresen_dir_x,
            enable_in => enable,
            limit_min => limit_x_min,
            limit_max => limit_x_max,
            step_out => step_x,
            dir_out => dir_x,
            enable_out => enable_x,
            fault => fault_x
        );

    stepgen_y : step_dir_generator
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            STEP_WIDTH_US => 5,
            DIR_SETUP_US => 1
        )
        port map (
            clk => clk,
            rst => rst,
            step_req => bresen_y_req,
            direction => bresen_dir_y,
            enable_in => enable,
            limit_min => limit_y_min,
            limit_max => limit_y_max,
            step_out => step_y,
            dir_out => dir_y,
            enable_out => enable_y,
            fault => fault_y
        );

    stepgen_z : step_dir_generator
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            STEP_WIDTH_US => 5,
            DIR_SETUP_US => 1
        )
        port map (
            clk => clk,
            rst => rst,
            step_req => bresen_z_req,
            direction => bresen_dir_z,
            enable_in => enable,
            limit_min => limit_z_min,
            limit_max => limit_z_max,
            step_out => step_z,
            dir_out => dir_z,
            enable_out => enable_z,
            fault => fault_z
        );

    -- ========================================================================
    -- OUTPUT MAPPING
    -- ========================================================================
    pos_x <= enc_pos_x;
    pos_y <= enc_pos_y;
    pos_z <= enc_pos_z;

    busy <= bresen_x_busy or bresen_y_busy or bresen_z_busy;

    fault <= fault_x or fault_y or fault_z or
             enc_err_x or enc_err_y or enc_err_z;

    -- Debug state
    state_debug <= "0001" when ctrl_state = IDLE else
                   "0010" when ctrl_state = CALC_PARAMS else
                   "0011" when ctrl_state = START_MOVEMENT else
                   "0100" when ctrl_state = MOVING else
                   "1000";

end rtl;
