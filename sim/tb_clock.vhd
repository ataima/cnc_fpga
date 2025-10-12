library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_clock is
end tb_clock;

architecture sim of tb_clock is
    signal clk : std_logic := '0';
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz
begin
    process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;
end sim;
