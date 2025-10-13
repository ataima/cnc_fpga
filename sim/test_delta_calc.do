vcom -93 ../rtl/cnc_pkg.vhd ../rtl/trajectory_rom.vhd ../rtl/rom_controller.vhd
vcom -93 tb_rom_controller_debug.vhd
vsim -c work.tb_rom_controller_debug
add wave -radix decimal sim:/tb_rom_controller_debug/*
add wave -radix decimal sim:/tb_rom_controller_debug/dut/*
run 5 us
quit -f
