# CNC 3-Axis FPGA Controller

## Panoramica del Progetto

Controller CNC a 3 assi implementato su FPGA Cyclone IV EP4CE6E22C8N, progettato per il controllo preciso di motori stepper tramite driver TB6600 con feedback encoder e algoritmo di interpolazione lineare Bresenham.

## Caratteristiche Principali

- **3 assi simultanei** (X, Y, Z) con interpolazione lineare
- **Encoder feedback** quadratura (600 PPR) con filtro digitale anti-rimbalzo
- **Output STEP/DIR** compatibili con driver TB6600
- **Limit switch** con logica di sicurezza integrata
- **Timing deterministico** con jitter <10ns
- **Algoritmo Bresenham** hardware per movimenti lineari perfetti
- **Emergency stop** con abort immediato
- **Posizione 32-bit signed** (±2 miliardi di step)

## Struttura del Progetto

```
~/cnc_fpga/
├── rtl/                          # Sorgenti VHDL
│   ├── cnc_pkg.vhd              # Package con definizioni comuni
│   ├── encoder_decoder.vhd      # Decoder encoder quadratura
│   ├── bresenham_axis.vhd       # Core algoritmo Bresenham
│   ├── step_dir_generator.vhd   # Generatore segnali STEP/DIR
│   └── cnc_3axis_controller.vhd # Top-level controller
├── sim/                          # Testbench
│   └── tb_bresenham.vhd         # Testbench per simulazione
├── constraints/                  # Vincoli Quartus
│   └── EP4CE6E22C8N.qsf         # Pin assignment e timing
├── quartus/                      # Progetto Quartus (da creare)
└── docs/                         # Documentazione
    └── README.md                # Questo file
```

## Specifiche Hardware

### Target FPGA
- **Device**: Intel/Altera Cyclone IV EP4CE6E22C8N
- **Package**: 144-EQFP
- **Logic Elements**: 6272 LE
- **Clock**: 50 MHz
- **Utilizzo stimato**: ~1650 LE (26% della FPGA)

### Risorse Utilizzate

| Modulo | LE Stimati | % |
|--------|-----------|---|
| 3x Encoder Decoder | 450 | 7% |
| 3x Bresenham Core | 600 | 10% |
| 3x Step/Dir Generator | 300 | 5% |
| Motion Controller | 200 | 3% |
| Safety Logic | 100 | 2% |
| **TOTALE** | **1650** | **26%** |

### Interfacce I/O

**INPUT:**
- 6x Encoder (A/B) per 3 assi
- 6x Limit switch (min/max) per 3 assi
- Segnali di controllo (start, abort, enable)
- Target position (32-bit per asse)
- Feedrate (16-bit)

**OUTPUT:**
- 9x STEP/DIR/ENABLE per 3 assi (driver TB6600)
- 3x Position feedback (32-bit da encoder)
- Status (busy, fault)
- Debug state (4-bit)

## Architettura del Sistema

### 1. Encoder Decoder
- Decodifica segnali quadratura A/B
- Filtro digitale anti-rimbalzo (4 stadi)
- Contatore posizione 32-bit signed
- Misura velocità in tempo reale
- Rilevamento errori sequenza

### 2. Bresenham Core
- Implementazione hardware algoritmo Bresenham
- Interpolazione lineare 3D perfetta
- Gestione asse principale/secondario
- Rate limiting configurabile
- Supporto abort immediato

### 3. Step/Dir Generator
- Pulse stretching STEP (5μs)
- Setup/Hold time DIR (1μs)
- Verifica limit switch pre-movimento
- Timing garantito TB6600-compatible
- Fault detection

### 4. Motion Controller
- Calcolo automatico asse principale
- Gestione movimenti coordinati 3 assi
- Conversione feedrate → step period
- State machine controllo movimento
- Safety logic integrata

## Guida Utilizzo

### Compilazione VHDL

Ordine di compilazione (ModelSim/Quartus):
1. `cnc_pkg.vhd`
2. `encoder_decoder.vhd`
3. `bresenham_axis.vhd`
4. `step_dir_generator.vhd`
5. `cnc_3axis_controller.vhd`
6. `tb_bresenham.vhd` (testbench)

### Simulazione

```bash
# ModelSim
vcom -93 rtl/cnc_pkg.vhd
vcom -93 rtl/encoder_decoder.vhd
vcom -93 rtl/bresenham_axis.vhd
vcom -93 rtl/step_dir_generator.vhd
vcom -93 rtl/cnc_3axis_controller.vhd
vcom -93 sim/tb_bresenham.vhd
vsim work.tb_bresenham
run -all
```

### Import in Quartus Prime

Vedi sezione dedicata alla fine di questo documento.

## Parametri Configurabili

Nel package `cnc_pkg.vhd`:

