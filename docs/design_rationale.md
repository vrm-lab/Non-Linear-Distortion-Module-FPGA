# Design Rationale

This module implements a **fixed-point, lookup-table based**
hyperbolic tangent (`tanh`) non-linear distortion function.

The design prioritizes:

- Deterministic behavior
- Fixed latency
- FPGA-safe arithmetic
- Clear separation of concerns

---

## Why tanh?

The `tanh()` function provides:

- Soft saturation
- Smooth transition from linear to non-linear region
- Bounded output range

This makes it suitable as a **generic non-linear building block**
in audio DSP pipelines.

No claim is made regarding analog accuracy or perceptual modeling.

---

## LUT-Based Approximation

The tanh function is implemented using:

- Absolute value mapping
- 256-entry lookup table
- Explicit saturation beyond the LUT domain

Reasons:

- Predictable resource usage
- No iterative math
- No variable latency

---

## Fixed-Point First

All arithmetic is explicitly fixed-point:

- Input: Q1.15
- Drive: Q2.14
- Internal accumulation: wider signed format
- Output: Q1.15

This avoids implicit scaling and hidden rounding behavior.

---

## Separation of Concerns

The design is split into:

- **Core**: pure arithmetic, no AXI logic
- **Wrapper**: AXI-Stream + AXI-Lite integration

This allows the NLD core to be reused or replaced
without touching the AXI infrastructure.

---

## Non-Goals

This design intentionally does **not** aim to be:

- Analog-model accurate
- Oversampled
- Psychoacoustically validated
- Parameter-heavy or adaptive

It is a deterministic DSP building block.
