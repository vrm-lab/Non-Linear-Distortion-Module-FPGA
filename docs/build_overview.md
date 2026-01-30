# Build Overview

This repository is intended to be **readable and reproducible**, not
to fully reconstruct a Vivado project environment.

---

## Supported Flow

The reference build flow consists of:

1. RTL simulation (SystemVerilog testbench)
2. Optional synthesis in Vivado
3. Hardware validation using PYNQ overlay

The following artifacts are intentionally excluded:

- Vivado project folders
- Generated IP cache
- Bitstreams
- XSA or HWH files

---

## Vivado Project Creation

A minimal Tcl script is provided to:

- Create a Vivado project
- Add RTL sources
- Add testbench files
- Run simulation or synthesis

This script **does not recreate** the full block design used during
hardware validation.

---

## Block Design (Reference Only)

A simplified `bd.tcl` is provided to document:

- AXI-Stream data path
- AXI-Lite control path
- DMA-based streaming topology

Board presets and PS fine-tuning are intentionally omitted.

---

## Tool Versions

- Vivado: 2024.1 (reference)
- Target platform: AMD Kria KV260

Other versions may work but are not guaranteed.
