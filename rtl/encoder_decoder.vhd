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
    
    -- Segnali ritardati per sincronizzazione
    signal a_clean_d1 : std_logic;  -- a_clean ritardato di 1 ciclo
    signal b_clean_d1 : std_logic;  -- b_clean ritardato di 1 ciclo
    signal a_clean_d2 : std_logic;  -- a_clean ritardato di 2 cicli
    signal b_clean_d2 : std_logic;  -- b_clean ritardato di 2 cicli
    
    -- Stato attuale e precedente (per quadratura)
    signal current_state : std_logic_vector(1 downto 0);  -- [a_clean_d1, b_clean_d1]
    signal prev_state    : std_logic_vector(1 downto 0);  -- [a_clean_d2, b_clean_d2]
    
    -- Rilevamento fronti
    signal pulse    : std_logic;            -- Segnale di impulso
    signal dir      : std_logic;            -- Segnale di direzione
    signal dir_internal : std_logic;        -- Segnale interno per direzione
    
    -- Posizione e velocità
    signal pos_counter : signed(POSITION_WIDTH-1 downto 0);
    signal vel_counter : signed(VELOCITY_WIDTH-1 downto 0);
    signal vel_timer   : unsigned(15 downto 0);
    signal step_count  : signed(15 downto 0);
    
    -- Errore
    signal error_flag   : std_logic;
    
    -- Segnale per ignorare il primo impulso spurio
    signal first_pulse : std_logic;

begin

    -- Filtro digitale anti-rimbalzo
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

    -- Ritardo dei segnali puliti
    process(clk, rst)
    begin
        if rst = '1' then
            a_clean_d1 <= '0';
            b_clean_d1 <= '0';
            a_clean_d2 <= '0';
            b_clean_d2 <= '0';
            first_pulse <= '0';
        elsif rising_edge(clk) then
            a_clean_d1 <= a_clean;
            b_clean_d1 <= b_clean;
            a_clean_d2 <= a_clean_d1;
            b_clean_d2 <= b_clean_d1;
            if enable = '1' and pulse = '1' then
                first_pulse <= '1';  -- Ignora il primo impulso
            end if;
        end if;
    end process;

    -- Definizione stato attuale e precedente
    current_state <= a_clean_d1 & b_clean_d1;
    prev_state <= a_clean_d2 & b_clean_d2;

    -- Generazione segnale pulse (rilevamento transizioni)
    pulse <= (a_clean_d1 xor a_clean_d2) or (b_clean_d1 xor b_clean_d2);
    
    -- Logica di direzione basata su transizioni di stato
    process(current_state, prev_state)
    begin
        case prev_state & current_state is
            -- Transizioni avanti (clockwise): 00->10, 10->11, 11->01, 01->00
            when "0010" | "1011" | "1101" | "0100" =>
                dir <= '1';  -- Avanti
            -- Transizioni indietro (counter-clockwise): 00->01, 01->11, 11->10, 10->00
            when "0001" | "0111" | "1110" | "1000" =>
                dir <= '0';  -- Indietro
            -- Transizioni non valide o statiche
            when others =>
                dir <= dir;  -- Mantieni direzione precedente
        end case;
    end process;

    -- Contatore posizione up/down
    process(clk, rst)
    begin
        if rst = '1' then
            pos_counter <= (others => '0');
            dir_internal <= '0';
            error_flag <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Aggiorna direzione interna solo su impulso valido
                if pulse = '1' and first_pulse = '1' then
                    dir_internal <= dir;
                end if;
                
                -- Reset posizione su comando
                if position_set = '1' then
                    pos_counter <= position_val;
                elsif pulse = '1' and first_pulse = '1' then
                    -- Aggiorna contatore in base a direzione
                    if dir_internal = '1' then
                        pos_counter <= pos_counter + 1;
                    else
                        pos_counter <= pos_counter - 1;
                    end if;
                end if;
                
                -- Rileva errore (transizioni non valide)
                case prev_state & current_state is
                    -- Transizioni valide
                    when "0010" | "1011" | "1101" | "0100" |  -- Avanti
                         "0001" | "0111" | "1110" | "1000" =>  -- Indietro
                        error_flag <= '0';
                    -- Stesso stato
                    when "0000" | "0101" | "1010" | "1111" =>
                        error_flag <= '0';
                    -- Transizioni non valide
                    when others =>
                        error_flag <= '1';
                end case;
            end if;
        end if;
    end process;

    -- Misura velocità
    process(clk, rst)
    begin
        if rst = '1' then
            vel_timer <= (others => '0');
            step_count <= (others => '0');
            vel_counter <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Timer finestra
                if vel_timer < VEL_WINDOW - 1 then
                    vel_timer <= vel_timer + 1;
                    -- Accumula step signed
                    if pulse = '1' and first_pulse = '1' then
                        if dir_internal = '1' then
                            step_count <= step_count + 1;
                        else
                            step_count <= step_count - 1;
                        end if;
                    end if;
                else
                    -- Fine finestra: output velocità
                    vel_timer <= (others => '0');
                    vel_counter <= resize(step_count, VELOCITY_WIDTH);
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