```vhdl
CLK_FREQ_HZ      : 50_000_000  -- Frequenza clock sistema
POSITION_WIDTH   : 32          -- Bit contatore posizione
VELOCITY_WIDTH   : 16          -- Bit misura velocità
ENCODER_PPR      : 600         -- Pulses Per Revolution encoder
ENCODER_FILTER   : 4           -- Stadi filtro debounce
MIN_STEP_PERIOD  : 100         -- Periodo minimo step (20μs)
MAX_STEP_PERIOD  : 65535       -- Periodo massimo step
```

Nel generatore STEP/DIR:

```vhdl
STEP_WIDTH_US    : 5           -- Larghezza pulse STEP (μs)
DIR_SETUP_US     : 1           -- Setup time DIR (μs)
```

## Sequenza di Movimento

1. **Configurazione**: Impostare `target_x`, `target_y`, `target_z`, `feedrate`
2. **Start**: Portare `move_start` = '1' per 1 clock cycle
3. **Movimento**: Il controller calcola parametri e avvia assi
4. **Monitoraggio**: Controllare `busy` = '1' durante movimento
5. **Completamento**: Quando `busy` = '0', movimento terminato
6. **Position feedback**: Leggere `pos_x`, `pos_y`, `pos_z`

### Abort Immediato

In qualsiasi momento: `move_abort` = '1' → arresto immediato tutti gli assi

### Fault Management

Il segnale `fault` = '1' indica:
- Limit switch attivato durante movimento
- Errore sequenza encoder
- Tentativo di movimento oltre limiti

## Timing e Performance

- **Clock sistema**: 50 MHz (20ns periodo)
- **Max step rate**: >1 MHz per asse
- **Jitter**: <10ns (timing deterministico)
- **Latenza abort**: 1 clock cycle (20ns)
- **Setup time DIR**: 1μs (garantito)
- **Pulse width STEP**: 5μs (compatibile TB6600)

## Esempi di Utilizzo

### Movimento Lineare (0,0,0) → (100,50,25)

```vhdl
-- Impostazione target
target_x <= to_signed(100, 32);
target_y <= to_signed(50, 32);
target_z <= to_signed(25, 32);
feedrate <= to_unsigned(10000, 16);  -- 10000 step/sec

-- Start movimento
enable <= '1';
move_start <= '1';
wait for 20 ns;
move_start <= '0';

-- Attendi completamento
wait until busy = '0';
```

### Movimento con Direzione Negativa

```vhdl
-- Target negativi (direzione inversa)
target_x <= to_signed(-200, 32);
target_y <= to_signed(-100, 32);
target_z <= to_signed(0, 32);
feedrate <= to_unsigned(5000, 16);

move_start <= '1';
wait for 20 ns;
move_start <= '0';
```

## Import in Quartus Prime - Guida Completa

### Metodo 1: Creazione Nuovo Progetto con File Esistenti

#### Passo 1: Avviare Quartus Prime
```
File → New Project Wizard
```

#### Passo 2: Directory e Nome Progetto
```
Working directory: ~/cnc_fpga/quartus/
Project name: cnc_3axis_fpga
Top-level entity: cnc_3axis_controller
```

#### Passo 3: Tipo di Progetto
```
Selezionare: "Empty project"
```

#### Passo 4: Aggiungere File Esistenti
```
Click su "Add Files"
Navigare in: ~/cnc_fpga/rtl/

Selezionare nell'ordine:
1. cnc_pkg.vhd
2. encoder_decoder.vhd
3. bresenham_axis.vhd
4. step_dir_generator.vhd
5. cnc_3axis_controller.vhd

Click "Add" per ciascun file
```

#### Passo 5: Selezione Device
```
Family: Cyclone IV E
Device: EP4CE6E22C8N
Package: EQFP144
Speed Grade: C8

Oppure usare il filtro:
- Name: EP4CE6E22C8N
- Click sul device trovato
```

#### Passo 6: EDA Tool Settings
```
Simulation: ModelSim (opzionale)
Lasciare altre impostazioni di default
```

#### Passo 7: Import Constraints (QSF)
```
Dopo aver creato il progetto:

File → Settings → General
Click su "..." accanto a "Project Settings File"
Navigare in: ~/cnc_fpga/constraints/EP4CE6E22C8N.qsf

Oppure copiare manualmente:
cp ~/cnc_fpga/constraints/EP4CE6E22C8N.qsf ~/cnc_fpga/quartus/cnc_3axis_fpga.qsf
```

### Metodo 2: Import da Command Line

```bash
cd ~/cnc_fpga/quartus/

# Crea progetto
quartus_sh --tcl_eval project_new cnc_3axis_fpga -overwrite

# Imposta device
quartus_sh --tcl_eval "project_open cnc_3axis_fpga; \
  set_global_assignment -name DEVICE EP4CE6E22C8N; \
  set_global_assignment -name TOP_LEVEL_ENTITY cnc_3axis_controller; \
  project_close"

# Aggiungi file VHDL
quartus_sh --tcl_eval "project_open cnc_3axis_fpga; \
  set_global_assignment -name VHDL_FILE ../rtl/cnc_pkg.vhd; \
  set_global_assignment -name VHDL_FILE ../rtl/encoder_decoder.vhd; \
  set_global_assignment -name VHDL_FILE ../rtl/bresenham_axis.vhd; \
  set_global_assignment -name VHDL_FILE ../rtl/step_dir_generator.vhd; \
  set_global_assignment -name VHDL_FILE ../rtl/cnc_3axis_controller.vhd; \
  project_close"

# Import constraints
cat ../constraints/EP4CE6E22C8N.qsf >> cnc_3axis_fpga.qsf
```

