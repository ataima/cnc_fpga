-- ============================================================================
-- Quadrature Encoder Decoder
-- ============================================================================
-- Decodifica encoder incrementale in quadratura
-- - Filtraggio digitale anti-rimbalzo
-- - Rilevamento direzione
-- - Contatore posizione 32-bit signed
-- - Uscita velocità istantanea
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity encoder_decoder is
    generic (
        FILTER_STAGES : integer := 4;           -- Stadi filtro debounce
        VEL_WINDOW    : integer := 1000         -- Finestra misura velocità (clk cycles)
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        
        -- Input encoder (A e B in quadratura)
        enc_a         : in  std_logic;
        enc_b         : in  std_logic;
        
        -- Controllo
        enable        : in  std_logic;
        position_set  : in  std_logic;          -- Reset posizione
        position_val  : in  signed(POSITION_WIDTH-1 downto 0);
        
        -- Output
        position      : out signed(POSITION_WIDTH-1 downto 0);
        velocity      : out signed(VELOCITY_WIDTH-1 downto 0);
        direction     : out std_logic;          -- '1' = avanti, '0' = indietro
        error         : out std_logic           -- Errore sequenza
    );
end encoder_decoder;

architecture rtl of encoder_decoder is
    
    -- Filtri digitali per debounce
    signal a_filter : std_logic_vector(FILTER_STAGES-1 downto 0);
    signal b_filter : std_logic_vector(FILTER_STAGES-1 downto 0);
    signal a_clean  : std_logic;
    signal b_clean  : std_logic;
    
    -- Rilevamento fronti
    signal a_prev   : std_logic;
    signal b_prev   : std_logic;
    signal state    : std_logic_vector(3 downto 0);
    signal state_prev : std_logic_vector(3 downto 0);
    
    -- Posizione e velocità
    signal pos_counter : signed(POSITION_WIDTH-1 downto 0);
    signal vel_counter : signed(VELOCITY_WIDTH-1 downto 0);
    signal vel_timer   : unsigned(15 downto 0);
    signal step_count  : unsigned(15 downto 0);
    
    -- Direzione
    signal dir_internal : std_logic;
    signal error_flag   : std_logic;
    
begin

    -- ========================================================================
    -- Filtro digitale anti-rimbalzo
    -- ========================================================================
    -- Shift register per filtrare noise meccanico/elettrico
    process(clk, rst)
    begin
        if rst = '1' then
            a_filter <= (others => '0');
            b_filter <= (others => '0');
            a_clean <= '0';
            b_clean <= '0';
        elsif rising_edge(clk) then
            -- Shift register
            a_filter <= a_filter(FILTER_STAGES-2 downto 0) & enc_a;
            b_filter <= b_filter(FILTER_STAGES-2 downto 0) & enc_b;
            
            -- Output pulito quando tutti i bit sono uguali
            if a_filter = (a_filter'range => '1') then
                a_clean <= '1';
            elsif a_filter = (a_filter'range => '0') then
                a_clean <= '0';
            end if;
            
            if b_filter = (b_filter'range => '1') then
                b_clean <= '1';
            elsif b_filter = (b_filter'range => '0') then
                b_clean <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Decoder quadratura - State machine
    -- ========================================================================
    -- Stati encoder in quadratura (Gray code):
    -- 00 -> 10 -> 11 -> 01 -> 00  (forward)
    -- 00 -> 01 -> 11 -> 10 -> 00  (reverse)
    
    state <= a_clean & b_clean & a_prev & b_prev;
    
    process(clk, rst)
    begin
        if rst = '1' then
            a_prev <= '0';
            b_prev <= '0';
            state_prev <= (others => '0');
            pos_counter <= (others => '0');
            dir_internal <= '0';
            error_flag <= '0';
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Salva stato precedente
                a_prev <= a_clean;
                b_prev <= b_clean;
                state_prev <= state;
                
                -- Reset posizione su comando
                if position_set = '1' then
                    pos_counter <= position_val;
                else
                    -- Decode transition
                    case state is
                        -- Forward transitions
                        when "0000" | "1011" | "1101" | "0110" =>
                            null; -- No change
                            
                        when "1000" | "0010" | "0111"  =>
                            pos_counter <= pos_counter + 1;
                            dir_internal <= '1';
                            
                        -- Reverse transitions  
                        when "0100" | "0001" | "1110"  =>
                            pos_counter <= pos_counter - 1;
                            dir_internal <= '0';
                            
                        -- Invalid transitions (errore)
                        when others =>
                            error_flag <= '1';
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Misura velocità
    -- ========================================================================
    -- Conta step in finestra temporale fissa
    process(clk, rst)
    begin
        if rst = '1' then
            vel_timer <= (others => '0');
            step_count <= (others => '0');
            vel_counter <= (others => '0');
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Timer finestra
                if vel_timer < VEL_WINDOW then
                    vel_timer <= vel_timer + 1;
                    
                    -- Conta step
                    if state /= state_prev then
                        step_count <= step_count + 1;
                    end if;
                else
                    -- Fine finestra: calcola velocità
                    vel_timer <= (others => '0');
                    
                    if dir_internal = '1' then
                        vel_counter <= resize(signed(step_count), VELOCITY_WIDTH);
                    else
                        vel_counter <= -resize(signed(step_count), VELOCITY_WIDTH);
                    end if;
                    
                    step_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- Output
    position <= pos_counter;
    velocity <= vel_counter;
    direction <= dir_internal;
    error <= error_flag;

end rtl;
