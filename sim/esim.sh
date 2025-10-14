#/bin/bash

set -e  # Exit on error



# === DEFINIZIONE DEI CODICI ANSI PER I COLORI ===
# Reset
RESET='\033[0m'

# Colori normali (foreground)
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Colori bold (intensi)
BBLACK='\033[1;30m'
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BBLUE='\033[1;34m'
BPURPLE='\033[1;35m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

# === FUNZIONI DI STAMPA COLORATA ===


tbfile=""
simfile=""



# Stampa un messaggio in rosso (es. errore)
function print_error() {
    echo -e "${RED}[ERRORE]${RESET} $1"
}

# Stampa un messaggio in giallo (es. avviso)
function print_warning() {
    echo -e "${YELLOW}[AVVISO]${RESET} $1"
}

# Stampa un messaggio in verde (es. successo)
function print_success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

# Stampa un messaggio in blu (es. info)
function print_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

# Stampa un messaggio con un colore personalizzato
# Uso: color_print "testo" "$RED"
function color_print() {
    local text="$1"
    local color="$2"
    echo -e "${color}${text}${RESET}"
}

# Esempio di utilizzo avanzato: log con timestamp
function log_info() {
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${RESET} ${WHITE}INFO${RESET}    $1"
}

function log_error() {
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${RESET} ${RED}ERRORE${RESET}  $1"
}

#$1 opt
#$2 file
vcom_exec(){
    vcom -93 $1 $2
    if [ $? -ne 0 ]
    then
        log_error "vcom fail ! ${BYELLOW} $1 ${RESET}"
        return 1
    fi
    return 0
}

function clean_rtl(){
    cd ../rtl
    vdel -all  work
    cd -
}



# Function to compile RTL
function compile_rtl() {
    log_info "Compile rtl files ..."
    if [ -d "../rtl" ]
    then 
        cd ../rtl
        local ALL_FILES="cnc_pkg.vhd  bresenham_axis.vhd  cnc_3axis_controller_synth.vhd  cnc_3axis_controller.vhd
                        trajectory_rom.vhd rom_controller.vhd   step_dir_generator.vhd
                        encoder_decoder.vhd encoder_simulator.vhd cnc_3axis_rom_top.vhd"
        for one in ${ALL_FILES}
        do
            vcom_exec " " "${one}"
            [ $? -ne 0 ] && exit 1
        done
        log_info "    ✓ RTL compilation complete"
        cd ../sim
    fi
}


select_vhd_file() {
    local dir_path="$1"

    # Controllo: la directory esiste?
    if [[ ! -d "$dir_path" ]]; then
        log_error "Il percorso '${dir_path}' non è una directory valida."
        return 1
    fi

    # Raccogli i file .vhd (case-insensitive) in un array
    local -a vhd_files=()
    while IFS= read -r -d '' file; do
        vhd_files+=("$file")
    done < <(find "$dir_path" -maxdepth 1 -type f \( -iname "*.vhd" \) -print0 | sort -z)

    # Nessun file trovato?
    if [[ ${#vhd_files[@]} -eq 0 ]]; then
        print_warning "Nessun file .vhd trovato in '${dir_path}'."
        return 1
    fi

    # Mostra intestazione (usiamo echo semplice per il menu, non è un log)
    echo -e "\n${BLUE}📁 File .vhd trovati in:${RESET} ${dir_path}"
    echo "--------------------------------------------------"

    # Lista numerata
    local i=1
    for file in "${vhd_files[@]}"; do
        echo -e "${i}) $(basename "$file")"
        ((i++))
    done
    echo

    # Input utente con validazione
    local choice
    while true; do
        read -rp "Seleziona un file (1-${#vhd_files[@]}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#vhd_files[@]} )); then
            # Restituisce solo il nome del file (basename)
            tbfile=`basename "${vhd_files[$((choice - 1))]}"`
            return 0
        else
            echo -e "${RED}[!] Scelta non valida.${RESET} Inserisci un numero tra 1 e ${#vhd_files[@]}."
        fi
    done
}

where=`basename ${PWD}`

if [ "${where}" != "sim" ]
then
    log_error "this script run only from 'sim' path"
    exit 1
fi 

clean_rtl
compile_rtl
select_vhd_file .
if [ $? -eq 0 ]
then
    cd ../rtl
    vcom_exec "-work work" "../sim/$tbfile"
    if [ $? -eq 0 ]
    then
        simfile="../rtl/work."`basename $tbfile .vhd `
        vsim -c "$simfile" -do "run 100 ms; quit -f"
    fi
fi

exit $?