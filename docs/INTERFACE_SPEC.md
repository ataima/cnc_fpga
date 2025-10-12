# CNC 3-Axis Controller - Interface Specification

## Overview

This document describes the control interface for the CNC 3-axis FPGA controller. The controller is designed to be controlled by an external microcontroller (ESP32, STM32, etc.) or soft-core processor (NIOS II).

---

## Control Signals

### Clock and Reset

| Signal | Direction | Type | Description |
|--------|-----------|------|-------------|
| `clk` | Input | std_logic | 50 MHz system clock |
| `rst` | Input | std_logic | Active-high asynchronous reset |

### Movement Commands

| Signal | Direction | Type | Width | Description |
|--------|-----------|------|-------|-------------|
| `move_start` | Input | std_logic | 1-bit | Start movement (pulse high for 1 cycle) |
| `move_abort` | Input | std_logic | 1-bit | Emergency stop - halts all axes immediately |
| `enable` | Input | std_logic | 1-bit | Master enable for all axes (active high) |

### Target Position (Relative Movement)

| Signal | Direction | Type | Width | Description |
|--------|-----------|------|-------|-------------|
| `target_x` | Input | signed | 32-bit | Target X position in steps (relative to current) |
| `target_y` | Input | signed | 32-bit | Target Y position in steps (relative to current) |
| `target_z` | Input | signed | 32-bit | Target Z position in steps (relative to current) |

**Range:** -2,147,483,648 to +2,147,483,647 steps per axis

**Sign Convention:**
- Positive value: Move in positive direction (DIR = '1')
- Negative value: Move in negative direction (DIR = '0')

### Speed Control

| Signal | Direction | Type | Width | Description |
|--------|-----------|------|-------|-------------|
| `step_period_in` | Input | unsigned | 16-bit | Number of clock cycles between steps |

**Calculation:**
```
step_period_in = CLK_FREQ_HZ / feedrate_steps_per_sec

Example:
- Feedrate = 10,000 steps/sec
- Clock = 50 MHz
- step_period_in = 50,000,000 / 10,000 = 5000 clock cycles
```

**Range:**
- Minimum: 100 cycles (500 kHz max step rate)
- Maximum: 65,535 cycles (~762 Hz min step rate)
- Default (if 0): 1000 cycles (50 kHz)

### Status Outputs

| Signal | Direction | Type | Width | Description |
|--------|-----------|------|-------|-------------|
| `pos_x` | Output | signed | 32-bit | Current X position from encoder feedback |
| `pos_y` | Output | signed | 32-bit | Current Y position from encoder feedback |
| `pos_z` | Output | signed | 32-bit | Current Z position from encoder feedback |
| `busy` | Output | std_logic | 1-bit | '1' when movement in progress |
| `fault` | Output | std_logic | 1-bit | '1' when error detected (limit hit, encoder error) |
| `state_debug` | Output | std_logic_vector | 4-bit | Debug state indicator (see below) |

**Debug State Values:**
- `0001` = IDLE
- `0010` = CALC_PARAMS
- `0100` = MOVING
- `1000` = DONE

---

## Movement Protocol

### Starting a Movement

**Sequence:**

1. **Setup Target Position:**
   ```
   target_x <= to_signed(1000, 32);   -- Move +1000 steps on X
   target_y <= to_signed(500, 32);    -- Move +500 steps on Y
   target_z <= to_signed(0, 32);      -- No Z movement
   ```

2. **Setup Speed:**
   ```
   step_period_in <= to_unsigned(5000, 16);  -- 10,000 steps/sec
   ```

3. **Enable System:**
   ```
   enable <= '1';
   ```

4. **Start Movement (single pulse):**
   ```
   move_start <= '1';
   wait for 20 ns;  -- One clock cycle
   move_start <= '0';
   ```

5. **Wait for Completion:**
   ```
   wait until busy = '0';
   ```

### Aborting a Movement

