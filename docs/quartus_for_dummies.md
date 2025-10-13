# Quartus & ModelSim for Dummies - Guida Completa

**Progetto**: CNC 3-Axis FPGA Controller
**Target**: Intel Cyclone IV EP4CE6E22C8N
**Data**: 2025-10-12
**Autore**: Angelo Coppi & Claude Code

---

## 📚 Indice

1. [Prerequisiti](#prerequisiti)
2. [Parte 1: Simulazione con ModelSim](#parte-1-simulazione-con-modelsim)
3. [Parte 2: Sintesi con Quartus Prime](#parte-2-sintesi-con-quartus-prime)
4. [Parte 3: Timing Analysis](#parte-3-timing-analysis)
5. [Parte 4: Programmazione FPGA](#parte-4-programmazione-fpga)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisiti

### Software Richiesto

1. **ModelSim Intel FPGA Edition 2020.1** (o superiore)
   - Installato in: `/opt/modelsim/modelsim_ase/`
   - Eseguibili: `vcom`, `vsim`, `vlog`

2. **Quartus Prime Lite Edition 20.1** (o superiore)
   - Download gratuito da: https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime/resource.html
   - Include: Quartus, ModelSim, TimeQuest

3. **Editor di testo** (opzionale)
   - VSCode, Sublime, gedit, vim, etc.

### File del Progetto

Assicurati di avere questa struttura:

```
~/quartus_wb/cnc_fpga/
├── rtl/
│   ├── cnc_pkg.vhd                  # Package principale
│   ├── encoder_decoder.vhd          # Decoder encoder
│   ├── bresenham_axis.vhd           # Core Bresenham (FIXED ✅)
│   ├── step_dir_generator.vhd       # Generatore STEP/DIR
│   └── cnc_3axis_controller.vhd     # Top-level
├── sim/
│   └── tb_bresenham.vhd             # Testbench (6 test)
├── constraints/
│   └── EP4CE6E22C8N.qsf             # Pin assignment
└── quartus/
    └── (progetto Quartus da creare)
```

---

## Parte 1: Simulazione con ModelSim

### Step 1.1: Preparazione Ambiente

Apri un terminale e vai nella directory di simulazione:

```bash
cd ~/quartus_wb/cnc_fpga/sim
```

### Step 1.2: Aggiungi ModelSim al PATH

**Metodo A - Solo per questa sessione**:
```bash
export PATH=/opt/modelsim/modelsim_ase/bin:$PATH
```

**Metodo B - Permanente (aggiungere a ~/.bashrc)**:
```bash
echo 'export PATH=/opt/modelsim/modelsim_ase/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

Verifica che funzioni:
```bash
which vcom
# Output atteso: /opt/modelsim/modelsim_ase/bin/vcom

vcom -version
# Output atteso: Model Technology ModelSim - Intel FPGA Edition vcom 2020.1
```

### Step 1.3: Crea la Libreria di Lavoro

ModelSim usa una libreria chiamata `work` per salvare i file compilati.

```bash
# Se non esiste già, crea la directory work
vlib work

# Verifica che sia stata creata
ls -la work/
```

### Step 1.4: Compila i Sorgenti VHDL

**IMPORTANTE**: I file devono essere compilati nell'ordine corretto (dipendenze).

```bash
# 1. Compila il package (primo, contiene tipi comuni)
cd ../rtl
vcom -93 -work work cnc_pkg.vhd

# 2. Compila i moduli che dipendono dal package
vcom -93 -work work encoder_decoder.vhd
vcom -93 -work work bresenham_axis.vhd
vcom -93 -work work step_dir_generator.vhd
vcom -93 -work work cnc_3axis_controller.vhd

# 3. Compila il testbench
cd ../sim
vcom -93 -work work tb_bresenham.vhd
```

**Output atteso per ogni file**:
```
Model Technology ModelSim - Intel FPGA Edition vcom 2020.1 Compiler 2020.02 Feb 28 2020
Start time: XX:XX:XX on Oct 12,2025
vcom -93 -work work filename.vhd
-- Loading package STANDARD
-- Loading package TEXTIO
-- Loading package std_logic_1164
-- Loading package NUMERIC_STD
-- Loading package cnc_pkg
-- Compiling entity xxxxx
-- Compiling architecture rtl of xxxxx
End time: XX:XX:XX on Oct 12,2025, Elapsed time: 0:00:00
Errors: 0, Warnings: 0  ✅
```

**Se vedi errori**:
- Controlla di aver compilato il package per primo
- Verifica che stai usando `-93` (VHDL-93 standard)
- Leggi il messaggio di errore (indica linea e problema)

### Step 1.5: Esegui la Simulazione

**Opzione A - Modalità Interattiva (con GUI)**:
```bash
vsim work.tb_bresenham
# Si apre la GUI di ModelSim
# Nel pannello comandi, digita:
run 150 ms
# Aspetta il completamento, poi:
quit
```

**Opzione B - Modalità Batch (senza GUI, consigliata)**:
```bash
vsim -c work.tb_bresenham -do "run 150 ms; quit -f"
```

**Output atteso**:
```
# vsim -c work.tb_bresenham -do "run 150 ms; quit -f"
# Start time: XX:XX:XX on Oct 12,2025
# Loading std.standard
# Loading std.textio(body)
# Loading ieee.std_logic_1164(body)
# Loading ieee.numeric_std(body)
# Loading work.cnc_pkg(body)
# Loading work.tb_bresenham(sim)
# Loading work.bresenham_axis(rtl)
# run 150 ms
# ** Note: === TEST 1: Movimento (0,0) -> (100,50) ===
#    Time: 200 ns  Iteration: 0  Instance: /tb_bresenham
# ** Note: X final position: 100
#    Time: 23230 ns  Iteration: 0  Instance: /tb_bresenham
# ** Note: Y final position: 50
#    Time: 23230 ns  Iteration: 0  Instance: /tb_bresenham
...
# ** Note: === SIMULAZIONE COMPLETATA - 6/6 TEST ===
#    Time: 1096350 ns  Iteration: 0  Instance: /tb_bresenham
#  quit -f
# End time: XX:XX:XX on Oct 12,2025, Elapsed time: 0:00:0X
# Errors: 0, Warnings: 0  ✅
```

### Step 1.6: Analisi dei Risultati

I risultati sono salvati nel file `transcript`:

```bash
cat transcript
# Oppure
less transcript
```

**Verifica che tutti i 6 test siano passati**:
```bash
grep "TEST" transcript
# Output atteso:
# ** Note: === TEST 1: Movimento (0,0) -> (100,50) ===
# ** Note: === TEST 2: Abort durante movimento ===
# ** Note: === TEST 3: Movimento negativo (-50,-25) ===
# ** Note: === TEST 4: Major axis solo X=100, Y=0 ===
# ** Note: === TEST 5: Diagonale 45 gradi (100,100) ===
# ** Note: === TEST 6: Movimento lento step_period=1000 (50,25) ===
# ** Note: === SIMULAZIONE COMPLETATA - 6/6 TEST ===
```

**Controlla errori**:
```bash
grep -i error transcript
# Output atteso: nessun errore (o solo "Errors: 0")
```

### Step 1.7: Visualizzare le Forme d'Onda (Opzionale)

Se vuoi vedere i segnali graficamente:

```bash
vsim work.tb_bresenham
# Nella GUI:
# 1. Click su "tb_bresenham" nella gerarchia a sinistra
# 2. Seleziona i segnali che vuoi vedere (es: clk, rst, pos_x, pos_y, busy_x, step_x)
# 3. Tasto destro → "Add to Wave"
# 4. Nel pannello comandi: run 150 ms
# 5. Nel pannello Wave: click destro → "Zoom Full" per vedere tutto
```

**Segnali interessanti da visualizzare**:
- `clk` - Clock 50 MHz
- `rst` - Reset
- `start_x`, `start_y` - Segnali di start
- `busy_x`, `busy_y` - Stato busy
- `step_x`, `step_y` - Pulse di step
- `pos_x`, `pos_y` - Posizione corrente
- `dir_x`, `dir_y` - Direzione

---

## Parte 2: Sintesi con Quartus Prime

### Step 2.1: Avvia Quartus Prime

```bash
# Apri Quartus (adatta il percorso se necessario)
quartus &
# Oppure cerca "Quartus Prime" nel menu applicazioni
```

### Step 2.2: Crea un Nuovo Progetto

1. **File → New Project Wizard**

2. **Page 1 - Directory, Name, Top-Level Entity**:
   - **Working directory**: `/home/angelocoppi/quartus_wb/cnc_fpga/quartus`
   - **Project name**: `cnc_3axis_fpga`
   - **Top-level entity**: `cnc_3axis_controller`
   - Click **Next**


3. **menu project - Add Files**:
   - Click **Add Files...**
   - Naviga a: `/home/angelocoppi/quartus_wb/cnc_fpga/rtl/`
   - Seleziona TUTTI i file `.vhd`:
     - `cnc_pkg.vhd`
     - `encoder_decoder.vhd`
     - `bresenham_axis.vhd`
     - `step_dir_generator.vhd`
     - `cnc_3axis_controller.vhd`
   - Click **Open**, poi **Next**

4. **menu Assignment - device**:
   - **Family**: Cyclone IV E
   - **Device**: EP4CE6E22C8
   - **Package**: EQFP144
   - **Speed grade**: C8
   - Click **Next**

   ![Device Selection](https://via.placeholder.com/400x200?text=EP4CE6E22C8N+EQFP144)

5. **tools -option-> EDA Tool Settings** 
   - **Simulation**: <path di modelsim>/modelsim_ase/bin
   - **Format**: VHDL
   - Lascia il resto di default
   - Click **Next**

7. **Page 6 - Summary**:
   - Verifica che tutto sia corretto
   - Click **Finish**

### Step 2.3: Importa i Constraint (Pin Assignment)

**IMPORTANTE**: Il file `.qsf` contiene i pin assignment per il Cyclone IV.

1. **Assignments → Import Assignments**
2. Naviga a: `/home/angelocoppi/quartus_wb/cnc_fpga/constraints/EP4CE6E22C8N.qsf`
3. Click **OK**

**NOTA**: Se vedi warning su pin count (211 richiesti vs 144 disponibili), è normale. Vedi la sezione "Pin Count Warning" in fondo.

### Step 2.4: Imposta il Top-Level Entity

1. **Project → Set as Top-Level Entity**
2. Seleziona `cnc_3axis_controller`
3. Click **OK**

Oppure manualmente:
1. **Assignments → Settings**
2. **Category: General**
3. **Top-level entity**: `cnc_3axis_controller`
4. Click **OK**

### Step 2.5: Analisi e Controllo Errori

Prima della sintesi, verifica che non ci siano errori:

1. **Processing → Start → Start Analysis & Elaboration**
2. Aspetta il completamento (pochi secondi)
3. Controlla il pannello **Messages** in basso:
   - **Errors**: Deve essere **0** ✅
   - **Warnings**: Alcuni sono normali (vedi sotto)
   - **Info**: Informazioni generali

**Warnings normali**:
- "Signal X is stuck at VCC/GND" - alcuni segnali costanti
- "Node X has unconnected output" - output non usati nel testbench
- "Found X pins without assignments" - normale se non tutti i pin sono assegnati

**Se vedi errori**:
- Leggi il messaggio (indica file e linea)
- Controlla che tutti i file VHDL siano stati aggiunti
- Verifica che il top-level entity sia corretto

### Step 2.6: Sintesi Completa (Synthesis)

Ora esegui la sintesi vera e propria:

1. **Processing → Start Compilation**
   - Oppure click sull'icona ▶️ **Start Compilation** nella toolbar
   - Oppure premi **Ctrl+L**

2. **Aspetta il completamento**:
   - Può richiedere 1-5 minuti
   - Vedrai una barra di progresso
   - Fasi:
     - Analysis & Synthesis
     - Fitter (Place & Route)
     - Assembler (Generate .sof)
     - TimeQuest Timing Analyzer

3. **Controlla il risultato**:
   - Se tutto OK: **"Full Compilation was successful"** ✅
   - Guarda il pannello **Compilation Report** (si apre automaticamente)

### Step 2.7: Analisi dei Risultati di Sintesi

Nel **Compilation Report**, espandi le sezioni:

#### **Flow Summary**
- **Status**: Successful ✅
- **Fmax**: Frequenza massima raggiunta (deve essere > 50 MHz)
- **Total logic elements**: ~1650 / 6272 (26%)
- **Total pins**: Vedi nota sul pin count

#### **Analysis & Synthesis → Resource Usage**
Controlla:
- **Logic Elements**: ~1650 / 6272 (26%) ✅
- **Combinational functions**: ~1400
- **Dedicated logic registers**: ~250
- **Total memory bits**: 0
- **Embedded Multipliers**: 0
- **PLLs**: 0 (o 1 se usi PLL per clock)

**Esempio output atteso**:
```
+----------------------------------+--------+
| Resource                         | Usage  |
+----------------------------------+--------+
| Total logic elements             | 1,650  |
|     Combinational functions      | 1,423  |
|     Dedicated logic registers    | 247    |
| Total pins                       | 38*    |
| Total memory bits                | 0      |
| Embedded multipliers (9-bit)     | 0      |
| PLLs                             | 0      |
+----------------------------------+--------+
```

\* 38 pin = solo quelli fisici (clock, reset, step/dir, encoder, limit).
I bus dati (target_x/y/z, pos_x/y/z) NON sono assegnati (serve interfaccia seriale).

#### **Fitter → Pin Usage**
- **Used**: 38
- **Available**: 144
- **Utilization**: 26%

### Step 2.8: Salva il Progetto

1. **File → Save Project**
2. Tutti i file generati sono in: `~/quartus_wb/cnc_fpga/quartus/`

File importanti generati:
- `cnc_3axis_fpga.qpf` - Progetto Quartus
- `cnc_3axis_fpga.qsf` - Settings e pin assignment
- `cnc_3axis_fpga.sof` - File di programmazione (SRAM)
- `output_files/` - File di sintesi e report

---

## Parte 3: Timing Analysis

### Step 3.1: Apri TimeQuest Timing Analyzer

1. **Tools → TimeQuest Timing Analyzer**
2. Si apre una nuova finestra

### Step 3.2: Crea il File SDC (Synopsys Design Constraints)

**SDC = file che specifica i vincoli di timing (clock, setup, hold).**

1. Nel TimeQuest Timing Analyzer:
   - **Constraints → Create Timing Netlist**
   - Click **OK**

2. Crea un nuovo file SDC:
   - **File → New SDC File**
   - Salva come: `cnc_3axis_fpga.sdc` nella cartella del progetto

3. Aggiungi il constraint del clock:

```tcl
# Clock constraint per 50 MHz (periodo = 20 ns)
create_clock -name clk -period 20.000 [get_ports {clk}]

# Input delay (da sensori esterni)
set_input_delay -clock clk -max 5.0 [get_ports {enc_*_a enc_*_b limit_* move_* enable}]
set_input_delay -clock clk -min 0.0 [get_ports {enc_*_a enc_*_b limit_* move_* enable}]

# Output delay (verso driver esterni)
set_output_delay -clock clk -max 5.0 [get_ports {step_* dir_* enable_*}]
set_output_delay -clock clk -min 0.0 [get_ports {step_* dir_* enable_*}]
```

4. Salva il file (Ctrl+S)

### Step 3.3: Esegui l'Analisi di Timing

1. **Tasks → Update Timing Netlist**
2. **Tasks → Read SDC File** → seleziona `cnc_3axis_fpga.sdc`
3. **Tasks → Update Timing Netlist** (di nuovo)

4. Esegui i report:
   - **Reports → Custom Reports → Report Timing**
   - **From**: clk
   - **To**: clk
   - Click **Report Timing**

### Step 3.4: Interpreta i Risultati

Nel pannello **Timing Report**, cerca:

#### **Setup Slack**
- **Slack > 0**: PASS ✅
- **Slack < 0**: FAIL ❌ (il design è troppo lento)

**Esempio output atteso**:
```
Clock clk
  Period: 20.000 ns
  Fmax: 55.123 MHz (actual)

Setup Slack: +2.456 ns  ✅
Hold Slack: +0.123 ns   ✅
```

**Cosa significa**:
- **Fmax = 55 MHz**: Il design può funzionare fino a 55 MHz
- **Target = 50 MHz**: Abbiamo margine di +5 MHz ✅
- **Setup Slack = +2.456 ns**: Abbiamo 2.5 ns di margine (positive slack = OK)

**Se Slack < 0**:
- Il design è troppo lento per 50 MHz
- Soluzioni:
  - Riduci la frequenza del clock
  - Ottimizza il codice VHDL
  - Abilita registri pipeline
  - Usa opzioni di ottimizzazione aggressive nel Fitter

### Step 3.5: Verifica dei Path Critici

1. **Reports → Custom Reports → Report Timing**
2. **Number of paths**: 10
3. **From**: [all]
4. **To**: [all]
5. Click **Report Timing**

Vedrai i 10 percorsi più lenti (critical paths). Verifica che tutti abbiano **slack positivo**.

**Esempio**:
```
Path #1:
  From: bresenham_x:step_counter[15]
  To: bresenham_x:error_accum[33]
  Delay: 17.544 ns
  Slack: +2.456 ns  ✅
```

---

## Parte 4: Programmazione FPGA

### Step 4.1: Genera il File di Programmazione

Se non è stato già generato dalla compilazione:

1. **Processing → Start → Assembler (Generate programming files)**
2. Aspetta il completamento
3. File generato: `output_files/cnc_3axis_fpga.sof`

### Step 4.2: Connetti l'FPGA

1. **Hardware necessario**:
   - Scheda FPGA con Cyclone IV EP4CE6E22C8N
   - Cavo USB Blaster (JTAG)
   - Alimentazione 5V per la scheda

2. **Collega**:
   - USB Blaster al PC (porta USB)
   - USB Blaster alla scheda FPGA (connettore JTAG 10-pin)
   - Alimenta la scheda

### Step 4.3: Configura il Programmer

1. **Tools → Programmer**
2. Si apre la finestra **Programmer**

3. **Hardware Setup**:
   - Click su **Hardware Setup...**
   - **Currently selected hardware**: scegli **USB-Blaster**
   - Click **Close**

4. **Aggiungi il file .sof**:
   - Se non c'è già, click **Add File...**
   - Seleziona: `output_files/cnc_3axis_fpga.sof`
   - Assicurati che la checkbox **Program/Configure** sia selezionata ✅

### Step 4.4: Programma l'FPGA

1. **Click su "Start"** (o premi Ctrl+L)
2. Vedrai la barra di progresso:
   - **Erase**: Cancella configurazione precedente
   - **Program**: Scrive il nuovo bitstream
   - **Verify**: Verifica la programmazione

3. **Output atteso**:
   ```
   Info: 100% (Success)  ✅
   ```

**Se vedi errori**:
- "Can't detect JTAG chain": USB Blaster non collegato o driver non installati
- "Verify failed": Problema con il file .sof o connessione instabile

### Step 4.5: Verifica il Funzionamento

**NOTA**: Poiché i bus dati non sono mappati su pin fisici, dovrai:

1. **Test base** (senza connessioni esterne):
   - Usa un LED collegato al pin `busy` per vedere se il sistema risponde
   - Usa un oscilloscopio su `step_x` per vedere i pulse

2. **Test completo** (richiede interfaccia seriale):
   - Implementa SPI/UART per controllare `target_x/y/z`
   - Connetti encoder reali agli input `enc_*_a/b`
   - Connetti driver TB6600 agli output `step_*/dir_*`

---

## Troubleshooting

### Problema: "vcom: command not found"

**Causa**: ModelSim non è nel PATH.

**Soluzione**:
```bash
export PATH=/opt/modelsim/modelsim_ase/bin:$PATH
# Oppure verifica il percorso:
ls /opt/modelsim/modelsim_ase/bin/vcom
```

---

### Problema: "Error: Cannot find package 'cnc_pkg'"

**Causa**: Il package non è stato compilato per primo.

**Soluzione**:
```bash
cd ~/quartus_wb/cnc_fpga/rtl
vcom -93 -work work cnc_pkg.vhd
# Poi ricompila gli altri file
```

---

### Problema: Simulazione si blocca infinitamente

**Causa**: Loop infinito nel testbench (es: `wait until` senza timeout).

**Soluzione**:
- Usa `vsim -c ... -do "run 150 ms; quit -f"` per forzare timeout
- Controlla il testbench per `wait until` senza condizione di uscita

---

### Problema: "Error: Can't elaborate top-level design"

**Causa**: Top-level entity sbagliata o mancante.

**Soluzione**:
1. Verifica che `cnc_3axis_controller` sia compilato correttamente
2. In Quartus: **Assignments → Settings → General → Top-level entity**
3. Assicurati che il nome sia esattamente `cnc_3axis_controller` (case-sensitive)

---

### Problema: Timing Analyzer - Slack negativo

**Causa**: Il design è troppo lento per la frequenza richiesta.

**Soluzione**:
1. **Opzione 1**: Riduci la frequenza del clock (es: da 50 MHz a 40 MHz)
2. **Opzione 2**: Ottimizza il codice VHDL (riduci logica combinatoria)
3. **Opzione 3**: Abilita opzioni di ottimizzazione aggressive:
   - **Assignments → Settings → Compiler Settings → Optimization Mode**
   - Cambia da "Balanced" a "High Performance Effort"

---

### Problema: Quartus - "Cannot find USB-Blaster"

**Causa**: Driver non installati o USB Blaster non collegato.

**Soluzione**:
1. **Linux**: Installa i driver Altera:
   ```bash
   cd /opt/intelFPGA/20.1/quartus/drivers/
   sudo ./setup
   ```

2. **Verifica connessione**:
   ```bash
   lsusb | grep Altera
   # Dovresti vedere: "Bus XXX Device XXX: ID 09fb:6001 Altera Blaster"
   ```

3. **Permessi USB** (Linux):
   ```bash
   sudo usermod -a -G plugdev $USER
   # Logout e login per applicare
   ```

---

### Problema: Resource Usage troppo alta (>90%)

**Causa**: Design troppo complesso per il Cyclone IV EP4CE6.

**Soluzione**:
1. Verifica che la sintesi sia ottimizzata
2. Considera un FPGA più grande (es: EP4CE10, EP4CE15)
3. Rimuovi funzionalità non usate
4. Ottimizza i contatori e registri (riduci larghezza se possibile)

---

### Problema: "Warning: Design contains X latches"

**Causa**: Logica combinatoria con feedback o `if` senza `else`.

**Soluzione**:
- I latch sono generalmente **indesiderati** in FPGA
- Controlla i file VHDL per `process` senza reset completo
- Assicurati che ogni `if` abbia un `else` (o valore di default)

---

## 📋 Checklist Rapida

### Prima della Simulazione
- [ ] ModelSim installato e nel PATH
- [ ] Tutti i file `.vhd` presenti in `rtl/` e `sim/`
- [ ] Libreria `work` creata (`vlib work`)

### Prima della Sintesi
- [ ] Quartus Prime installato
- [ ] Progetto creato con device corretto (EP4CE6E22C8)
- [ ] Tutti i file VHDL aggiunti al progetto
- [ ] Top-level entity impostato correttamente
- [ ] File `.qsf` importato (pin assignment)

### Prima della Programmazione
- [ ] Compilazione completata con successo
- [ ] File `.sof` generato
- [ ] USB Blaster collegato e riconosciuto
- [ ] FPGA alimentato

---

## 📚 Risorse Aggiuntive

### Documentazione Intel/Altera
- **Quartus Prime User Guide**: https://www.intel.com/content/www/us/en/docs/programmable/683232/current/introduction.html
- **Cyclone IV Handbook**: https://www.intel.com/content/www/us/en/programmable/documentation/lit-index.html
- **TimeQuest User Guide**: https://www.intel.com/content/dam/altera-www/global/en_US/pdfs/literature/ug/ug_timequest.pdf

### Tutorial Video
- Quartus Prime Getting Started: https://www.youtube.com/results?search_query=quartus+prime+tutorial
- ModelSim Simulation: https://www.youtube.com/results?search_query=modelsim+vhdl+tutorial

### Forum e Community
- Intel FPGA Forum: https://community.intel.com/t5/Programmable-Devices/ct-p/programmable-devices
- Stack Overflow (VHDL tag): https://stackoverflow.com/questions/tagged/vhdl

---

## 🎓 Glossario

| Termine | Significato |
|---------|-------------|
| **FPGA** | Field-Programmable Gate Array - Chip riconfigurabile |
| **VHDL** | VHSIC Hardware Description Language - Linguaggio per descrivere hardware |
| **Synthesis** | Processo di conversione VHDL → netlist (rete logica) |
| **Fitter** | Processo di Place & Route (posizionamento componenti + routing) |
| **LE** | Logic Element - Blocco logico base del Cyclone IV |
| **Fmax** | Frequenza massima di clock raggiungibile |
| **Slack** | Margine di timing (positivo = OK, negativo = fail) |
| **Setup Time** | Tempo minimo prima del clock per stabilizzare il dato |
| **Hold Time** | Tempo minimo dopo il clock per mantenere il dato |
| **.sof** | SRAM Object File - File di programmazione temporaneo (perso allo spegnimento) |
| **.pof** | Programmer Object File - File di programmazione permanente (flash) |
| **JTAG** | Joint Test Action Group - Protocollo per programmazione/debug |
| **USB Blaster** | Programmatore JTAG di Intel/Altera |

---

## ✅ Conclusione

Seguendo questa guida dovresti essere in grado di:

1. ✅ Simulare il design con ModelSim (6/6 test passing)
2. ✅ Sintetizzare il design con Quartus (~1650 LE, 26% usage)
3. ✅ Verificare il timing (Fmax > 50 MHz)
4. ✅ Programmare l'FPGA via USB Blaster

**Prossimi passi**:
- Implementare interfaccia SPI/UART per risolvere il pin count issue
- Testare con hardware reale (motori + encoder + driver TB6600)
- Aggiungere profili di accelerazione/decelerazione

---

**Buona fortuna con il tuo progetto CNC FPGA!** 🚀

**Autore**: Angelo Coppi & Claude Code (Anthropic)
**Data**: 2025-10-12
**Versione**: 1.0
