# Latency and Data Format

This document defines the fixed latency and data formats
used by the NLD module.

---

## Data Formats

| Signal | Format | Description                |
|------|--------|----------------------------|
| Input `x` | Q1.15 | Signed audio sample       |
| Drive    | Q2.14 | Pre-gain multiplier       |
| Output `y` | Q1.15 | Saturated audio output   |

All formats are signed two's complement.

---

## Internal Pipeline

The tanh core uses a fixed pipeline:

1. Drive multiplication
2. Absolute value + sign capture
3. LUT address computation
4. LUT read
5. Sign restoration

---

## Latency Summary

| Block | Latency (cycles) |
|------|------------------|
| `nld_tanh_core_16` | 4 |
| AXI wrapper mux   | +1 |
| **Total**         | **5 cycles** |

Latency is:

- Constant
- Deterministic
- Independent of input value

---

## Bypass Alignment

When bypass mode is active:

- Input samples are delayed by the same number of cycles
- Output alignment remains consistent

This guarantees seamless runtime switching
between bypass and active modes.