### Metodo 3: Uso del File QSF Esistente

Il file `EP4CE6E22C8N.qsf` contiene già tutti i riferimenti ai file:

```bash
cd ~/cnc_fpga/quartus/

# Copia il QSF
cp ../constraints/EP4CE6E22C8N.qsf ./cnc_3axis_fpga.qsf

# Crea file QPF (project file)
cat > cnc_3axis_fpga.qpf << EOF
QUARTUS_VERSION = "Version 18.0"
PROJECT_REVISION = "cnc_3axis_fpga"
EOF

# Apri con Quartus
quartus cnc_3axis_fpga.qpf
```

### Compilazione del Progetto

#### GUI:
```
Processing → Start Compilation
(oppure Ctrl+L)
```

#### Command Line:
```bash
cd ~/cnc_fpga/quartus/
quartus_sh --flow compile cnc_3axis_fpga
```

### Verifica Pin Assignment

```
Assignments → Pin Planner
```

Verificare che tutti i pin siano assegnati correttamente secondo la tabella nel QSF.

### Analisi Timing

Dopo la compilazione:
```
Tools → TimeQuest Timing Analyzer
Tasks → Update Timing Netlist
Reports → Custom Reports → Report Timing
```

Verificare che tutti i path abbiano **slack positivo**.

### Generazione File Programmazione

```
File → Convert Programming Files

Output file: cnc_3axis_fpga.sof (SRAM programming)
         o   cnc_3axis_fpga.pof (Flash programming)
```

### Programmazione FPGA

```
Tools → Programmer

1. Hardware Setup → Selezionare programmatore (USB-Blaster)
2. Add File → cnc_3axis_fpga.sof
3. Check "Program/Configure"
4. Click "Start"
```

## Troubleshooting Quartus

### Errore: "Top-level entity not found"
```
Assignments → Settings → General
Verificare che "Top-level entity" = cnc_3axis_controller
```

### Errore: "File not found" durante compilazione
```
Verificare path relativi nel QSF:
set_global_assignment -name VHDL_FILE ../rtl/cnc_pkg.vhd

Se necessario, usare path assoluti:
set_global_assignment -name VHDL_FILE /home/user/cnc_fpga/rtl/cnc_pkg.vhd
```

### Errore: "Package cnc_pkg not found"
```
Assicurarsi che cnc_pkg.vhd sia il primo file compilato.
Ordine compilazione gestito automaticamente da Quartus se i file sono aggiunti correttamente.
```

### Warning: "Timing requirements not met"
```
Tools → TimeQuest Timing Analyzer
Analizzare path critici
Eventualmente ridurre CLK_FREQ_HZ nel package o abilitare ottimizzazioni:

Settings → Compiler Settings → Optimization
- Speed: Abilitare "Perform physical synthesis for combinational logic"
```

## Testing e Validazione

### Test Funzionali Consigliati

1. **Test encoder**: Verificare conteggio corretto con rotazione manuale
2. **Test limit switch**: Verificare fault detection
3. **Test movimenti singolo asse**: X, Y, Z separatamente
4. **Test movimento 2D**: Diagonale XY, verificare linearità
5. **Test movimento 3D**: Tutti e 3 gli assi simultanei
6. **Test abort**: Interrompere movimento e verificare stop immediato
7. **Test velocità variabili**: Da feedrate minimo a massimo

### Waveform da Verificare (Simulazione)

Nel testbench `tb_bresenham.vhd`:
- Sequenza step X: dovrebbe generare 100 pulse
- Sequenza step Y: dovrebbe generare 50 pulse
- Timing: verificare periodo tra step uguale a `step_period`
- Abort: verificare stop immediato quando abort='1'

## Note di Sicurezza

1. **Verificare sempre i limit switch** prima del power-on
2. **Testare emergency stop** prima dell'uso normale
3. **Non superare velocità massima** dei motori stepper
4. **Verificare direzioni assi** con movimenti di test a bassa velocità
5. **Controllare connessioni encoder** per evitare falsi conteggi

## Licenza e Disclaimer

Questo progetto è fornito AS-IS per scopi educativi e di sviluppo.
Testare accuratamente prima dell'uso in applicazioni critiche.

## Contatti e Supporto

Per domande o issue, riferirsi alla documentazione originale del progetto.

**Data**: 2025-10-12
**Versione**: 1.0
**Status**: Ready for Implementation
