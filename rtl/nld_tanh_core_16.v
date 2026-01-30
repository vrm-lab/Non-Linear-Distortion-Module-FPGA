`timescale 1ns/1ps

// ============================================================================
// Non-Linear Distortion Core (tanh-based)
// ----------------------------------------------------------------------------
// Fixed-point, deterministic, pipelined implementation of tanh waveshaping
// using a precomputed LUT.
//
// - Input  : signed Q1.15
// - Drive  : signed Q2.14
// - Output : signed Q1.15
//
// Latency  : 5 cycles (fully deterministic)
// Target  : AXI-Stream DSP pipeline (core only, no AXI logic here)
//
// Notes:
// - This module focuses purely on arithmetic behavior.
// - No variable latency, no implicit buffering, no control logic.
// ============================================================================

module nld_tanh_core_16 #(
    parameter integer INT_W = 24,   // Internal fixed-point width
    parameter integer ACC_W = 32    // Accumulator width for multiply
)(
    input  wire clk,
    input  wire rst,
    input  wire en,

    input  wire signed [15:0] x,       // Input sample  (Q1.15)
    input  wire signed [15:0] drive,   // Drive control (Q2.14)

    output reg  signed [15:0] y        // Output sample (Q1.15)
);

    // =========================================================================
    // Stage 1: Drive Multiply
    // -------------------------------------------------------------------------
    // Multiply input sample with drive factor.
    // Result is kept in higher precision accumulator before scaling back.
    // =========================================================================
    reg  signed [ACC_W-1:0] xd_acc;
    wire signed [INT_W-1:0] xd = xd_acc >>> 14;  // Align back to internal format

    // =========================================================================
    // Stage 2: Absolute Value & Sign Capture
    // -------------------------------------------------------------------------
    // tanh() is an odd function, so only positive domain is stored in LUT.
    // Sign is extracted and delayed through the pipeline.
    // =========================================================================
    reg signed [INT_W-1:0] abs_x;
    reg                   sign_s2;

    // =========================================================================
    // Stage 3: LUT Address Generation
    // -------------------------------------------------------------------------
    // The positive input domain [0.0, 4.0] is mapped to LUT indices [0, 255].
    // Values beyond the domain are saturated to the maximum LUT entry.
    // =========================================================================
    reg [7:0] lut_addr;
    reg       sign_s3;

    // =========================================================================
    // Stage 4: LUT Read
    // -------------------------------------------------------------------------
    // Precomputed tanh() values in Q1.15 format.
    // LUT stores only the positive half of the function.
    // =========================================================================
    reg signed [15:0] tanh_lut [0:255];
    reg signed [15:0] lut_out;
    reg               sign_s4;

    // =========================================================================
    // LUT Initialization
    // -------------------------------------------------------------------------
    // Hardcoded tanh lookup table for deterministic synthesis.
    // No external memory or runtime initialization required.
    // =========================================================================
    initial begin
        tanh_lut[0]   = 16'h0000;
        tanh_lut[1]   = 16'h0201;
        tanh_lut[2]   = 16'h0403;
        tanh_lut[3]   = 16'h0604;
        tanh_lut[4]   = 16'h0805;
        tanh_lut[5]   = 16'h0A04;
        tanh_lut[6]   = 16'h0C02;
        tanh_lut[7]   = 16'h0DFF;
        tanh_lut[8]   = 16'h0FFA;
        tanh_lut[9]   = 16'h11F3;
        tanh_lut[10]  = 16'h13EA;
        tanh_lut[11]  = 16'h15DE;
        tanh_lut[12]  = 16'h17D0;
        tanh_lut[13]  = 16'h19BE;
        tanh_lut[14]  = 16'h1BAA;
        tanh_lut[15]  = 16'h1D92;
        // ...
        // (LUT contents unchanged — truncated here for readability)
        // ...
        tanh_lut[255] = 16'h7FE9;
    end

    // =========================================================================
    // Pipeline Registers
    // -------------------------------------------------------------------------
    // Fully synchronous pipeline.
    // All state is explicitly reset.
    // No variable latency or hidden buffering.
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            xd_acc   <= 0;
            abs_x    <= 0;
            sign_s2  <= 0;
            sign_s3  <= 0;
            sign_s4  <= 0;
            lut_addr <= 0;
            lut_out  <= 0;
            y        <= 0;
        end else if (en) begin

            // ------------------------------------------------------------
            // Stage 1: Drive Scaling
            // ------------------------------------------------------------
            xd_acc <= x * drive;

            // ------------------------------------------------------------
            // Stage 2: Sign Extraction and Absolute Value
            // ------------------------------------------------------------
            sign_s2 <= xd[INT_W-1];
            abs_x   <= xd[INT_W-1] ? -xd : xd;

            // ------------------------------------------------------------
            // Stage 3: LUT Address Mapping
            // ------------------------------------------------------------
            sign_s3 <= sign_s2;

            // Saturate if input exceeds LUT domain (>= 4.0)
            if (abs_x[INT_W-1:17] != 0) begin
                lut_addr <= 8'hFF;
            end else begin
                // Use fractional bits to index LUT
                lut_addr <= abs_x[16:9];
            end

            // ------------------------------------------------------------
            // Stage 4: LUT Read
            // ------------------------------------------------------------
            sign_s4 <= sign_s3;
            lut_out <= tanh_lut[lut_addr];

            // ------------------------------------------------------------
            // Stage 5: Sign Restoration
            // ------------------------------------------------------------
            y <= sign_s4 ? -lut_out : lut_out;
        end
    end

endmodule
