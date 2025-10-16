# CNC 3-Axis FPGA Controller - Project Context

**Last Updated:** 2025-10-16 (21:20 UTC)
**Status:** ✅ ROM-based design complete + 🎯 **HOMING SYSTEM TESTED & VERIFIED** | 🔄 RAM/SPI interface pending
**Target Device:** Intel/Altera Cyclone IV EP4CE6E22C8N (6272 LE, 144-pin EQFP)

---

## 🎯 Project Overview

This is a **3-axis CNC controller** implemented in VHDL for FPGA, featuring:
- **Bresenham line interpolation** algorithm for smooth 3D linear movements
- **Quadrature encoder feedback** (600 PPR) for closed-loop position control
- **STEP/DIR outputs** compatible with TB6600 stepper drivers
- **ROM-based trajectory storage** (24 positions, 288 bytes) ✅ **UPDATED**
- **Automatic homing system** (Z→Y→X cascade with release+offset) ✨ **NEW**
- **Encoder simulator** for realistic closed-loop testing
- **Limit switch safety** logic with fault detection
- **Deterministic timing** (<10ns jitter) @ 50 MHz clock

**Applications:** CNC milling, 3D printers, laser cutters, pick-and-place machines

---

## 📂 Project Structure

```
~/quartus_wb/cnc_fpga/
├── rtl/                           # RTL source files (VHDL-93)
│   ├── cnc_pkg.vhd                # Package with types & constants (UPDATED ✅)
│   ├── encoder_decoder.vhd        # Quadrature encoder decoder (FIXED ✅)
│   ├── encoder_simulator.vhd      # Encoder simulator for testing
│   ├── bresenham_axis.vhd         # Bresenham core per axis (FIXED ✅)
│   ├── step_dir_generator.vhd     # STEP/DIR pulse generator
│   ├── cnc_3axis_controller.vhd   # Top-level integration (FIXED ✅)
│   ├── trajectory_rom.vhd         # 24-position ROM (288 bytes) ✅ UPDATED
│   ├── rom_controller.vhd         # ROM sequencer with auto-advance
│   ├── cnc_3axis_rom_top.vhd      # Top-level with ROM & simulators
│   │
│   ├── homing_sequence_v2.vhd     # 3-axis homing sequencer (Z→Y→X) ✨ NEW
│   ├── axis_homing_v3.vhd         # Single-axis homing controller ✨ NEW
│   ├── axis_homing_v2.vhd         # Legacy homing v2
│   ├── axis_homing.vhd            # Legacy homing v1
│   └── reset_z.vhd                # Z-axis automatic reset ✨ NEW
│
├── sim/                           # Simulation testbenches
│   ├── tb_bresenham.vhd           # Enhanced testbench (6 test cases)
│   ├── tb_rom_playback.vhd        # ROM playback testbench
│   ├── tb_rom_simple.vhd          # Simplified closed-loop test
│   ├── tb_rom_full.vhd            # Full ROM test (24 positions)
│   ├── tb_rom_24positions.vhd     # ROM geometry verification
│   ├── tb_rom_delta_check.vhd     # Delta calculation test
│   ├── tb_rom_debug.vhd           # ROM debug viewer
│   ├── tb_rom_viewer.vhd          # ROM content viewer
│   │
│   ├── tb_homing_sequence_v2.vhd  # Full homing test (Z→Y→X) ✨ NEW
│   ├── tb_homing_sequence.vhd     # Legacy homing test
│   ├── tb_reset_z.vhd             # Z-axis reset test ✨ NEW
│   ├── tb_3axis_test.vhd          # 3-axis integration test
│   ├── tb_single_move.vhd         # Single movement test
│   ├── tb_encoder_decoder.vhd     # Encoder decoder test
│   └── tb_clock.vhd               # Clock test
│
├── constraints/                   # Quartus constraints
│   └── EP4CE6E22C8N.qsf          # Pin assignments & timing (UPDATED ✅)
│
├── quartus/                       # Quartus project files
│   └── (user-created project)
│
├── docs/                          # Documentation
│   ├── INTERFACE_SPEC.md          # Complete interface specification
│   └── README.md
│
├── cnc_fpga.md                    # Original design documentation
├── CORRECTIONS_APPLIED.md         # Bug fixes report (January 2025)
├── CORRECTIONS_OCTOBER_2025.md    # Bug fixes report (October 2025) ✨NEW
└── CLAUDE.md                      # This file (project context)
```

---

## 🔧 Recent Changes (2025-10-12)

### ✅ ROM-Based Design Implementation - October 2025

**Problem Solved:** Original design required 211 pins, FPGA has only 144 pins.

**Solution:** ROM-based trajectory storage with encoder simulation for testing.

#### 1. **trajectory_rom.vhd** - Pre-programmed 64-position ROM
   - 768 bytes total (64 positions × 3 axes × 32 bits)
   - Stores absolute positions (X, Y, Z)
   - Pre-programmed trajectory: square, diagonals, circle approximation
   - Synchronous read (1 cycle latency)

#### 2. **rom_controller.vhd** - Automatic sequencer
   - Reads positions from ROM sequentially
   - **Calculates relative deltas** (current - previous position)
   - Auto-advances when movement complete (busy='0')
   - Two modes: LOOP (infinite) or ONE_SHOT (run once)
   - Outputs relative movement commands to CNC controller

#### 3. **encoder_simulator.vhd** - Closed-loop testing
   - Monitors STEP/DIR/ENABLE outputs
   - Generates quadrature A/B signals with 10µs delay
   - Gray code state machine (00→01→11→10)
   - Direction follows DIR signal (CW/CCW)
   - Freezes when enable=0
   - **Makes testing realistic** with actual encoder feedback

#### 4. **cnc_3axis_rom_top.vhd** - Integrated top-level
   - **Only 39 pins required!** (vs 211 original)
   - Includes ROM + controller + CNC + 3× encoder simulators
   - Pin `open_loop`:
     - `0` = Use simulated encoders (closed-loop testing)
     - `1` = Use external encoders (hardware mode)
   - MUX selects encoder source automatically

### Pin Count Solution

| Design | Pin Count | Compatible? |
|--------|-----------|-------------|
| **Original** (parallel interface) | 211 | ❌ No (144 available) |
| **ROM-based** (this design) | **39** | ✅ **Yes!** |
| **Reduction** | **-172 pins (-82%)** | ✅ Fits perfectly |

**Pin Breakdown:**
- System: 2 (clk, rst)
- Control: 3 (enable, pause, open_loop)
- Encoders: 6 (X/Y/Z A/B) - can be simulated or external
- Limits: 6 (X/Y/Z min/max)
- Motors: 9 (X/Y/Z STEP/DIR/ENABLE)
- Status: 7 (busy, fault, state_debug[3:0], sequence_active, sequence_done)
- Debug: 6 (current_step[5:0])
- **Total: 39 pins** (27% of 144 available)

### Simulation Results

