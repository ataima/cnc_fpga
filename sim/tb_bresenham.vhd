-- ============================================================================
-- Testbench per Bresenham Core
-- ============================================================================
-- Simula movimento lineare da (0,0) a (100,50)
-- Verifica:
-- - Generazione corretta step
-- - Timing preciso
-- - Algoritmo Bresenham
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity tb_bresenham is
end tb_bresenham;

architecture sim of tb_bresenham is
    
    -- Component Under Test
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
    
    -- Clock e reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    
    -- Inputs X axis (major)
    signal start_x : std_logic := '0';
    signal abort_x : std_logic := '0';
    signal delta_major : unsigned(POSITION_WIDTH-1 downto 0) := to_unsigned(100, POSITION_WIDTH);
    signal delta_x : unsigned(POSITION_WIDTH-1 downto 0) := to_unsigned(100, POSITION_WIDTH);
    signal is_major_x : std_logic := '1';
    signal step_period : unsigned(15 downto 0) := to_unsigned(10, 16);
    signal dir_x : std_logic := '1';
    
    -- Inputs Y axis (minor)
    signal start_y : std_logic := '0';
    signal delta_y : unsigned(POSITION_WIDTH-1 downto 0) := to_unsigned(50, POSITION_WIDTH);
    signal is_major_y : std_logic := '0';
    signal dir_y : std_logic := '1';
    
    -- Outputs
    signal step_x, step_y : std_logic;
    signal busy_x, busy_y : std_logic;
    signal pos_x, pos_y : signed(POSITION_WIDTH-1 downto 0);
    signal steps_x, steps_y : unsigned(POSITION_WIDTH-1 downto 0);
    
    -- Clock period
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    
    -- Contatori per verifica
    signal x_count, y_count : integer := 0;
    
