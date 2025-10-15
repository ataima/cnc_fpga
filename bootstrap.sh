#!/usr/bin/env bash
#
# ============================================================================
#  bootstrap.sh
#  Setup script for ModelSim/QuestaSim VHDL projects
#  - Creates work library
#  - Compiles all VHDL files in rtl/ and sim/
#  - Generates a Makefile.vmake for incremental rebuilds
# ============================================================================

set -e  # stop on first error

# Directories
RTL_DIR="rtl"
SIM_DIR="sim"
WORK_DIR="work"
VERS=93 

echo ">>> Creating work library..."
mkdir -p "$WORK_DIR"
vlib "$WORK_DIR" >/dev/null 2>&1 || true
vmap work "$WORK_DIR" >/dev/null 2>&1 || true

echo ">>> Compiling RTL smain package"
vcom -"$VERS" "$RTL_DIR"/$1


echo ">>> Compiling RTL sources..."
vcom -"$VERS" "$RTL_DIR"/*.vhd

echo ">>> Compiling SIM sources..."
vcom -"$VERS" "$SIM_DIR"/*.vhd

echo ">>> Generating Makefile.vmake..."
vmake > Makefile.vmake

echo ">>> Done!"
rm -f ./do

echo "make -f Makefile.vmake" > ./do

chmod +x ./do

echo "Now can build with with : .do"

