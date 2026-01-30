# AXI-Lite Address Map

This document describes the AXI-Lite register map exposed by the
`axis_nld_psycho_simple` module.

The AXI-Lite interface is used exclusively for **static configuration**
of the non-linear distortion behavior during runtime.

---

## Register Summary

| Offset | Name      | Width | Description                      |
|------:|-----------|-------|----------------------------------|
| 0x00  | CTRL      | 16-bit| Enable / Bypass control          |
| 0x04  | DRIVE     | 16-bit| Drive gain for tanh non-linearity|

Unused bits read as zero.

---

## Register Details

### CTRL Register (0x00)

| Bit | Name   | Description                            |
|----:|--------|----------------------------------------|
| 0   | ENABLE | `1`: NLD active, `0`: bypass mode      |
| 15:1| —      | Reserved                               |

Default value after reset: `0x0000` (bypass).

---

### DRIVE Register (0x04)

| Field | Format | Description                          |
|-------|--------|--------------------------------------|
| [15:0] | Q2.14 | Drive multiplier before tanh function|

- `0x4000` → 1.0
- `0x6000` → 1.5
- `0x8000` → 2.0

The drive value scales the input signal before entering
the non-linear tanh lookup table.

---

## Notes

- No dynamic reconfiguration during active AXI-Stream transfers
  is required or assumed.
- Register writes are assumed to occur between audio blocks.

This register map is intentionally minimal by design.
