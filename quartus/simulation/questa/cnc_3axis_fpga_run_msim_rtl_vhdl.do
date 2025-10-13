transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/cnc_pkg.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/trajectory_rom.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/rom_controller.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/encoder_simulator.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/step_dir_generator.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/encoder_decoder.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/cnc_3axis_controller.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/bresenham_axis.vhd}
vcom -93 -work work {/home/angelocoppi/quartus_wb/cnc_fpga/rtl/cnc_3axis_rom_top.vhd}

