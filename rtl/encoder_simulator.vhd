--------------------------------------------------------------------------------
-- File: encoder_simulator.vhd
-- Description: Quadrature encoder simulator for closed-loop testing
--              Generates A/B quadrature signals based on STEP/DIR outputs
--
-- Features:
--   - Monitors STEP/DIR signals from motor driver
--   - Generates quadrature output with configurable delay (default 10us)
--   - Direction follows DIR signal (CW/CCW)
--   - Freezes when enable=0
--   - 1 quadrature edge per step pulse (simplified, fast simulation)
--
-- Usage: Connect between step_dir_generator output and encoder_decoder input
-- Author: Generated for cnc_fpga project
-- Date: 2025-10-12
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder_simulator is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000;  -- 50 MHz
        DELAY_US    : integer := 10            -- Delay from STEP to quadrature edge
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Input: Monitor STEP/DIR/ENABLE from motor driver
        step_in     : in  std_logic;
        dir_in      : in  std_logic;
        enable_in   : in  std_logic;

        -- Output: Simulated quadrature encoder signals
        enc_a_out   : out std_logic;
        enc_b_out   : out std_logic
    );
end encoder_simulator;

architecture rtl of encoder_simulator is

    -- Delay counter (10us = 500 cycles @ 50MHz)
    constant DELAY_CYCLES : integer := (CLK_FREQ_HZ / 1_000_000) * DELAY_US;
    signal delay_counter  : integer range 0 to DELAY_CYCLES := 0;
    signal delayed_step   : std_logic := '0';

    -- Step edge detection
    signal step_prev      : std_logic := '0';
    signal step_edge      : std_logic := '0';

    -- Direction latch (captured at step edge)
    signal dir_latched    : std_logic := '0';

    -- Quadrature state machine (Gray code)
    -- 00 -> 01 -> 11 -> 10 -> 00 (forward, dir=1)
    -- 00 -> 10 -> 11 -> 01 -> 00 (reverse, dir=0)
    type quad_state_t is (S00, S01, S11, S10);
    signal quad_state : quad_state_t := S00;

    -- Output registers
    signal enc_a_int : std_logic := '0';
    signal enc_b_int : std_logic := '0';

begin

    -- Output assignment
    enc_a_out <= enc_a_int;
    enc_b_out <= enc_b_int;

    -------------------------------------------------------------------------
    -- Step edge detection with delay
    -------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            step_prev <= '0';
            step_edge <= '0';
            delay_counter <= 0;
            delayed_step <= '0';
            dir_latched <= '0';

        elsif rising_edge(clk) then
            -- Default
            step_edge <= '0';
            delayed_step <= '0';

            if enable_in = '1' then
                -- Detect rising edge on step_in
                step_prev <= step_in;
                if step_in = '1' and step_prev = '0' then
                    step_edge <= '1';
                    dir_latched <= dir_in;  -- Capture direction at step edge
                end if;

                -- Delay generator
                if step_edge = '1' then
                    -- Start delay counter
                    delay_counter <= DELAY_CYCLES;
                elsif delay_counter > 0 then
                    delay_counter <= delay_counter - 1;
                    if delay_counter = 1 then
                        -- Delay elapsed, generate delayed step pulse
                        delayed_step <= '1';
                    end if;
                end if;

            else
                -- Freeze when disabled
                delay_counter <= 0;
                delayed_step <= '0';
                step_edge <= '0';
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- Quadrature generator (Gray code state machine)
    -------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            quad_state <= S00;
            enc_a_int <= '0';
            enc_b_int <= '0';

        elsif rising_edge(clk) then
            if enable_in = '1' then
                -- Advance quadrature state on delayed step
                if delayed_step = '1' then
                    if dir_latched = '1' then
                        -- Forward direction (CW)
                        case quad_state is
                            when S00 => quad_state <= S01;
                            when S01 => quad_state <= S11;
                            when S11 => quad_state <= S10;
                            when S10 => quad_state <= S00;
                        end case;
                    else
                        -- Reverse direction (CCW)
                        case quad_state is
                            when S00 => quad_state <= S10;
                            when S10 => quad_state <= S11;
                            when S11 => quad_state <= S01;
                            when S01 => quad_state <= S00;
                        end case;
                    end if;
                end if;

                -- Update A/B outputs based on state (Gray code)
                case quad_state is
                    when S00 =>
                        enc_a_int <= '0';
                        enc_b_int <= '0';
                    when S01 =>
                        enc_a_int <= '0';
                        enc_b_int <= '1';
                    when S11 =>
                        enc_a_int <= '1';
                        enc_b_int <= '1';
                    when S10 =>
                        enc_a_int <= '1';
                        enc_b_int <= '0';
                end case;

            else
                -- Freeze outputs when disabled
                null;  -- Maintain current state
            end if;
        end if;
    end process;

end rtl;