```bash
# Closed-loop test with encoder simulation
cd sim/
vcom -93 ../rtl/*.vhd tb_rom_simple.vhd
vsim -c work.tb_rom_simple -do "run 5 ms; quit -f"
```

**Results:** ✅ **All tests PASS**
- First 5 ROM positions executed successfully
- Closed-loop feedback working (encoder simulator → decoder → controller)
- 0 errors, 0 warnings
- Realistic 10µs encoder delay verified

### ✅ Additional Bug Fixes - October 2025

1. **bresenham_axis.vhd:156** - Fixed incorrect `minor_steps` increment
2. **bresenham_axis.vhd:137** - Fixed timer off-by-one error (10% timing error)
3. **rom_controller.vhd** - Fixed absolute→relative position conversion
4. **cnc_3axis_rom_top.vhd** - VHDL-93 compatibility (output buffering)

**See:** `CORRECTIONS_OCTOBER_2025.md` for detailed change log

---

## 🎯 NEW FEATURE: Automatic Homing System (2025-10-16)

### Overview
Sistema completo di **homing automatico a 3 assi** con sequenza cascata **Z → Y → X** e procedura completa per ogni asse.

**Caratteristiche principali:**
- ✅ **Sequenza cascata**: Z si azzera per primo, poi Y (quando Z completo), poi X (quando Y completo)
- ✅ **Procedura completa per asse**: HOMING → DEBOUNCE → RELEASE → OFFSET → SET_ZERO → COMPLETE
- ✅ **Offset programmabile**: 200 steps dal limite al punto zero (configurabile)
- ✅ **Debounce hardware**: 20µs per evitare falsi trigger dei limit switch
- ✅ **Segnali di stato**: `pos_z_zero`, `pos_y_zero`, `pos_x_zero`, `all_axes_homed`, `all_axes_homed_n`
- ✅ **LED ready**: Segnale `all_axes_homed_n` (attivo basso) per pilotare LED esterno

### Componenti Implementati

#### 1. **homing_sequence_v2.vhd** - Sequencer 3 assi
Coordina la sequenza di homing per tutti e 3 gli assi in cascata.

**Interfaccia:**
```vhdl
entity homing_sequence_v2 is
    generic (
        CLK_FREQ_HZ     : integer := 50_000_000;  -- 50 MHz
        WAIT_TIME_MS    : integer := 1;           -- Wait after reset
        OFFSET_STEPS    : integer := 200          -- Steps from limit to zero
    );
    port (
        -- System
        clk, rst        : in  std_logic;

        -- Limit switches (active low: 0=hit, 1=not hit)
        limit_min_x/y/z : in  std_logic;

        -- Motor outputs (9 signals: 3 × STEP/DIR/ENABLE)
        step_x/y/z, dir_x/y/z, enable_x/y/z : out std_logic;

        -- Position feedback (all zero after homing)
        pos_x/y/z       : out signed(31 downto 0);

        -- Status outputs
        pos_z_zero      : out std_logic;  -- Z axis homed (enables Y)
        pos_y_zero      : out std_logic;  -- Y axis homed (enables X)
        pos_x_zero       : out std_logic;  -- X axis homed (enables ROM)
        all_axes_homed   : out std_logic;  -- All 3 axes complete (active high)
        all_axes_homed_n : out std_logic;  -- All 3 axes complete (active low LED)
        homing_active    : out std_logic;  -- Any homing in progress

        -- Debug
        state_z/y/x      : out std_logic_vector(2 downto 0)  -- State machine per axis
    );
end homing_sequence_v2;
```

**Nuovo segnale LED (2025-10-16):**
- `all_axes_homed_n`: Versione negata di `all_axes_homed` per pilotaggio LED
  - `'0'` quando tutti gli assi completati → **LED acceso** (active low)
  - `'1'` durante homing → **LED spento**
  - Collegamento diretto: `LED_PIN <= all_axes_homed_n;`

**Logica di cascata:**
```
Reset → Wait 1ms → Z starts
Z complete → pos_z_zero='1' → Y starts
Y complete → pos_y_zero='1' → X starts
X complete → pos_x_zero='1' → all_axes_homed='1' → ROM enabled
```

#### 2. **axis_homing_v3.vhd** - Controller singolo asse
Esegue la procedura di homing completa per un singolo asse.

**State Machine:**
```
IDLE           (000) → Attesa enable_homing
HOMING         (001) → Movimento verso limit_min (dir=0, negative)
DEBOUNCE_HIT   (010) → Attesa 20µs dopo hit del limite
RELEASE        (011) → Movimento in avanti fino a rilascio switch (dir=1)
OFFSET         (100) → Movimento di 200 steps in avanti
SET_ZERO       (101) → Imposta posizione = 0
COMPLETE       (110) → Homing completato (axis_homed='1')
```

**Procedura dettagliata:**
1. **HOMING**: Muove verso `limit_min` finché `limit='0'` (hit)
2. **DEBOUNCE_HIT**: Attende 20µs per debounce meccanico
3. **RELEASE**: Muove in avanti finché `limit='1'` (rilasciato)
4. **OFFSET**: Muove ulteriori 200 steps (distanza limite→zero)
5. **SET_ZERO**: Imposta `position = 0` (questo è il nuovo home)
6. **COMPLETE**: Segnala `axis_homed='1'` → abilita prossimo asse

**Parametri configurabili:**
- `OFFSET_STEPS`: Distanza dal limite al punto zero (default 200)
- `STEP_PERIOD_CYC`: Periodo step in clock cycles (default 5000 = 100µs)
- `AXIS_NAME`: Nome asse per debug ("X", "Y", "Z")

#### 3. **reset_z.vhd** - Reset automatico asse Z (legacy)
Versione semplificata per solo asse Z (usato in test iniziali).

**Funzionalità:**
- Wait 1ms dopo reset
- Muove Z verso `limit_min_z`
- Si ferma quando limite hit
- Segnala `pos_z_zero='1'`

**Nota:** Sostituito da `homing_sequence_v2` per operazioni complete.

### Test Coverage

#### Test principale: **tb_homing_sequence_v2.vhd**
Testbench completo che verifica:

**Test 1: Z Axis Homing**
- [1.1] Z HOMING phase: movimento verso limite
- [1.2] Hit detection: `limit_min_z='0'` → DEBOUNCE
- [1.3] RELEASE phase: rilascio switch
- [1.4] OFFSET phase: 200 steps forward
- [1.5] Verifica: `pos_z_zero='1'`, `pos_z=0`

**Test 2: Y Axis Homing** (triggered by `pos_z_zero='1'`)
- [2.1] Y HOMING phase (X ancora disabilitato)
- [2.2-2.4] Stesse fasi di Z
- [2.5] Verifica: `pos_y_zero='1'`, `pos_y=0`

**Test 3: X Axis Homing** (triggered by `pos_y_zero='1'`)
- [3.1] X HOMING phase
- [3.2-3.4] Stesse fasi di Y
- [3.5] Verifica: `pos_x_zero='1'`, `pos_x=0`, `all_axes_homed='1'`

