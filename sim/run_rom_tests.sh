#!/bin/bash
################################################################################
# Script: run_rom_tests.sh
# Description: Compile and run ROM visualization testbenches
# Usage: ./run_rom_tests.sh [viewer|full|all]
################################################################################

set -e  # Exit on error

echo "================================================================================"
echo "  CNC FPGA - ROM Trajectory Test Suite"
echo "================================================================================"
echo ""

# Check if ModelSim is available
if ! command -v vcom &> /dev/null; then
    echo "ERROR: vcom (ModelSim) not found in PATH"
    echo "Please ensure ModelSim is installed and PATH is set correctly"
    exit 1
fi

# Get test selection
TEST_MODE="${1:-all}"

# Function to compile RTL
compile_rtl() {
    echo "[1/3] Compiling RTL files..."
    cd ../rtl

    vcom -93 cnc_pkg.vhd || exit 1
    vcom -93 encoder_decoder.vhd || exit 1
    vcom -93 encoder_simulator.vhd || exit 1
    vcom -93 bresenham_axis.vhd || exit 1
    vcom -93 step_dir_generator.vhd || exit 1
    vcom -93 cnc_3axis_controller.vhd || exit 1
    vcom -93 trajectory_rom.vhd || exit 1
    vcom -93 rom_controller.vhd || exit 1
    vcom -93 cnc_3axis_rom_top.vhd || exit 1

    echo "    ✓ RTL compilation complete"
    cd ../sim
}

# Function to run ROM viewer (fast, no execution)
run_viewer() {
    echo ""
    echo "[2/3] Compiling ROM viewer testbench..."
    vcom -93 tb_rom_viewer.vhd || exit 1
    echo "    ✓ Testbench compiled"

    echo ""
    echo "[3/3] Running ROM content viewer..."
    echo "--------------------------------------------------------------------------------"
    vsim -c work.tb_rom_viewer -do "run 10 us; quit -f"
    echo "--------------------------------------------------------------------------------"
    echo "    ✓ ROM viewer complete"
}

# Function to run full ROM playback (slow, executes all 64 positions)
run_full() {
    echo ""
    echo "[2/3] Compiling full ROM playback testbench..."
    vcom -93 tb_rom_full.vhd || exit 1
    echo "    ✓ Testbench compiled"

    echo ""
    echo "[3/3] Running full ROM playback (this may take a while)..."
    echo "--------------------------------------------------------------------------------"
    vsim -c work.tb_rom_full -do "run 100 ms; quit -f"
    echo "--------------------------------------------------------------------------------"
    echo "    ✓ Full playback complete"
}

# Main execution
case "$TEST_MODE" in
    viewer)
        compile_rtl
        run_viewer
        ;;
    full)
        compile_rtl
        run_full
        ;;
    all)
        compile_rtl
        run_viewer
        echo ""
        echo "================================================================================"
        run_full
        ;;
    *)
        echo "ERROR: Invalid test mode '$TEST_MODE'"
        echo "Usage: $0 [viewer|full|all]"
        echo ""
        echo "  viewer  - Quick ROM content display (no execution)"
        echo "  full    - Execute all 64 ROM positions (slow)"
        echo "  all     - Run both tests (default)"
        exit 1
        ;;
esac

echo ""
echo "================================================================================"
echo "  All tests complete!"
echo "================================================================================"
