library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity tb_encoder_decoder is
end tb_encoder_decoder;

architecture behavioral of tb_encoder_decoder is

    -- Costanti
    constant CLK_PERIOD      : time := 10 ns;  -- Periodo di clock (100 MHz)
    constant FILTER_STAGES   : integer := 4;   -- Stadi filtro debounce
    constant VEL_WINDOW      : integer := 1000; -- Finestra misura velocità
    constant POSITION_WIDTH  : integer := 32;  -- Larghezza contatore posizione
    constant VELOCITY_WIDTH  : integer := 16;  -- Larghezza contatore velocità

    -- Segnali
    signal clk           : std_logic := '0';
    signal rst           : std_logic := '0';
    signal enc_a         : std_logic := '0';
    signal enc_b         : std_logic := '0';
    signal enable        : std_logic := '0';
    signal position_set  : std_logic := '0';
    signal position_val  : signed(POSITION_WIDTH-1 downto 0) := (others => '0');
    signal position      : signed(POSITION_WIDTH-1 downto 0);
    signal velocity      : signed(VELOCITY_WIDTH-1 downto 0);
    signal direction     : std_logic;
    signal error         : std_logic;

    -- Componente DUT
    component encoder_decoder
        generic (
            FILTER_STAGES : integer;
            VEL_WINDOW    : integer
        );
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            enc_a         : in  std_logic;
            enc_b         : in  std_logic;
            enable        : in  std_logic;
            position_set  : in  std_logic;
            position_val  : in  signed(POSITION_WIDTH-1 downto 0);
            position      : out signed(POSITION_WIDTH-1 downto 0);
            velocity      : out signed(VELOCITY_WIDTH-1 downto 0);
            direction     : out std_logic;
            error         : out std_logic
        );
    end component;

begin

    -- Istanza del DUT
    dut: encoder_decoder
        generic map (
            FILTER_STAGES => FILTER_STAGES,
            VEL_WINDOW    => VEL_WINDOW
        )
        port map (
            clk           => clk,
            rst           => rst,
            enc_a         => enc_a,
            enc_b         => enc_b,
            enable        => enable,
            position_set  => position_set,
            position_val  => position_val,
            position      => position,
            velocity      => velocity,
            direction     => direction,
            error         => error
        );

    -- Generazione del clock
    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- Stimolo e debug
    stim_proc: process
        -- Procedura per generare una transizione in quadratura con debug
        procedure quad_pulse(signal a, b: inout std_logic; forward: boolean; pulse_num: integer) is
            variable dir_str : string(1 to 7);
        begin
            if forward then
                dir_str := "Forward";
                -- Sequenza forward: 00 -> 10 -> 11 -> 01 -> 00
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                a <= '1';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
                b <= '1';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
                a <= '0';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
                b <= '0';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
            else
                dir_str := "Reverse";
                -- Sequenza reverse: 00 -> 01 -> 11 -> 10 -> 00
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                b <= '1';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
                a <= '1';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
                b <= '0';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
                a <= '0';
                wait for CLK_PERIOD * FILTER_STAGES * 2;
                report "Pulse " & integer'image(pulse_num) & " (" & dir_str & "): enc_a=" & std_logic'image(a) & ", enc_b=" & std_logic'image(b) & ", position=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error) & " at time " & time'image(now);
            end if;
        end procedure;
    begin
        -- Inizializzazione
        rst <= '1';
        enable <= '0';
        position_set <= '0';
        position_val <= (others => '0');
        enc_a <= '0';
        enc_b <= '0';
        wait for CLK_PERIOD * 10;
        report "Inizializzazione completata, position=" & integer'image(to_integer(position)) & ", error=" & std_logic'image(error);

        -- Rimuovi reset
        rst <= '0';
        wait for CLK_PERIOD * 10;
        report "Reset rimosso, position=" & integer'image(to_integer(position)) & ", error=" & std_logic'image(error);

        -- Abilita encoder
        enable <= '1';
        wait for CLK_PERIOD * 10;
        report "Encoder abilitato, position=" & integer'image(to_integer(position)) & ", error=" & std_logic'image(error);

        -- Simula 40 impulsi in avanti
        report "Inizio 40 impulsi in avanti";
        for i in 1 to 40 loop
            quad_pulse(enc_a, enc_b, true, i);
        end loop;
        report "Fine 40 impulsi in avanti, posizione attesa=160, posizione attuale=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error);

        -- Attendi una finestra di velocità
        wait for CLK_PERIOD * VEL_WINDOW;
        report "Dopo finestra velocità (avanti), position=" & integer'image(to_integer(position)) & ", velocity=" & integer'image(to_integer(velocity)) & ", error=" & std_logic'image(error);

        -- Simula 40 impulsi indietro
        report "Inizio 40 impulsi indietro";
        for i in 1 to 40 loop
            quad_pulse(enc_a, enc_b, false, i);
        end loop;
        report "Fine 40 impulsi indietro, posizione attesa=0, posizione attuale=" & integer'image(to_integer(position)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error);

        -- Attendi una finestra di velocità
        wait for CLK_PERIOD * VEL_WINDOW;
        report "Dopo finestra velocità (indietro), position=" & integer'image(to_integer(position)) & ", velocity=" & integer'image(to_integer(velocity)) & ", error=" & std_logic'image(error);

        -- Test reset posizione
        report "Inizio test reset posizione a 100";
        position_set <= '1';
        position_val <= to_signed(100, POSITION_WIDTH);
        wait for CLK_PERIOD * 2;
        position_set <= '0';
        wait for CLK_PERIOD * 2;
        report "Fine test reset posizione, posizione attesa=100, posizione attuale=" & integer'image(to_integer(position)) & ", error=" & std_logic'image(error);

        -- Attendi e termina
        wait for CLK_PERIOD * VEL_WINDOW * 2;
        enable <= '0';
        wait for CLK_PERIOD * 100;
        report "Simulazione completata, position=" & integer'image(to_integer(position)) & ", velocity=" & integer'image(to_integer(velocity)) & ", direction=" & std_logic'image(direction) & ", error=" & std_logic'image(error);

        wait;
    end process;

end behavioral;