**Metriche verificate:**
- ✅ Conteggio steps per fase (homing, release, offset)
- ✅ Verifica offset ≈ 200 steps (190-210 tolleranza)
- ✅ Posizioni finali = 0 per tutti gli assi
- ✅ Sequenza cascata corretta (Z→Y→X)
- ✅ Timing: ~60ms per asse completo

**Output testbench (ultimo test: 2025-10-16 21:07):**
```
=== HOMING SEQUENCE V2 TEST (WITH RELEASE + OFFSET) ===
[TEST 1] Z AXIS HOMING SEQUENCE
  Z axis: homing=50, release=19, offset=200 steps
  pos_z = 0, pos_z_zero = '1' OK

[TEST 2] Y AXIS HOMING SEQUENCE
  Y axis: homing=109, release=19, offset=200 steps
  pos_y = 0, pos_y_zero = '1' OK

[TEST 3] X AXIS HOMING SEQUENCE
  X axis: homing=109, release=19, offset=200 steps
  pos_x = 0, pos_x_zero = '1' OK

*** ALL TESTS PASS ***
Errors: 0, Warnings: 0
System ready for ROM controller operation
```

**Note:** Testbench corretto con delay di 100ns per propagazione segnale `dir` attraverso `step_dir_generator`.

### Integrazione con sistema esistente

**Segnale chiave: `pos_x_zero`**
```vhdl
-- In homing_sequence_v2:
pos_x_zero <= x_homed;  -- High when X homing complete

-- In future top-level integration:
rom_enable <= pos_x_zero;  -- ROM starts only after all axes homed
```

**Flusso operativo completo:**
```
1. Power-on / Reset
2. Homing sequence starts automatically (Z→Y→X)
3. When all_axes_homed='1' → ROM controller enabled
4. ROM playback starts → 24-position trajectory
5. System operational
```

### Risorse utilizzate (stimate)

| Componente | Logic Elements | Note |
|------------|----------------|------|
| `homing_sequence_v2` | ~150 LE | 3× axis_homing instances + control |
| `axis_homing_v3` (×3) | ~400 LE | State machine + step_dir_generator |
| **Totale homing** | **~550 LE** | ~9% del totale disponibile (6272 LE) |

**Memoria:** Nessuna RAM aggiuntiva (solo registri)

### Vantaggi del sistema implementato

✅ **Affidabilità**: Debounce hardware + procedura RELEASE evita problemi meccanici
✅ **Ripetibilità**: Offset fisso di 200 steps garantisce posizione zero costante
✅ **Sicurezza**: Sequenza cascata evita collisioni (Z si alza prima di X/Y)
✅ **Flessibilità**: Parametri configurabili (offset, timing, sequenza)
✅ **Testabilità**: Testbench completo con verifica automatica
✅ **Integrazione**: Segnali `pos_x/y/z_zero` si integrano con ROM controller

### Note operative

**Configurazione limit switches:**
- Segnali **active low**: `'0'` = limite raggiunto, `'1'` = libero
- Solo `limit_min` usati (homing verso minimo)
- `limit_max` opzionali (per sicurezza durante operazione normale)

**Timing:**
- Step period: 100µs (10,000 steps/sec)
- Debounce: 20µs
- Tempo totale homing (esempio): ~60ms per asse @ 500 steps
- Sequenza completa Z+Y+X: ~180ms

**Stato corrente (2025-10-16):**
- ✅ Sistema di homing **testato e verificato** (0 errors, 0 warnings)
- ✅ Testbench corretto (timing fix per verifica direzione)
- ✅ Segnale `all_axes_homed_n` aggiunto per pilotaggio LED
- ✅ Compilazione VHDL-93 completa senza errori

**Prossimi passi:**
- ⏭️ Integrare homing in `cnc_3axis_rom_top.vhd`
- ⏭️ Aggiungere pin `homing_enable` / `start_homing`
- ⏭️ Collegare `all_axes_homed` → `rom_enable`

---

## 🚀 Quick Start

### Prerequisites
- **ModelSim** or **Quartus Prime** (with built-in simulator)
- **VHDL-93** compiler
- **Quartus Prime Lite** (for synthesis/programming)

### 1. Compile RTL (VHDL-93)
```bash
cd rtl/
vcom -93 cnc_pkg.vhd
vcom -93 encoder_decoder.vhd
vcom -93 encoder_simulator.vhd
vcom -93 bresenham_axis.vhd
vcom -93 step_dir_generator.vhd
vcom -93 cnc_3axis_controller.vhd
vcom -93 trajectory_rom.vhd
vcom -93 rom_controller.vhd
vcom -93 cnc_3axis_rom_top.vhd
```

### 2. Run Simulations

**Test homing system (recommended first):**
```bash
cd ../sim/
vcom -93 tb_homing_sequence_v2.vhd
vsim -c work.tb_homing_sequence_v2 -do "run 100 ms; quit -f"
```
Expected output: **ALL TESTS PASS**, all 3 axes homed (Z→Y→X)

**Test ROM playback (closed-loop):**
```bash
vcom -93 tb_rom_simple.vhd
vsim -c work.tb_rom_simple -do "run 5 ms; quit -f"
```
Expected output: **Closed-loop test PASS**, encoder feedback working

**Test ROM 24-position geometry:**
```bash
vcom -93 tb_rom_24positions.vhd
vsim -c work.tb_rom_24positions -do "run 1 ms; quit -f"
```
Expected output: ROM content verified, cube+pyramid geometry OK

### 3. Synthesize with Quartus
1. Open Quartus Prime
2. Create new project in `quartus/` directory
3. Add all files from `rtl/` to project
4. Set top-level entity: **`cnc_3axis_rom_top`** (not cnc_3axis_controller)
5. Run **Analysis & Synthesis**
6. Check resource usage: ~1850 LE (29% of 6272)

### 4. Verify Timing
- Run **TimeQuest Timing Analyzer**
- Target Fmax: **50 MHz**
- Ensure all paths have **positive slack**

### 5. Program FPGA
- Generate `.sof` file (Assembler)
- Program via JTAG (USB Blaster)
- Set `open_loop = '0'` for testing (uses internal encoder simulation)
- Set `open_loop = '1'` for hardware (uses external encoders)

---

## 📊 Hardware Requirements

### FPGA Resources (Estimated)

| Resource | Used | Available | Usage |
|----------|------|-----------|-------|
| Logic Elements (LE) | ~2400 | 6272 | 38% |
| RAM bits (M4K blocks) | 288 bytes | 276,480 | <1% |
| Pins | 39 | 144 | 27% |

**Breakdown:**
- CNC core (Bresenham + Step/Dir + Encoders): ~1650 LE
- ROM (24 positions) + controller: ~200 LE
- Homing system (3 axes): ~550 LE
- Total: **~2400 LE (38% utilizzo)**

**Note:** ROM usa 288 bytes (24 posizioni × 3 assi × 4 bytes), molto efficiente in Block RAM M4K.

### External Connections

