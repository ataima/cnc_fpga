-- ============================================================================
-- Bresenham Line Drawing Algorithm - Single Axis Core
-- ============================================================================
-- Implementa algoritmo di Bresenham per interpolazione lineare
-- - Gestione movimento principale e secondario
-- - Generazione step con timing preciso
-- - Supporto accelerazione/decelerazione
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity bresenham_axis is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;

        -- Comando movimento
        start         : in  std_logic;
        abort         : in  std_logic;

        -- Parametri movimento
        delta_major   : in  unsigned(POSITION_WIDTH-1 downto 0);  -- Asse principale
        delta_minor   : in  unsigned(POSITION_WIDTH-1 downto 0);  -- Questo asse
        is_major_axis : in  std_logic;                            -- '1' se questo è major
        step_period   : in  unsigned(15 downto 0);                -- Periodo tra step (clock cycles)

        -- Direzione
        direction     : in  std_logic;  -- '1' = positiva, '0' = negativa

        -- Feedback encoder (opzionale per closed-loop)
        encoder_pos   : in  signed(POSITION_WIDTH-1 downto 0);

        -- Output
        step_req      : out std_logic;  -- Richiesta step
        busy          : out std_logic;
        position      : out signed(POSITION_WIDTH-1 downto 0);
        steps_done    : out unsigned(POSITION_WIDTH-1 downto 0)
    );
end bresenham_axis;

architecture rtl of bresenham_axis is

    constant ERROR_BITS : integer := POSITION_WIDTH + 2;  -- 34 bit per POSITION_WIDTH=32

    type state_t is (IDLE, RUNNING, DONE);
    signal state : state_t;

    -- Algoritmo Bresenham (scaling per 2*dy, 2*dx)
    signal error_accum : signed(ERROR_BITS-1 downto 0);

    -- Contatori
    signal step_counter   : unsigned(POSITION_WIDTH-1 downto 0);  -- Conta major steps
    signal minor_steps    : unsigned(POSITION_WIDTH-1 downto 0);  -- Conta minor steps
    signal total_steps    : unsigned(POSITION_WIDTH-1 downto 0);

    -- Timer per generazione step
    signal step_timer     : unsigned(15 downto 0);
    signal step_pulse     : std_logic;

    -- Posizione calcolata
    signal pos_internal   : signed(POSITION_WIDTH-1 downto 0);

    -- Edge detect per start
    signal start_prev     : std_logic := '0';

begin

    -- ========================================================================
    -- State Machine principale
    -- ========================================================================
    process(clk, rst)
        variable delta_major_s, delta_minor_s : signed(POSITION_WIDTH downto 0);
        variable error_init : signed(ERROR_BITS-1 downto 0);
        variable two_delta_minor, two_delta_major : signed(ERROR_BITS-1 downto 0);
        variable new_error : signed(ERROR_BITS-1 downto 0);
        variable adjusted_error : signed(ERROR_BITS-1 downto 0);
    begin
        if rst = '1' then
            state <= IDLE;
            error_accum <= (others => '0');
            step_counter <= (others => '0');
            minor_steps <= (others => '0');
            total_steps <= (others => '0');
            step_timer <= (others => '0');
            step_pulse <= '0';
            pos_internal <= (others => '0');
            start_prev <= '0';

        elsif rising_edge(clk) then

            start_prev <= start;  -- Edge detect
            step_pulse <= '0';    -- Default: no step

            case state is

                -- ============================================================
                -- IDLE: Attesa comando start
                -- ============================================================
                when IDLE =>
                    if start = '1' and start_prev = '0' then  -- Rising edge
                        state <= RUNNING;
                        step_counter <= (others => '0');
                        minor_steps <= (others => '0');
                        step_timer <= (others => '0');

                        -- Inizializza total_steps
                        total_steps <= delta_major;  -- Sempre delta_major (per sync)

                        -- Calcola init error = 2*dy - dx - 1 per evitare step extra
                        delta_major_s := signed('0' & delta_major);
                        delta_minor_s := signed('0' & delta_minor);
                        error_init := resize((delta_minor_s sll 1) - delta_major_s - 1, ERROR_BITS);
                        error_accum <= error_init;

                        -- Per major axis, error non usato
                    end if;

                -- ============================================================
                -- RUNNING: Esecuzione movimento
                -- ============================================================
                when RUNNING =>

                    if abort = '1' then
                        -- Abort immediato: reset contatori
                        state <= DONE;
                        step_counter <= (others => '0');
                        minor_steps <= (others => '0');
                        step_timer <= (others => '0');

                    elsif step_counter < delta_major and step_period > 0 then

                        -- Timer per rate limiting (major ticks)
                        -- Nota: conta da 0 a (step_period-1) per avere esattamente step_period cicli
                        if step_timer < (step_period - 1) then
                            step_timer <= step_timer + 1;
                        else
                            step_timer <= (others => '0');

                            -- Incrementa contatore major
                            step_counter <= step_counter + 1;

                            if is_major_axis = '1' then
                                -- Asse principale: step SEMPRE
                                step_pulse <= '1';

                                -- Aggiorna posizione
                                if direction = '1' then
                                    pos_internal <= pos_internal + 1;
                                else
                                    pos_internal <= pos_internal - 1;
                                end if;

                                -- Nota: step_counter già incrementato sopra (linea 142)
                                -- minor_steps NON viene usato per major axis

                            else
                                -- Asse secondario: Bresenham decision
                                -- Aggiorna error: error += 2*dy
                                two_delta_minor := resize(signed('0' & delta_minor), ERROR_BITS) sll 1;
                                new_error := error_accum + two_delta_minor;
                                error_accum <= new_error;

                                -- Check: if error > 0 then step, error -= 2*dx
                                if new_error > 0 then
                                    step_pulse <= '1';

                                    -- Sottrai 2*dx
                                    two_delta_major := resize(signed('0' & delta_major), ERROR_BITS) sll 1;
                                    adjusted_error := new_error - two_delta_major;
                                    error_accum <= adjusted_error;

                                    -- Aggiorna posizione
                                    if direction = '1' then
                                        pos_internal <= pos_internal + 1;
                                    else
                                        pos_internal <= pos_internal - 1;
                                    end if;

                                    -- Conta step per minor axis
                                    minor_steps <= minor_steps + 1;
                                end if;
                            end if;
                        end if;

                    else
                        -- Movimento completato
                        state <= DONE;
                    end if;

                -- ============================================================
                -- DONE: Movimento terminato
                -- ============================================================
                when DONE =>
                    if start = '0' then
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- ========================================================================
    -- Output
    -- ========================================================================
    step_req <= step_pulse;
    busy <= '1' when state = RUNNING else '0';
    position <= pos_internal;
    steps_done <= minor_steps when is_major_axis = '0' else step_counter;

end rtl;


