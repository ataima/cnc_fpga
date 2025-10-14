-- Package definition (assumed, since not provided in the original query)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package cnc_pkg is
    constant POSITION_WIDTH : integer := 32;
    constant VELOCITY_WIDTH : integer := 32;
end package cnc_pkg;

-- Testbench for encoder_decoder
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cnc_pkg.all;

entity tb_encoder_decoder is
end tb_encoder_decoder;

architecture behavioral of tb_encoder_decoder is

    -- Component declaration
    component encoder_decoder
        generic (
            FILTER_STAGES : integer := 4;
            VEL_WINDOW : integer := 1000
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            enc_a : in std_logic;
            enc_b : in std_logic;
            enable : in std_logic;
            position_set : in std_logic;
            position_val : in signed(POSITION_WIDTH-1 downto 0);
            position : out signed(POSITION_WIDTH-1 downto 0);
            velocity : out signed(VELOCITY_WIDTH-1 downto 0);
            direction : out std_logic;
            error : out std_logic
        );
    end component;

    -- Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal enc_a : std_logic := '0';
    signal enc_b : std_logic := '0';
    signal enable : std_logic := '0';
    signal position_set : std_logic := '0';
    signal position_val : signed(POSITION_WIDTH-1 downto 0) := (others => '0');
    signal position : signed(POSITION_WIDTH-1 downto 0);
    signal velocity : signed(VELOCITY_WIDTH-1 downto 0);
    signal direction : std_logic;
    signal error : std_logic;

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz clock

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: encoder_decoder
        generic map (
            FILTER_STAGES => 4,
            VEL_WINDOW => 1000
        )
        port map (
            clk => clk,
            rst => rst,
            enc_a => enc_a,
            enc_b => enc_b,
            enable => enable,
            position_set => position_set,
            position_val => position_val,
            position => position,
            velocity => velocity,
            direction => direction,
            error => error
        );

    -- Clock generation
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimulus process
    stim_process: process
    begin
        -- Reset the system
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        enable <= '1';
        wait for 100 ns;

        -- Simulate 10 movements to the left (reverse direction: 00 -> 01 -> 11 -> 10 -> 00)
        for i in 1 to 10 loop
            -- State 00
            enc_a <= '0'; enc_b <= '0';
            wait for 10 * CLK_PERIOD;
            -- State 01
            enc_a <= '0'; enc_b <= '1';
            wait for 10 * CLK_PERIOD;
            -- State 11
            enc_a <= '1'; enc_b <= '1';
            wait for 10 * CLK_PERIOD;
            -- State 10
            enc_a <= '1'; enc_b <= '0';
            wait for 10 * CLK_PERIOD;
            -- Back to 00
            enc_a <= '0'; enc_b <= '0';
            wait for 10 * CLK_PERIOD;
        end loop;

        -- Wait a bit between directions
        wait for 100 ns;

        -- Simulate 10 movements to the right (forward direction: 00 -> 10 -> 11 -> 01 -> 00)
        for i in 1 to 10 loop
            -- State 00
            enc_a <= '0'; enc_b <= '0';
            wait for 10 * CLK_PERIOD;
            -- State 10
            enc_a <= '1'; enc_b <= '0';
            wait for 10 * CLK_PERIOD;
            -- State 11
            enc_a <= '1'; enc_b <= '1';
            wait for 10 * CLK_PERIOD;
            -- State 01
            enc_a <= '0'; enc_b <= '1';
            wait for 10 * CLK_PERIOD;
            -- Back to 00
            enc_a <= '0'; enc_b <= '0';
            wait for 10 * CLK_PERIOD;
        end loop;

        -- End simulation
        wait for 100 ns;
        report "Simulation completed";
        wait;
    end process;

end behavioral;