**Inputs (26 pins):**
- 2× System (clk, rst)
- 3× Control (enable, pause, open_loop)
- 6× Encoder channels (A/B for X/Y/Z) - optional if open_loop=0
- 6× Limit switches (min/max for X/Y/Z)

**Outputs (13 pins):**
- 9× Motor driver signals (STEP/DIR/ENABLE for X/Y/Z)
- 7× Status (busy, fault, state_debug[3:0], sequence_active, sequence_done)
- 6× Debug (current_step[5:0])

**Total: 39 pins** ✅ Fits in EP4CE6E22C8N (144-pin EQFP)

---

## 🔌 Interface Summary (ROM-Based Design)

### Control Signals
| Signal | Type | Description |
|--------|------|-------------|
| `clk` | Input | 50 MHz system clock |
| `rst` | Input | Async reset (active high) |
| `enable` | Input | Master enable + ROM playback enable |
| `pause` | Input | Pause ROM playback |
| `open_loop` | Input | 0=simulated encoders, 1=external encoders |

### Movement Parameters (Internal - No Pins)
- `target_x/y/z`: From ROM, calculated as delta from previous position
- `step_period`: Fixed at 5000 (10,000 steps/sec @ 50MHz)

### Status Outputs
| Signal | Type | Description |
|--------|------|-------------|
| `busy` | Output | Movement in progress |
| `fault` | Output | Error detected (limit hit, encoder error) |
| `state_debug[3:0]` | Output | CNC state machine debug |
| `sequence_active` | Output | ROM playback active |
| `sequence_done` | Output | Sequence complete (ONE_SHOT mode) |
| `current_step[5:0]` | Output | Current ROM position (0-63) |

### Motor Outputs (9 pins)
| Signal | Per Axis | Description |
|--------|----------|-------------|
| `step_x/y/z` | 1-bit | Step pulse (5µs width) |
| `dir_x/y/z` | 1-bit | Direction (1=CW, 0=CCW) |
| `enable_x/y/z` | 1-bit | Enable signal |

---

## 🎓 Key Concepts

### ROM-Based Trajectory
The design uses **pre-programmed positions** stored in Block RAM:
- **64 positions** @ 32-bit per axis (X, Y, Z)
- **Absolute coordinates** stored in ROM
- **Relative deltas** calculated by rom_controller
- **Auto-sequencing**: Loads next position when movement completes
- **Loop mode**: Infinite repetition for continuous operation

### Encoder Simulation (Closed-Loop Testing)
- **Purpose:** Realistic testing without external hardware
- **Input:** Monitors STEP/DIR/ENABLE from motor outputs
- **Output:** Generates quadrature A/B signals
- **Delay:** 10µs (500 cycles @ 50MHz) - realistic mechanical lag
- **Direction:** Follows DIR signal (forward/reverse)
- **Freeze:** Stops when enable=0

### Bresenham Algorithm
The controller uses **Bresenham's line algorithm** for 3D interpolation:
- **Major axis:** Largest displacement (always steps)
- **Minor axes:** Step when error accumulator crosses threshold
- **Result:** Perfect linear interpolation in 3D space

---

## 🧪 Testing

### Testbench Coverage

#### 1. **tb_bresenham.vhd** - Bresenham core tests (6 cases)
- All 6 tests PASS ✅
- Covers positive/negative, diagonal, edge cases, timing

#### 2. **tb_homing_sequence_v2.vhd** - Full 3-axis homing ✨ **NEW**
- Tests complete Z→Y→X cascade sequence
- Verifies: HOMING → DEBOUNCE → RELEASE → OFFSET → SET_ZERO → COMPLETE
- Validates offset accuracy (±5% tolerance on 200 steps)
- **Result:** All 3 axes homed, positions = 0, PASS ✅

#### 3. **tb_reset_z.vhd** - Z-axis automatic reset ✨ **NEW**
- Tests single-axis homing (Z only)
- Verifies 1ms wait after reset
- **Result:** Z homed to limit_min, PASS ✅

#### 4. **tb_rom_24positions.vhd** - ROM geometry verification ✨ **NEW**
- Verifies 24-position ROM content (cube + pyramid)
- Checks coordinate correctness
- **Result:** Geometry verified, PASS ✅

#### 5. **tb_rom_simple.vhd** - Closed-loop ROM playback
- Tests ROM sequencer with encoder simulation
- Verifies closed-loop feedback
- **Result:** First 5 positions executed, PASS ✅

#### 6. **tb_rom_full.vhd** - Full 24-position playback
- Complete trajectory execution test
- Verifies all 24 positions
- **Result:** Full sequence PASS ✅

### Test Summary

| Metric | Value |
|--------|-------|
| **Bresenham Tests** | 6/6 PASS ✅ |
| **Homing Tests** | 3/3 axes PASS ✅ **NEW** |
| **ROM Geometry Tests** | 24/24 positions verified ✅ **NEW** |
| **ROM Playback Tests** | 5/5 positions PASS ✅ |
| **Compilation** | VHDL-93, 0 errors, 0 warnings |
| **Closed-Loop** | Encoder feedback working ✅ |
| **Timing Error** | <0.2% |
| **Homing Timing** | ~180ms for Z+Y+X cascade ✅ **NEW** |

---

## 🏁 Current Project State

✅ **READY FOR SYNTHESIS**
- ROM-based design complete (solves pin count issue)
- **HOMING SYSTEM COMPLETE** ✨ NEW (Z→Y→X cascade with release+offset)
- Closed-loop testing successful with encoder simulation
- Code compiles without errors (VHDL-93)
- All testbenches pass (homing + ROM + Bresenham)
- Only 39 pins required (fits in 144-pin FPGA)
- Resource usage: 38% LE, <1% RAM

✅ **TESTED FEATURES**
- ✅ **Automatic homing system (Z→Y→X)** with RELEASE + OFFSET ✨ **NEW (2025-10-16)** ✅ **VERIFIED**
  - Testbench completo con 0 errori, 0 warning
  - Timing corrected (100ns delay for dir signal propagation)
  - LED output signal (`all_axes_homed_n`) added
- ✅ ROM trajectory storage (**24 positions**, cube + double pyramid geometry) **UPDATED**
- ✅ Automatic sequencing with relative delta calculation
- ✅ Encoder simulation (10µs delay, Gray code)
- ✅ Closed-loop feedback (step → encoder → decoder → controller)
- ✅ open_loop pin MUX (simulated vs external encoders)
- ✅ State machine debug outputs per axis

✅ **COMPLETED FROM REDESIGN PLAN (2025-10-13)**
- ✅ Task 1: ROM geometry updated (64 → 24 positions)
- ✅ Task 2: cnc_pkg.vhd updated (ROM_SIZE=24, ROM_ADDR_WIDTH=5)
- ⏭️ Task 3-14: RAM/SPI interface **PENDING** (next phase)

⚠️ **OPTIONAL ENHANCEMENTS** (Future)
- Parametric encoder delay (currently fixed 10µs)
- SPI/UART interface (for runtime position updates) ← **NEXT PRIORITY**
- Acceleration profiles (currently constant velocity)
- Dual-buffer RAM mode (requires more resources)