```vhdl
move_abort <= '1';
wait for 20 ns;  -- One clock cycle
move_abort <= '0';
```

**Effect:** All axes stop immediately at their current position. The `busy` signal goes low within 2 clock cycles.

### State Machine Behavior

```
IDLE → CALC_PARAMS → MOVING → DONE → IDLE
  ↑                      ↓
  └──────────────────────┘
        (move_abort)
```

**State Descriptions:**

- **IDLE:** Waiting for `move_start` signal
- **CALC_PARAMS:** Calculating Bresenham parameters (1 clock cycle)
  - Computes absolute delta values
  - Determines major axis
  - Sets direction signals
- **MOVING:** Executing movement using Bresenham interpolation
  - Generates step pulses according to `step_period_in`
  - All three axes move simultaneously
- **DONE:** Movement complete, waiting for `move_start` to go low before returning to IDLE

---

## Encoder Feedback

### Encoder Inputs

| Signal | Direction | Type | Description |
|--------|-----------|------|-------------|
| `enc_x_a`, `enc_x_b` | Input | std_logic | X-axis quadrature encoder (A/B channels) |
| `enc_y_a`, `enc_y_b` | Input | std_logic | Y-axis quadrature encoder (A/B channels) |
| `enc_z_a`, `enc_z_b` | Input | std_logic | Z-axis quadrature encoder (A/B channels) |

**Encoder Specifications:**
- Type: Incremental quadrature (A/B channels)
- Resolution: 600 PPR (configurable in package)
- Digital filtering: 4-stage anti-bounce filter
- Maximum frequency: ~10 MHz (hardware dependent)

**Encoder Sequence (CW rotation):**
```
A: ‾‾‾‾‾‾‾‾‾\________/‾‾‾‾‾‾‾‾‾
B: ‾‾‾\________/‾‾‾‾‾‾‾‾‾\____
   00→10→11→01→00  (Gray code)
```

---

## Limit Switches

### Limit Switch Inputs

| Signal | Direction | Type | Description |
|--------|-----------|------|-------------|
| `limit_x_min`, `limit_x_max` | Input | std_logic | X-axis min/max limits (active high) |
| `limit_y_min`, `limit_y_max` | Input | std_logic | Y-axis min/max limits (active high) |
| `limit_z_min`, `limit_z_max` | Input | std_logic | Z-axis min/max limits (active high) |

**Behavior:**
- When moving in positive direction and `limit_*_max = '1'`, movement is blocked and `fault` is set
- When moving in negative direction and `limit_*_min = '1'`, movement is blocked and `fault` is set
- Fault persists until system is reset or `move_start` is issued after clearing the condition

**Safety:**
- Limit checks occur **before** each step pulse is generated
- No steps are generated if limit would be violated
- `fault` signal can be used to trigger external emergency stop

---

## Step/Dir Outputs (to Motor Drivers)

### Output Signals per Axis

| Signal | Direction | Type | Description |
|--------|-----------|------|-------------|
| `step_x`, `step_y`, `step_z` | Output | std_logic | Step pulse (active high, 5µs width) |
| `dir_x`, `dir_y`, `dir_z` | Output | std_logic | Direction ('1' = CW, '0' = CCW) |
| `enable_x`, `enable_y`, `enable_z` | Output | std_logic | Enable signal (follows master `enable` input) |

**Timing Specifications (TB6600 compatible):**
- Step pulse width: 5 µs
- Step pulse hold time: 5 µs (low time between pulses)
- Direction setup time: 1 µs (before step pulse)
- Minimum step period: 100 clock cycles (2 µs @ 50 MHz)

**Pulse Timing Diagram:**
```
DIR:  ────────────────────────────────────────
            ↑ 1µs setup
STEP: ______/‾‾‾‾‾‾‾\__________/‾‾‾‾‾‾‾\______
             5µs       5µs hold
```

---

## Fault Conditions

The `fault` output goes high ('1') when:

1. **Limit Switch Hit:** Movement attempted beyond soft/hard limits
2. **Encoder Error:** Invalid quadrature sequence detected
3. **Multi-Axis Fault:** Any axis fault triggers global fault signal

**Fault Recovery:**

```vhdl
-- Clear fault by issuing reset or new move command
if fault = '1' then
    -- Option 1: Hardware reset
    rst <= '1';
    wait for 100 ns;
    rst <= '0';

    -- Option 2: Clear by starting new safe movement
    -- (Ensure limits are cleared first)
    target_x <= to_signed(0, 32);
    move_start <= '1';
    wait for 20 ns;
    move_start <= '0';
end if;
```

---

## Timing Constraints

### Critical Timing Parameters

| Parameter | Min | Typ | Max | Unit |
|-----------|-----|-----|-----|------|
| Clock frequency | 40 | 50 | 60 | MHz |
| Step rate per axis | 762 | - | 500,000 | steps/sec |
| Position update latency | - | 20 | 40 | ns |
| Abort response time | - | 40 | 100 | ns |

### Setup/Hold Requirements

| Signal | Setup Time | Hold Time |
|--------|------------|-----------|
| `move_start` | 5 ns | 2 ns |
| `target_*` | 10 ns | 5 ns |
| `step_period_in` | 10 ns | 5 ns |
| Encoder inputs | 0 ns | 0 ns (filtered internally) |

---

## Example Usage (VHDL Testbench)

```vhdl
-- Move diagonally: X=1000, Y=500, Z=0 at 10k steps/sec
procedure move_xyz(
    signal target_x, target_y, target_z : out signed(31 downto 0);
    signal step_period : out unsigned(15 downto 0);
    signal move_start : out std_logic;
    signal busy : in std_logic
) is
begin
    -- Setup
    target_x <= to_signed(1000, 32);
    target_y <= to_signed(500, 32);
    target_z <= to_signed(0, 32);
    step_period <= to_unsigned(5000, 16);  -- 50MHz / 10k = 5000

    -- Start (pulse)
    wait for 20 ns;
    move_start <= '1';
    wait for 20 ns;
    move_start <= '0';

    -- Wait completion
    wait until busy = '0';
    report "Movement complete";
end procedure;
```

---

## Pin Count Requirements

**Warning:** The current design requires **211 pins** for full parallel interface, but the target FPGA (EP4CE6E22C8N) only has **144 pins** available.

**Recommended Solutions:**

### Option 1: Serial Interface (SPI/UART)
- Add SPI slave module to receive commands
- Reduce pin count to ~10 pins
- Trade-off: Slower command latency (~1-10 µs)

### Option 2: NIOS II Integration
- Integrate NIOS II soft processor
- Use Avalon-MM bus interface
- Full 32-bit register access with minimal pins

### Option 3: Simplified Parallel Interface
- Multiplex position outputs (read-only register bank)
- Reduce target position to 16-bit (±32k steps)
- Total pins: ~40-50

---

## Register Map (for future Serial/Bus interface)

| Address | Register | Width | R/W | Description |
|---------|----------|-------|-----|-------------|
| 0x00 | CTRL | 8-bit | W | Control register (start, abort, enable) |
| 0x04 | STATUS | 8-bit | R | Status register (busy, fault, state) |
| 0x08 | TARGET_X | 32-bit | W | X target position |
| 0x0C | TARGET_Y | 32-bit | W | Y target position |
| 0x10 | TARGET_Z | 32-bit | W | Z target position |
| 0x14 | STEP_PERIOD | 16-bit | W | Step period (clock cycles) |
| 0x18 | POS_X | 32-bit | R | Current X position |
| 0x1C | POS_Y | 32-bit | R | Current Y position |
| 0x20 | POS_Z | 32-bit | R | Current Z position |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-12 | Claude Code | Initial specification |
| 1.1 | 2025-01-12 | Claude Code | Added pin count warning, removed hardware division |

---

**END OF SPECIFICATION**
