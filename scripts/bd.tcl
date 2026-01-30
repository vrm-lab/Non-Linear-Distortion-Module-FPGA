# ============================================================================
# Minimal Block Design Script
# ----------------------------------------------------------------------------
# Design  : NLD (Non-Linear Distortion)
# Purpose : Reference AXI-based integration of NLD core
# Tool    : Vivado 2024.1+
#
# Notes:
# - This script documents the AXI topology used for hardware validation.
# - It is NOT intended to fully recreate the original Vivado project.
# - Board presets, DDR mapping, and PS fine-tuning are intentionally omitted.
# ============================================================================

set design_name "nld_bd"

# ------------------------------------------------------------
# Create project & BD (if needed)
# ------------------------------------------------------------
if {[get_projects -quiet] eq ""} {
    create_project nld_proj ./nld_proj -part xck26-sfvc784-2LV-c
    set_property board_part xilinx.com:kv260_som:part0:1.4 [current_project]
}

if {[get_files -quiet ${design_name}.bd] eq ""} {
    create_bd_design $design_name
}
current_bd_design $design_name

# ------------------------------------------------------------
# Required IP blocks
# ------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_lite_ic
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mm_ic

# ------------------------------------------------------------
# Custom RTL module
# ------------------------------------------------------------
create_bd_cell -type module -reference axis_nld_psycho_simple nld

# ------------------------------------------------------------
# Clock & reset
# ------------------------------------------------------------
connect_bd_net [get_bd_pins ps/pl_clk0] \
               [get_bd_pins nld/aclk] \
               [get_bd_pins axi_dma/m_axi_mm2s_aclk] \
               [get_bd_pins axi_dma/m_axi_s2mm_aclk] \
               [get_bd_pins axi_dma/s_axi_lite_aclk] \
               [get_bd_pins axi_lite_ic/ACLK]

connect_bd_net [get_bd_pins ps/pl_resetn0] \
               [get_bd_pins rst/ext_reset_in]

connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
               [get_bd_pins nld/aresetn] \
               [get_bd_pins axi_dma/axi_resetn] \
               [get_bd_pins axi_lite_ic/ARESETN]

# ------------------------------------------------------------
# AXI-Stream data path
# ------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins axi_dma/M_AXIS_MM2S] \
                    [get_bd_intf_pins nld/s_axis]

connect_bd_intf_net [get_bd_intf_pins nld/m_axis] \
                    [get_bd_intf_pins axi_dma/S_AXIS_S2MM]

# ------------------------------------------------------------
# AXI-Lite control path
# ------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_lite_ic/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_lite_ic/M00_AXI] \
                    [get_bd_intf_pins axi_dma/S_AXI_LITE]

connect_bd_intf_net [get_bd_intf_pins axi_lite_ic/M01_AXI] \
                    [get_bd_intf_pins nld/s_axi]

# ------------------------------------------------------------
# Validate & save
# ------------------------------------------------------------
validate_bd_design
save_bd_design

puts "INFO: Minimal NLD block design created."