🚀 **NEXT MILESTONE**
**Phase 2-5: RAM/SPI Implementation** (from redesign plan 2025-10-13)
- RAM implementation (2048 positions)
- SPI parallel interface (4-bit data bus)
- Test pin (ROM/RAM selector)
- Enhanced reset logic + run control

---

## 🔄 NEW REQUIREMENTS (2025-10-13) - TO BE IMPLEMENTED

### ⚠️ Git Status
- Repository cleaned up
- **IMPORTANT:** Ask before adding new files to git

### 📋 Task List - Major Redesign

#### 1. **ROM Geometry Update (24 positions)** ✅ **COMPLETED (2025-10-16)**
**File modified:** `rtl/trajectory_rom.vhd`

**New geometry:**
- Total positions: **24** (was 64)
- Cube + Double Pyramid inscribed structure:
  - **Cube external:** 2000×2000×2000 (8 vertices)
  - **Pyramid inferior (base down):** 1000×1000×1000 base, vertex at center (0,0,0) (5 points: 4 base vertices + 1 center vertex)
  - **Pyramid superior (base up):** 1000×1000×1000 base, vertex at center (0,0,0) (5 points: 4 base vertices + 1 center vertex)
  - The two pyramid vertices touch at center (0,0,0)
  - **Last position:** (0, 0, 0)

**Coordinate calculation (assuming center cube at origin):**

```
Cube vertices (8 positions):
  1. (-1000, -1000, -1000)  # Bottom-front-left
  2. (+1000, -1000, -1000)  # Bottom-front-right
  3. (+1000, +1000, -1000)  # Bottom-back-right
  4. (-1000, +1000, -1000)  # Bottom-back-left
  5. (-1000, -1000, +1000)  # Top-front-left
  6. (+1000, -1000, +1000)  # Top-front-right
  7. (+1000, +1000, +1000)  # Top-back-right
  8. (-1000, +1000, +1000)  # Top-back-left

Inferior pyramid (base at bottom, 5 positions):
  9.  (-500, -500, -1000)   # Base vertex 1
  10. (+500, -500, -1000)   # Base vertex 2
  11. (+500, +500, -1000)   # Base vertex 3
  12. (-500, +500, -1000)   # Base vertex 4
  13. (   0,    0,     0)   # Vertex (center)

Superior pyramid (base at top, 5 positions):
  14. (-500, -500, +1000)   # Base vertex 1
  15. (+500, -500, +1000)   # Base vertex 2
  16. (+500, +500, +1000)   # Base vertex 3
  17. (-500, +500, +1000)   # Base vertex 4
  18. (   0,    0,     0)   # Vertex (center) - same as #13

Total unique positions: 18
Add 5 intermediate positions to reach 23, then:
  24. (0, 0, 0)             # Final return home
```

**Visit order:** Optimize for shortest path (minimize travel distance)

**Changes completed:**
- ✅ ROM size updated: 24 positions × 3 axes × 32 bits = 2304 bits (288 bytes)
- ✅ Address width updated: 5 bits (0-23, was 6 bits for 0-63)
- ✅ Trajectory order optimized for minimal travel distance
- ✅ `cnc_pkg.vhd` constants updated (ROM_SIZE=24, ROM_ADDR_WIDTH=5)

---

#### 2. **RAM Implementation (2048 positions)** 🔴 TODO
**New file:** `rtl/trajectory_ram.vhd`

**Specifications:**
- Size: **2048 positions** (2^11)
- Data format: 3 × 32-bit per position (X, Y, Z) = 96 bits/position
- Total RAM: 2048 × 96 = 196,608 bits (~24 KB)
- Available RAM: 276,480 bits (Cyclone IV), usage: 71% (within margin)
- Address width: 11 bits (0-2047)
- Port configuration:
  - **Port A (write):** External SPI interface writes here
  - **Port B (read):** CNC controller reads positions sequentially
- Dual-port Block RAM (M9K)
- Write enable controlled by SPI interface
- Synchronous read/write

**Future enhancement:** Dual-buffer mode (ping-pong)
- Buffer 0: CNC reads (active processing)
- Buffer 1: SPI writes (data loading)
- Swap buffers on command
- Requires 2× RAM (393,216 bits = 142% available) ⚠️ **NOT FEASIBLE NOW**
- Defer to future when requested

---

#### 3. **SPI Parallel Interface (4-bit data bus)** 🔴 TODO
**New file:** `rtl/spi_parallel_interface.vhd`

**Interface signals:**
- `spi_clk` : Input - SPI clock from external microprocessor
- `spi_cs` : Input - Chip Select (active low)
- `spi_wr` : Input - Write enable (active high)
- `spi_data[3:0]` : Input - 4-bit parallel data bus
- `spi_addr[10:0]` : Input - RAM address (11 bits for 2048 positions)
- `spi_axis[1:0]` : Input - Axis select (00=X, 01=Y, 10=Z, 11=reserved)
- `spi_byte_sel[1:0]` : Input - Byte select within 32-bit word (0-3)

**Protocol:**
1. External µP asserts `spi_cs = '0'`
2. Sets address (`spi_addr`), axis (`spi_axis`), byte selector (`spi_byte_sel`)
3. Places data on `spi_data[3:0]` (4 bits)
4. Pulses `spi_wr = '1'` for 1+ clock cycles
5. Repeats for all bytes of position (8 nibbles per axis, 24 nibbles total per position)
6. De-asserts `spi_cs = '1'` when done

**Total pins for SPI interface:**
- 1× spi_clk
- 1× spi_cs
- 1× spi_wr
- 4× spi_data[3:0]
- 11× spi_addr[10:0]
- 2× spi_axis[1:0]
- 2× spi_byte_sel[1:0]
- **Total: 21 pins**

**State machine:**
- IDLE: Wait for `spi_cs = '0'`
- WRITE: On `spi_wr` rising edge, write nibble to RAM at specified position/axis/byte
- Reconstruct 32-bit word from 8 nibbles (requires temporary holding register per axis)

---

#### 4. **TEST Pin - ROM/RAM Selector** 🔴 TODO
**Files to modify:** `rtl/rom_controller.vhd`, `rtl/cnc_3axis_rom_top.vhd` (or create new top)

**New pin:**
- `test` : Input - Source selector
  - `test = '0'` → Use internal ROM (24 positions, fixed geometry)
  - `test = '1'` → Use external RAM (2048 positions, loaded via SPI)

**Implementation:**
- Add MUX in memory controller
- Select ROM or RAM output based on `test` signal
- ROM address: 5 bits (0-23)
- RAM address: 11 bits (0-2047)
- Use unified controller interface (target_x/y/z outputs)

---

#### 5. **Enhanced RESET Logic with READY Signal** 🔴 TODO
**Files to modify:** `rtl/cnc_3axis_controller.vhd`, top-level

**New behavior:**

