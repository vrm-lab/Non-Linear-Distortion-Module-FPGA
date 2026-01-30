# ============================================================================
# Minimal Vivado Project Creation Script
# ----------------------------------------------------------------------------
# Project : NLD (Non-Linear Distortion)
# Purpose : Recreate a minimal Vivado project for simulation and synthesis
# Tool    : Vivado 2024.1+
#
# Notes:
# - This script intentionally avoids full Block Design reconstruction.
# - Focus is on RTL + testbench reproducibility.
# - Bitstreams, GUI layout, and IP cache are out of scope.
# ============================================================================

# ------------------------------------------------------------
# User-adjustable variables
# ------------------------------------------------------------
set proj_name "nld_fpga"
set part_name "xck26-sfvc784-2LV-c"

# Root directory (repo root expected)
set origin_dir [file normalize "."]

# ------------------------------------------------------------
# Create project
# ------------------------------------------------------------
create_project $proj_name ./$proj_name -part $part_name -force
set_property board_part xilinx.com:kv260_som:part0:1.4 [current_project]

# ------------------------------------------------------------
# Source files (RTL)
# ------------------------------------------------------------
add_files -fileset sources_1 [list \
    "$origin_dir/rtl/nld_tanh_core_16.v" \
    "$origin_dir/rtl/axis_nld_psycho_simple.v" \
]

# ------------------------------------------------------------
# Simulation files (Testbench)
# ------------------------------------------------------------
add_files -fileset sim_1 [list \
    "$origin_dir/tb/tb_nld_tanh_core_16.v" \
    "$origin_dir/tb/tb_axis_nld_psycho_simple.sv" \
]

set_property top tb_axis_nld_psycho_simple [get_filesets sim_1]
set_property simulator_language Mixed [current_project]

# ------------------------------------------------------------
# Basic synthesis & implementation runs
# ------------------------------------------------------------
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -flow {Vivado Synthesis 2024}
}

if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -parent_run synth_1 -flow {Vivado Implementation 2024}
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
puts "INFO: Minimal NLD project created successfully."
puts "INFO: You may now run simulation or synthesis manually."
