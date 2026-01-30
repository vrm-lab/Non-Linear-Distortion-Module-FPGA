# Validation Notes

This module was validated at both RTL and hardware levels.

---

## RTL Simulation

Two testbenches are provided:

- `tb_nld_tanh_core_16`
- `tb_axis_nld_psycho_simple`

Validation focuses on:

- Correct saturation behavior
- Sign symmetry
- Latency alignment
- Bypass correctness

Simulation outputs are logged to CSV
for offline inspection and plotting.

---

## Hardware Validation

Hardware testing was performed using:

- PYNQ overlay
- AXI DMA streaming
- Real-time audio samples

PYNQ is used as:

- Stimulus generator
- Runtime configuration interface
- Observability tool

---

## Excluded Artifacts

The following are intentionally not published:

- Bitstreams
- Overlay files
- Python notebooks

The goal is to validate the RTL design,
not to distribute a finished product.

---

## Status

This design is considered **complete** within its defined scope.

No further feature expansion is planned.