```
RESET active (rst='1'):
  - All motor outputs: step/dir/enable = '0'
  - State machine → RESET state
  - Timer reset
  - Ready signal: ready = '0'

RESET released (rst='0'):
  - Wait 1 second (50,000,000 clock cycles @ 50 MHz)
  - After 1 second: ready = '1'
  - Ready remains HIGH until next reset
  - Only after ready='1' can processing start

State transitions:
  RESET → WAIT_READY (1s timer) → IDLE (ready='1') → LOAD_POSITION (when run activated)
```

**New output pin:**
- `ready` : Output - System ready indicator (HIGH after 1s post-reset)

---

#### 6. **RUN Control with Dual Outputs** 🔴 TODO
**Files to modify:** Top-level, rom_controller or new sequencer

**New pins:**
- `run` : Input - Start processing (active LOW)
- `run_led` : Output - LED indicator (inverted from run state)
- `run_ack` : Output - Acknowledge to microprocessor (opposite of run_led)

**Logic:**

```
When ready='1' AND run='0' (active):
  - Start sequence processing (ROM or RAM based on test pin)
  - run_led = '0' (LED ON, active low)
  - run_ack = '1' (acknowledge to µP)
  - State machine: IDLE → LOAD_POSITION → MOVING → ...

When sequence completes:
  - Stop at last position
  - run_led = '1' (LED OFF)
  - run_ack = '0'
  - Wait for next run='0' pulse to restart

Behavior:
  - Single-shot mode (no auto-loop)
  - Requires new run='0' pulse after each sequence completion
  - ready must be '1' before run can start processing
```

---

#### 7. **Updated Pin Assignment** 🔴 TODO
**File to modify:** `constraints/EP4CE6E22C8N.qsf`

**New pin count estimate:**

```
System & Control:
  - 1× clk (50 MHz)
  - 1× rst (active high)
  - 1× test (ROM/RAM selector)
  - 1× run (active low)
  - 1× open_loop (encoder source: sim/external)
  Total: 5 pins

SPI Interface (when test='1'):
  - 1× spi_clk
  - 1× spi_cs
  - 1× spi_wr
  - 4× spi_data[3:0]
  - 11× spi_addr[10:0]
  - 2× spi_axis[1:0]
  - 2× spi_byte_sel[1:0]
  Total: 21 pins

Encoders (when open_loop='1'):
  - 6× enc_a/b_x/y/z
  Total: 6 pins

Limit Switches:
  - 6× limit_min/max_x/y/z
  Total: 6 pins

Motor Outputs:
  - 9× step/dir/enable for X/Y/Z
  Total: 9 pins

Status/Debug:
  - 1× ready
  - 1× run_led
  - 1× run_ack
  - 1× busy
  - 1× fault
  - 1× sequence_active
  - 1× sequence_done
  - 4× state_debug[3:0]
  Total: 11 pins

Optional Debug:
  - 11× current_addr[10:0] (RAM address display)
  Total: 11 pins (optional)

TOTAL (without optional debug): 5 + 21 + 6 + 6 + 9 + 11 = 58 pins
TOTAL (with optional debug): 58 + 11 = 69 pins
```

**Pin usage: 58-69 pins (40-48% of 144 available)** ✅ Acceptable

---

#### 8. **Updated Architecture Diagram** 📝 TODO

```
┌──────────────────────────────────────────────────────────────────────┐
│                     cnc_3axis_hybrid_top (NEW TOP)                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐          ┌──────────────┐                        │
│  │trajectory_rom│          │trajectory_ram│                        │
│  │ 24 positions │          │2048 positions│                        │
│  │   (288 B)    │          │  (24 KB)     │                        │
│  └──────┬───────┘          └──────┬───────┘                        │
│         │                         │                                 │
│         │                         │ ▲                               │
│         │                         │ │ write                         │
│         │                         │ │                               │
│         │                  ┌──────┴─┴─────────┐                    │
│         │                  │  spi_parallel_   │                    │
│         │                  │    interface     │                    │
│         │                  │  (4-bit data)    │                    │
│         │                  └──────────────────┘                    │
│         │                         ▲                                 │
│         │                         │ SPI pins (21)                   │
│         │                         │                                 │
│         └─────────┬───────────────┘                                 │
│                   │                                                 │
│                   ▼                                                 │
│         ┌─────────────────┐                                         │
│         │   test MUX      │  (test pin: 0=ROM, 1=RAM)              │
│         │   ROM/RAM       │                                         │
│         └────────┬────────┘                                         │
│                  │ position data                                    │
│                  ▼                                                  │
│         ┌─────────────────┐                                         │
│         │ memory_sequencer│  (enhanced rom_controller)             │
│         │  - run control  │                                         │
│         │  - ready logic  │                                         │
│         │  - 1s timer     │                                         │
│         └────────┬────────┘                                         │
│                  │ target_x/y/z (relative)                          │
│                  ▼                                                  │
│         ┌──────────────────────────────────┐                       │
│         │    cnc_3axis_controller          │                       │
│         │  (Bresenham + Step/Dir + Enc)    │                       │
│         └──┬───────────────────┬───────────┘                       │
│            │ STEP/DIR/EN       │ ENC_A/B                            │
│            ▼                   ▼                                    │
│    ┌──────────┐       ┌────────────────┐                           │
│    │ Motors   │       │  open_loop MUX │                           │
│    │(outputs) │       │  (sim or ext)  │                           │
│    └──────────┘       └────────┬───────┘                           │
│                                │                                    │
│                     ┌──────────┴────────────┐                      │
│                     │                       │                      │
│                     ▼                       ▼                      │
│              ┌─────────────┐        ┌────────────┐                │
│              │  encoder_   │        │  External  │                │
│              │  simulator  │        │  Encoders  │                │
│              │  (3 axes)   │        │  (A/B × 3) │                │
│              └─────────────┘        └────────────┘                │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Control Flow:
1. Reset → Wait 1s → ready='1'
2. run='0' (active) → Start sequence from position 0
3. Read position from ROM or RAM (based on test pin)
4. Execute movement (Bresenham)
5. Advance to next position
6. Repeat until last position
7. Stop → run_led='1', run_ack='0' (idle)
8. Wait for next run pulse
```

---

#### 9. **Files to Create** 📝

1. `rtl/trajectory_ram.vhd` - Dual-port RAM (2048 positions)
2. `rtl/spi_parallel_interface.vhd` - 4-bit parallel SPI interface
3. `rtl/memory_sequencer.vhd` - Enhanced ROM/RAM controller with run/ready logic
4. `rtl/cnc_3axis_hybrid_top.vhd` - New top-level with ROM/RAM/SPI
5. `sim/tb_spi_interface.vhd` - Testbench for SPI writes
6. `sim/tb_hybrid_system.vhd` - Full system test (ROM mode + RAM mode)

---

#### 10. **Files to Modify** 📝

1. `rtl/trajectory_rom.vhd` - Update to 24 positions with cube+pyramid geometry
2. `rtl/cnc_pkg.vhd` - Update constants (ROM_SIZE=24, RAM_SIZE=2048, address widths)
3. `rtl/cnc_3axis_controller.vhd` - Add RESET→WAIT_READY→IDLE state transition with 1s timer
4. `constraints/EP4CE6E22C8N.qsf` - Update pin assignments (58-69 pins)
5. `CLAUDE.md` - This file (updated ✅)