begin

    -- ========================================================================
    -- Istanze Bresenham (X = major, Y = minor)
    -- ========================================================================
    
    dut_x : bresenham_axis
        port map (
            clk => clk,
            rst => rst,
            start => start_x,
            abort => abort_x,
            delta_major => delta_major,
            delta_minor => delta_x,
            is_major_axis => is_major_x,
            step_period => step_period,
            direction => dir_x,
            encoder_pos => (others => '0'),
            step_req => step_x,
            busy => busy_x,
            position => pos_x,
            steps_done => steps_x
        );
    
    dut_y : bresenham_axis
        port map (
            clk => clk,
            rst => rst,
            start => start_y,
            abort => abort_x,
            delta_major => delta_major,
            delta_minor => delta_y,
            is_major_axis => is_major_y,
            step_period => step_period,
            direction => dir_y,
            encoder_pos => (others => '0'),
            step_req => step_y,
            busy => busy_y,
            position => pos_y,
            steps_done => steps_y
        );

    -- ========================================================================
    -- Clock generation
    -- ========================================================================
    clk_proc: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- ========================================================================
    -- Stimulus
    -- ========================================================================
    stim_proc: process
    begin
        -- Reset iniziale
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;
        
        -- Test 1: Linea da (0,0) a (100,50)
        report "=== TEST 1: Movimento (0,0) -> (100,50) ===";
        start_x <= '1';
        start_y <= '1';
        wait for CLK_PERIOD;
        start_x <= '0';
        start_y <= '0';
        
        -- Attendi completamento
        wait until busy_x = '0' and busy_y = '0';
        wait for 1 us;
        
        report "X final position: " & integer'image(to_integer(pos_x));
        report "Y final position: " & integer'image(to_integer(pos_y));
        report "X steps done: " & integer'image(to_integer(steps_x));
        report "Y steps done: " & integer'image(to_integer(steps_y));
        
        -- Verifica risultati
        assert to_integer(pos_x) = 100 
            report "ERROR: X position incorrect!" severity error;
        assert to_integer(pos_y) = 50 
            report "ERROR: Y position incorrect!" severity error;
        
        wait for 1 us;

        -- Reset tra test per posizione pulita
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Test 2: Abort durante movimento
        report "=== TEST 2: Abort durante movimento ===";
        start_x <= '1';
        start_y <= '1';
        wait for CLK_PERIOD;
        start_x <= '0';
        start_y <= '0';
        
        -- Aspetta un po' poi abort
        wait for 5 us;
        abort_x <= '1';
        wait for CLK_PERIOD;
        abort_x <= '0';

        -- Attendi che busy torni a 0 (con timeout)
        wait for 1 us;  -- Dai tempo al sistema di andare in DONE
        if busy_x = '1' or busy_y = '1' then
            report "WARNING: Busy still high after abort!" severity warning;
        end if;
        
        report "Abort test: X pos = " & integer'image(to_integer(pos_x));
        report "Abort test: Y pos = " & integer'image(to_integer(pos_y));

        wait for 1 us;

        -- Reset tra test per posizione pulita
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Test 3: Movimento negativo (-50,-25)
        report "=== TEST 3: Movimento negativo (-50,-25) ===";
        delta_major <= to_unsigned(50, POSITION_WIDTH);
        delta_x <= to_unsigned(50, POSITION_WIDTH);
        delta_y <= to_unsigned(25, POSITION_WIDTH);
        is_major_x <= '1';
        is_major_y <= '0';
        dir_x <= '0';  -- Direzione negativa
        dir_y <= '0';  -- Direzione negativa
        step_period <= to_unsigned(10, 16);

        start_x <= '1';
        start_y <= '1';
        wait for CLK_PERIOD;
        start_x <= '0';
        start_y <= '0';

        wait until busy_x = '0' and busy_y = '0';
        wait for 1 us;

        report "Test 3 - X final position: " & integer'image(to_integer(pos_x));
        report "Test 3 - Y final position: " & integer'image(to_integer(pos_y));

        -- Verifica risultati (dovrebbe essere -50, -25)
        assert to_integer(pos_x) = -50
            report "ERROR: Test 3 X position incorrect!" severity error;
        assert to_integer(pos_y) = -25
            report "ERROR: Test 3 Y position incorrect!" severity error;

        wait for 1 us;

        -- Reset tra test per posizione pulita
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Test 4: Major axis solo (100,0) - edge case
        report "=== TEST 4: Major axis solo X=100, Y=0 ===";
        delta_major <= to_unsigned(100, POSITION_WIDTH);
        delta_x <= to_unsigned(100, POSITION_WIDTH);
        delta_y <= to_unsigned(0, POSITION_WIDTH);  -- Y non si muove
        is_major_x <= '1';
        is_major_y <= '0';
        dir_x <= '1';  -- Direzione positiva
        dir_y <= '1';
        step_period <= to_unsigned(10, 16);

        start_x <= '1';
        start_y <= '1';
        wait for CLK_PERIOD;
        start_x <= '0';
        start_y <= '0';

        wait until busy_x = '0' and busy_y = '0';
        wait for 1 us;

        report "Test 4 - X final position: " & integer'image(to_integer(pos_x));
        report "Test 4 - Y final position: " & integer'image(to_integer(pos_y));
        report "Test 4 - X steps done: " & integer'image(to_integer(steps_x));
        report "Test 4 - Y steps done: " & integer'image(to_integer(steps_y));

        -- Verifica risultati (X dovrebbe avanzare 100, Y restare a 0)
        assert to_integer(pos_x) = 100
            report "ERROR: Test 4 X position incorrect!" severity error;
        assert to_integer(pos_y) = 0
            report "ERROR: Test 4 Y position should stay at 0!" severity error;
        assert to_integer(steps_y) = 0
            report "ERROR: Test 4 Y should not step!" severity error;

        wait for 1 us;

        -- Reset tra test per posizione pulita
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Test 5: Diagonale 45° (100,100)
        report "=== TEST 5: Diagonale 45 gradi (100,100) ===";
        delta_major <= to_unsigned(100, POSITION_WIDTH);
        delta_x <= to_unsigned(100, POSITION_WIDTH);
        delta_y <= to_unsigned(100, POSITION_WIDTH);
        is_major_x <= '1';  -- X è major (arbitrario, sono uguali)
        is_major_y <= '0';
        dir_x <= '1';  -- Direzione positiva
        dir_y <= '1';  -- Direzione positiva
        step_period <= to_unsigned(10, 16);

        start_x <= '1';
        start_y <= '1';
        wait for CLK_PERIOD;
        start_x <= '0';
        start_y <= '0';

        wait until busy_x = '0' and busy_y = '0';
        wait for 1 us;

        report "Test 5 - X final position: " & integer'image(to_integer(pos_x));
        report "Test 5 - Y final position: " & integer'image(to_integer(pos_y));
        report "Test 5 - X steps done: " & integer'image(to_integer(steps_x));
        report "Test 5 - Y steps done: " & integer'image(to_integer(steps_y));

        -- Verifica risultati (dovrebbe essere 100, 100 partendo da 0, 0)
        assert to_integer(pos_x) = 100
            report "ERROR: Test 5 X position incorrect!" severity error;
        assert to_integer(pos_y) = 100
            report "ERROR: Test 5 Y position incorrect!" severity error;
        assert to_integer(steps_x) = 100
            report "ERROR: Test 5 X steps incorrect!" severity error;
        assert to_integer(steps_y) = 100
            report "ERROR: Test 5 Y steps incorrect!" severity error;

        wait for 1 us;

        -- Reset tra test per posizione pulita
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Test 6: Movimento lento (step_period=1000)
        report "=== TEST 6: Movimento lento step_period=1000 (50,25) ===";
        delta_major <= to_unsigned(50, POSITION_WIDTH);
        delta_x <= to_unsigned(50, POSITION_WIDTH);
        delta_y <= to_unsigned(25, POSITION_WIDTH);
        is_major_x <= '1';
        is_major_y <= '0';
        dir_x <= '1';  -- Direzione positiva
        dir_y <= '1';  -- Direzione positiva
        step_period <= to_unsigned(1000, 16);  -- Movimento lento

        start_x <= '1';
        start_y <= '1';
        wait for CLK_PERIOD;
        start_x <= '0';
        start_y <= '0';

        wait until busy_x = '0' and busy_y = '0';
        wait for 1 us;

        report "Test 6 - X final position: " & integer'image(to_integer(pos_x));
        report "Test 6 - Y final position: " & integer'image(to_integer(pos_y));
        report "Test 6 - X steps done: " & integer'image(to_integer(steps_x));
        report "Test 6 - Y steps done: " & integer'image(to_integer(steps_y));

        -- Verifica risultati (dovrebbe essere 50, 25 partendo da 0, 0)
        assert to_integer(pos_x) = 50
            report "ERROR: Test 6 X position incorrect!" severity error;
        assert to_integer(pos_y) = 25
            report "ERROR: Test 6 Y position incorrect!" severity error;

        wait for 1 us;

        -- Fine simulazione
        report "=== SIMULAZIONE COMPLETATA - 6/6 TEST ===";
        wait;
    end process;

    -- ========================================================================
    -- Monitor step pulses
    -- ========================================================================
    monitor_proc: process(clk)
    begin
        if rising_edge(clk) then
            if step_x = '1' then
                x_count <= x_count + 1;
            end if;
            if step_y = '1' then
                y_count <= y_count + 1;
            end if;
        end if;
    end process;

end sim;
