# Non-Linear Distortion (tanh) Module (AXI-Stream) on FPGA

This repository provides a **reference RTL implementation** of a
**lookup-table based non-linear distortion (tanh) DSP block**
implemented in **Verilog** and integrated with **AXI-Stream**.

Target platform: **AMD Kria KV260**  
Focus: **RTL architecture, fixed-point DSP decisions, and AXI correctness**

---

## Overview

This module implements:

- **Function**: Soft non-linear distortion using a `tanh()` characteristic  
- **Data type**: Fixed-point arithmetic (Q1.15, Q2.14)  
- **Scope**: Minimal, single-purpose DSP building block  

The design is intentionally **not generic** and **not feature-rich**.  
It exists to demonstrate **how non-linear DSP is implemented safely and deterministically in hardware**, not to provide a turnkey audio effect.

---

## Key Characteristics

- RTL written in **Verilog**
- **AXI-Stream** data interface
- **AXI-Lite** control interface (enable & drive)
- Fixed-point arithmetic with explicit bit-width control
- Deterministic, cycle-accurate behavior
- Designed and verified for **real-time audio processing**
- No software runtime included

---

## Architecture

High-level structure:

```
AXI-Stream In
|
v
+-----------------------+
| NLD Core (tanh LUT) |
| - Drive scaling |
| - Abs + sign logic |
| - LUT approximation |
+-----------------------+
|
v
AXI-Stream Out
```

---


Design notes:

- Processing is **fully synchronous**
- No hidden state outside the RTL
- No variable-latency logic
- All arithmetic decisions are explicit and documented

The AXI wrapper is strictly separated from the DSP core.

---

## Data Format

- **AXI-Stream width**: 16-bit
- **Audio sample format**: Q1.15 (signed)
- **Drive control format**: Q2.14 (signed)
- **Channel layout**: Mono stream

All values use two’s complement representation.

---

## Latency

- **Core latency**: 4 clock cycles  
- **AXI wrapper alignment**: +1 clock cycle  
- **Total end-to-end latency**: **5 clock cycles**

Latency is:

- fixed
- deterministic
- independent of input signal amplitude or waveform

Bypass mode uses a matched delay path to preserve alignment.

---

## Verification & Validation

Verification was performed at two levels.

### 1. RTL Simulation

Dedicated testbenches validate:

- Correct tanh-shaped saturation
- Sign symmetry and zero-crossing preservation
- Fixed-point scaling and saturation
- Deterministic pipeline latency
- AXI-Stream handshake correctness
- Bypass vs active path alignment

Simulation results are logged numerically to CSV files.

---

### 2. Hardware Validation

The design was **tested on real FPGA hardware**.

> **Tested on FPGA hardware via PYNQ overlay**

PYNQ was used strictly as:

- signal stimulus
- runtime configuration interface
- observability tool

No Python code, overlays, or bitstreams are included in this repository.

---

## What This Repository Is

- A **clean RTL reference** for non-linear DSP
- A demonstration of:
  - fixed-point design trade-offs
  - LUT-based non-linear approximation
  - AXI-Stream + AXI-Lite integration
- A reusable **building block** for larger FPGA audio pipelines

---

## What This Repository Is Not

- ❌ A complete audio effect or pedal
- ❌ An analog-accurate distortion model
- ❌ A psychoacoustically validated system
- ❌ A parameter-heavy generic IP
- ❌ A software-driven demo

The scope is intentionally constrained.

---

## Design Rationale (Summary)

Key design decisions:

- **LUT-based tanh approximation**  
  → predictable resource usage, no iterative math

- **Fixed-point arithmetic only**  
  → deterministic behavior, FPGA-safe implementation

- **Explicit saturation and bounds checking**  
  → no overflow or wrap-around artifacts

- **Separated core and AXI wrapper**  
  → clarity, reuse, and easier verification

- **Minimal control surface (enable + drive)**  
  → avoids feature creep and unstable configurations

These choices reflect **engineering trade-offs**, not missing features.

---

## Project Status

This repository is considered **complete**.

- RTL is stable
- Simulation and hardware validation are complete
- No further feature development is planned

The design is published as a **reference implementation**.

---

## License

Licensed under the MIT License.  
Provided as-is, without warranty.

---

> **This repository demonstrates design decisions, not design possibilities.**