---

#### 11. **Simulation Strategy** 🧪

**Test sequence:**

1. **Test ROM mode (test='0'):**
   - Reset → wait 1s → check ready='1'
   - Pulse run='0' → verify 24 positions executed
   - Check run_led and run_ack signals
   - Verify cube+pyramid trajectory

2. **Test RAM mode (test='1'):**
   - Load 10 test positions via SPI (write nibbles)
   - Reset → ready → run
   - Verify positions read from RAM correctly
   - Check sequence stops after position 9

3. **Test SPI interface:**
   - Write full 32-bit position (8 nibbles × 3 axes = 24 nibbles)
   - Read back from RAM
   - Verify data integrity

4. **Test reset timing:**
   - Assert reset → check all motors disabled
   - Release reset → measure 1s delay
   - Verify ready='1' after exactly 50M cycles

---

#### 12. **Resource Estimation** 📊

| Resource | Current | New Design | Available | Usage |
|----------|---------|------------|-----------|-------|
| Logic Elements (LE) | ~1850 | ~2500 | 6272 | 40% |
| RAM bits (M9K) | 2,304 | 196,608 | 276,480 | 71% |
| Pins | 39 | 58-69 | 144 | 40-48% |

**Notes:**
- RAM usage: 71% (within spec, 10% margin used)
- Dual-buffer mode would require 142% RAM ⚠️ **NOT FEASIBLE** - defer to future
- Pin count increased from 39 to 58-69 due to SPI interface (21 pins)
- LE increase due to SPI controller, memory MUX, enhanced sequencer

---

#### 13. **Implementation Priority** 🎯

**Phase 1 - Core Memory System:**
1. Update `cnc_pkg.vhd` with new constants
2. Modify `trajectory_rom.vhd` to 24 positions (cube+pyramid)
3. Create `trajectory_ram.vhd` (2048 positions, dual-port)
4. Create `memory_sequencer.vhd` with ROM/RAM MUX

**Phase 2 - SPI Interface:**
5. Create `spi_parallel_interface.vhd`
6. Integrate SPI → RAM write path
7. Create `tb_spi_interface.vhd` testbench

**Phase 3 - Control Logic:**
8. Update `cnc_3axis_controller.vhd` with RESET→READY logic (1s timer)
9. Add run/run_led/run_ack control to memory_sequencer
10. Create new top-level `cnc_3axis_hybrid_top.vhd`

**Phase 4 - Integration & Test:**
11. Update pin constraints `EP4CE6E22C8N.qsf`
12. Create `tb_hybrid_system.vhd` full system testbench
13. Simulate ROM mode + RAM mode
14. Synthesize and verify timing/resources

**Phase 5 - Documentation:**
15. Update `INTERFACE_SPEC.md`
16. Create `REDESIGN_2025_10_13.md` with change log
17. Update `CLAUDE.md` (this file) when complete

---

#### 14. **Cube + Pyramid Geometry Details** 📐

**Visual representation:**

```
        Top view (Z=+1000):

        Superior pyramid base
        ┌─────────────────┐
        │  14          15 │
        │     \     /     │
        │       \ /       │
        │   17   *   18   │  * = vertex (0,0,0)
        │       / \       │
        │     /     \     │
        │  16          17 │
        └─────────────────┘


        Middle (Z=0):
        Center point (0, 0, 0)
        Vertices #13 and #18 meet here


        Bottom view (Z=-1000):

        Inferior pyramid base
        ┌─────────────────┐
        │   9          10 │
        │     \     /     │
        │       \ /       │
        │   12   *   11   │  * = vertex (0,0,0)
        │       / \       │
        │     /     \     │
        │  12          9  │
        └─────────────────┘


        Cube vertices (8 corners):
        Z=-1000: (±1000, ±1000, -1000)  [positions 1-4]
        Z=+1000: (±1000, ±1000, +1000)  [positions 5-8]
```

**Trajectory order (optimized for minimal travel):**
```
Start: (0, 0, 0)
1. Cube bottom-front-left
2. Cube bottom-front-right
3. Cube bottom-back-right
4. Cube bottom-back-left
5. Return to origin (traverse inferior pyramid vertex)
6. Inferior pyramid base vertex 1
7. Inferior pyramid base vertex 2
8. Inferior pyramid base vertex 3
9. Inferior pyramid base vertex 4
10. Back to origin (center)
11. Superior pyramid base vertex 1
12. Superior pyramid base vertex 2
13. Superior pyramid base vertex 3
14. Superior pyramid base vertex 4
15. Back to origin
16. Cube top-front-left
17. Cube top-front-right
18. Cube top-back-right
19. Cube top-back-left
20. Diagonal to bottom-front-left
21. Diagonal to top-back-right
22. Diagonal to bottom-back-left
23. Diagonal to top-front-right
24. Final return to origin (0, 0, 0)
```

---

## 📝 Summary of Changes

### What's staying the same:
- ✅ Bresenham interpolation algorithm
- ✅ Encoder decoder (quadrature feedback)
- ✅ Step/Dir pulse generator
- ✅ Encoder simulator
- ✅ CNC core controller logic
- ✅ VHDL-93 compatibility
- ✅ 50 MHz clock, deterministic timing

### What's IMPLEMENTED (2025-10-16):
- ✅ **ROM updated**: 64 → 24 positions (cube + double pyramid geometry)
- ✅ **cnc_pkg.vhd updated**: ROM_SIZE=24, ROM_ADDR_WIDTH=5
- ✅ **Automatic homing system**: Z→Y→X cascade with RELEASE + OFFSET (200 steps)
- ✅ **3 new RTL modules**: homing_sequence_v2, axis_homing_v3, reset_z
- ✅ **4 new testbenches**: tb_homing_sequence_v2, tb_reset_z, tb_rom_24positions, tb_rom_full
- ✅ **Resource usage**: 38% LE (~2400 LE), <1% RAM (288 bytes)

### What's PENDING (next phase):
- 🔄 RAM implementation: 2048 positions (71% of available RAM)
- 🔄 SPI parallel interface (4-bit data bus, 21 pins)
- 🔄 TEST pin (ROM/RAM selector)
- 🔄 Enhanced reset logic (1s delay → ready signal)
- 🔄 RUN control (active low, dual outputs: run_led + run_ack)
- 🔄 Single-shot mode (no auto-loop, requires run pulse per sequence)
- 🔄 Pin count expansion: 39 → 58-69 pins (still 40-48% of 144 available)

### Future enhancements (NOT in this phase):
- ⏭️ Integrate homing with ROM controller (automatic flow: homing → ROM playback)
- ⏭️ Dual-buffer RAM (ping-pong) - requires 2× RAM (not enough space now)
- ⏭️ Acceleration profiles
- ⏭️ Variable encoder delay
- ⏭️ UART interface (alternative to SPI)

