# Synopsys Design Constraints (SDC) file for CNC 3-Axis FPGA Controller
# Target device: Cyclone IV EP4CE6E22C8
# Design: cnc_3axis_rom_top
# Clock: 50 MHz (20ns period)

# Create base clock constraint
create_clock -name clk -period 20.000 [get_ports {clk}]

# Derive clock uncertainty (jitter, skew)
derive_clock_uncertainty

# Set input delays (assume 5ns setup time from external devices)
set_input_delay -clock clk -max 5.000 [all_inputs]
set_input_delay -clock clk -min 1.000 [all_inputs]

# Set output delays (assume 5ns before next device samples)
set_output_delay -clock clk -max 5.000 [all_outputs]
set_output_delay -clock clk -min 1.000 [all_outputs]

# Exclude clock and reset from I/O delay constraints
remove_input_delay [get_ports {clk}]
remove_input_delay [get_ports {rst}]

# Set false paths for asynchronous reset
set_false_path -from [get_ports {rst}] -to [all_registers]

# Set false paths for asynchronous inputs (limit switches, encoder inputs)
set_false_path -from [get_ports {limit_*}] -to [all_registers]
set_false_path -from [get_ports {enc_*}] -to [all_registers]

# Report timing paths
#report_timing -setup -npaths 10
#report_timing -hold -npaths 10
