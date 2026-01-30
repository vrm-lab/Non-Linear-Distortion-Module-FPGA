`timescale 1ns / 1ps

// =============================================================
// Non-Linear Distortion Core (tanh approximation)
// -------------------------------------------------------------
// - Input  : Q1.15
// - Drive  : Q2.14
// - Output : Q1.15
// - Method : |x| → LUT → restore sign
// - Latency: 5 cycles
// =============================================================
module nld_tanh_core_16 #(
    parameter integer INT_W = 24,
    parameter integer ACC_W = 32
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     en,

    input  wire signed [15:0]        x,       // Q1.15
    input  wire signed [15:0]        drive,   // Q2.14

    output reg  signed [15:0]        y        // Q1.15
);

    // =========================================================
    // Stage 1: Drive Multiply (Q1.15 * Q2.14 -> Q3.29)
    // =========================================================
    reg  signed [ACC_W-1:0] xd_acc;
    wire signed [INT_W-1:0] xd = xd_acc >>> 14; // back to ~Q3.15

    // =========================================================
    // Stage 2: Absolute Value & Sign Capture
    // =========================================================
    reg  signed [INT_W-1:0] abs_x;
    reg                     sign_s2;

    // =========================================================
    // Stage 3: LUT Address Mapping
    // =========================================================
    reg  [7:0]              lut_addr;
    reg                     sign_s3;

    // =========================================================
    // Stage 4: LUT Read
    // =========================================================
    reg  signed [15:0]      tanh_lut [0:255];
    reg  signed [15:0]      lut_out;
    reg                     sign_s4;

    // =========================================================
    // LUT Initialization (|x| domain: 0.0 – 4.0)
    // =========================================================
    initial begin
        tanh_lut[0]   = 16'h0000;
        tanh_lut[1]   = 16'h0201;
        // ...
        // (LUT content unchanged – truncated here for clarity)
        // ...
        tanh_lut[254] = 16'h7FE8;
        tanh_lut[255] = 16'h7FE9;
    end

    // =========================================================
    // Pipeline Logic
    // =========================================================
    always @(posedge clk) begin
        if (rst) begin
            xd_acc   <= '0;
            abs_x    <= '0;
            sign_s2  <= 1'b0;
            sign_s3  <= 1'b0;
            sign_s4  <= 1'b0;
            lut_addr <= 8'd0;
            lut_out  <= '0;
            y        <= '0;
        end
        else if (en) begin

            // -------------------------------------------------
            // Stage 1: Drive Scaling
            // -------------------------------------------------
            xd_acc <= x * drive;

            // -------------------------------------------------
            // Stage 2: Absolute Value + Sign
            // -------------------------------------------------
            sign_s2 <= xd[INT_W-1];
            abs_x   <= xd[INT_W-1] ? -xd : xd;

            // -------------------------------------------------
            // Stage 3: LUT Address Mapping
            // -------------------------------------------------
            sign_s3 <= sign_s2;

            // Map |x| ∈ [0,4.0] to LUT index [0,255]
            if (abs_x[INT_W-1:17] != 0) begin
                lut_addr <= 8'hFF;      // saturate
            end else begin
                lut_addr <= abs_x[16:9];
            end

            // -------------------------------------------------
            // Stage 4: LUT Read
            // -------------------------------------------------
            sign_s4 <= sign_s3;
            lut_out <= tanh_lut[lut_addr];

            // -------------------------------------------------
            // Stage 5: Restore Sign
            // -------------------------------------------------
            y <= sign_s4 ? -lut_out : lut_out;
        end
    end

endmodule