---

🚀 **NEXT MILESTONE - Phase 2-5 Implementation**
Implement RAM + SPI interface + TEST pin + Enhanced control logic → Simulate → Synthesize → Hardware test

---

## 🔮 Architecture Overview (Current Implementation)

```
┌─────────────────────────────────────────────────────────────────┐
│                    cnc_3axis_rom_top (TOP)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐                                             │
│  │ trajectory_rom│ (768 bytes, 64 positions)                   │
│  │   X/Y/Z ROM   │                                             │
│  └───────┬───────┘                                             │
│          │ abs positions                                        │
│          ▼                                                      │
│  ┌───────────────┐                                             │
│  │rom_controller │ (sequencer + delta calculator)             │
│  │  - Auto-advance                                             │
│  │  - Calc relative deltas                                     │
│  └───────┬───────┘                                             │
│          │ target_x/y/z (relative)                             │
│          ▼                                                      │
│  ┌─────────────────────────────────────────────────┐           │
│  │         cnc_3axis_controller                    │           │
│  │  (Bresenham + Step/Dir + Encoder Decoder)       │           │
│  └──┬──────────────────┬─────────────────┬─────────┘           │
│     │ STEP/DIR/EN      │                 │ ENC_A/B             │
│     ▼                  │                 ▼                     │
│  ┌────────────┐        │         ┌──────────────┐             │
│  │  To Motors │        │         │  From MUX    │             │
│  │  (outputs) │        │         │ (sim or ext) │             │
│  └────────────┘        │         └──────▲───────┘             │
│                        │                │                      │
│                        │         ┌──────┴───────┐             │
│                        │         │  open_loop   │             │
│                        │         │     MUX      │             │
│                        │         │ 0=sim 1=ext  │             │
│                        │         └──┬───────┬───┘             │
│                        │            │       │                  │
│                        │  ┌─────────┘       └────────┐         │
│                        │  │                          │         │
│                        │  ▼                          ▼         │
│                        │ ┌─────────────┐    ┌────────────┐    │
│                        │ │  encoder_   │    │  External  │    │
│                        └►│  simulator  │    │  Encoders  │    │
│                          │  (3 axes)   │    │  (A/B × 3) │    │
│                          │  +10us delay│    └────────────┘    │
│                          └─────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 💡 Usage Example (ROM-Based)

### Hardware Setup

```vhdl
-- Connect to FPGA:
clk         : 50 MHz oscillator
rst         : Push button (active high)
enable      : DIP switch (1=run, 0=stop)
pause       : Push button (1=pause)
open_loop   : DIP switch (0=testing, 1=hardware)

-- Motors: TB6600 drivers
step_x/y/z  : To STEP+ pins
dir_x/y/z   : To DIR+ pins
enable_x/y/z: To ENA+ pins

-- Encoders (if open_loop='1'):
enc_a/b_x/y/z : From quadrature encoders

-- Limits (optional):
limit_min/max_x/y/z : From mechanical limit switches

-- Status LEDs:
busy        : LED (movement in progress)
fault       : LED (error detected)
```

### Testing Mode (open_loop = '0')
1. Set `open_loop = '0'` (simulated encoders)
2. Set `enable = '1'`
3. Watch motors execute 64-position sequence
4. Encoder simulation provides closed-loop feedback
5. Sequence repeats infinitely (LOOP_MODE=true)

### Hardware Mode (open_loop = '1')
1. Connect real encoders to enc_a/b pins
2. Set `open_loop = '1'` (external encoders)
3. Set `enable = '1'`
4. Real encoder feedback used for position control

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `cnc_fpga.md` | Original design document |
| `CORRECTIONS_APPLIED.md` | Bug fixes (January 2025) |
| `CORRECTIONS_OCTOBER_2025.md` | ROM implementation & bug fixes ✨NEW |
| `docs/INTERFACE_SPEC.md` | Complete interface specification |
| `CLAUDE.md` | This file (project context) |

---

## 🐛 Debugging Tips

### If simulation fails:
1. Check `cnc_pkg.vhd` is compiled first
2. Verify VHDL-93 mode (not VHDL-2008)
3. Look for assertions in transcript
4. Check `open_loop` signal (0=sim, 1=external)

### If synthesis fails:
1. Verify top-level entity: **`cnc_3axis_rom_top`**
2. Check all ROM files included
3. Look for unassigned pins (only 39 needed)
4. Check for VHDL-93 compatibility

### If hardware test fails:
1. Check `open_loop` setting (DIP switch)
2. Verify 50 MHz clock input
3. Check TB6600 driver connections
4. Monitor `fault` LED (limit switches, encoder errors)
5. Check `current_step[5:0]` LED/pins for ROM progress

---

## 📊 Comparison: Original vs ROM-Based

| Feature | Original | ROM-Based | Status |
|---------|----------|-----------|--------|
| **Pin Count** | 211 | 39 | ✅ **Solved** |
| **Trajectory Source** | External (parallel bus) | Internal (ROM) | ✅ Simplified |
| **Testing** | Requires hardware | Encoder simulation | ✅ Realistic |
| **FPGA Fit** | ❌ No (211 > 144) | ✅ Yes (39 < 144) | ✅ **Compatible** |
| **LE Usage** | ~1650 | ~1850 | ✅ Acceptable |
| **Positions** | Unlimited | 64 (expandable) | ⚠️ Limited |
| **Runtime Update** | Yes (parallel bus) | No (ROM fixed) | ⚠️ Static |

**Trade-offs:**
- ✅ **Solved pin count** - now fits in FPGA
- ✅ **Realistic testing** - encoder simulation
- ⚠️ **Limited to 64 positions** - can expand ROM or add SPI interface later
- ⚠️ **Static trajectory** - need reprogramming to change path

---

**Project Status:** ✅ **ROM-based design complete + HOMING SYSTEM TESTED & VERIFIED**
**Last Contributors:** Angelo Coppi, Claude Code (Anthropic)

**Session Updates (2025-10-16):**

**Morning Session (10:00-12:00):**
- ✅ ROM aggiornata da 64 a 24 posizioni (cube + double pyramid geometry)
- ✅ Sistema di homing automatico completo (Z→Y→X cascade)
- ✅ 3 nuovi moduli RTL: homing_sequence_v2, axis_homing_v3, reset_z
- ✅ 4 nuovi testbench completi con verifica automatica
- ✅ Documentazione CLAUDE.md aggiornata con sezione homing

**Evening Session (21:00-21:20):**
- ✅ Test completo sistema di homing eseguito con successo
- ✅ Testbench corretto: aggiunto delay 100ns per propagazione segnale direzione
- ✅ Aggiunto segnale `all_axes_homed_n` (attivo basso) per pilotaggio LED
- ✅ Compilazione finale: 0 errors, 0 warnings
- ✅ Risultati test: tutti gli assi homed correttamente (Z: 50+19+200, Y: 109+19+200, X: 109+19+200 steps)

**Next Phase:** RAM implementation (2048 positions) + SPI interface + TEST pin
