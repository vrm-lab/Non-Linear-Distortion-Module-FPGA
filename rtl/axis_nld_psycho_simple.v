`timescale 1 ns / 1 ps

// ============================================================================
// AXI-Stream Non-Linear Distortion Module (tanh-based, simple psycho model)
// ----------------------------------------------------------------------------
// This module wraps a fixed-latency tanh NLD core with:
//
// - AXI4-Stream audio input/output
// - AXI4-Lite control interface
// - Deterministic latency compensation for bypass vs processed path
//
// Control Registers:
//   Reg0[0] : Enable (1 = NLD active, 0 = bypass)
//   Reg1    : Drive parameter (Q2.14)
//
// Notes:
// - This is a simple, deterministic non-linear processor.
// - No dynamic buffering, no variable latency, no feedback paths.
// - Designed to be used as a building block in larger DSP pipelines.
// ============================================================================

module axis_nld_psycho_simple #
(
    // ================= AXI4-Lite Parameters =================
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4,

    // ================= AXI4-Stream Audio ====================
    parameter integer C_AXIS_DATA_WIDTH = 16,

    // ================= Core Latency =========================
    // Fixed latency of the internal NLD core (in cycles)
    parameter integer CORE_LATENCY = 4
)
(
    // ================= Global Clock & Reset =================
    input wire  aclk,
    input wire  aresetn, // Active-low synchronous reset

    // ================= AXI4-LITE =============================
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input wire  s_axi_awvalid,
    output reg  s_axi_awready,

    input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
    input wire  s_axi_wvalid,
    output reg  s_axi_wready,

    output reg [1 : 0] s_axi_bresp,
    output reg  s_axi_bvalid,
    input wire  s_axi_bready,

    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
    input wire  s_axi_arvalid,
    output reg  s_axi_arready,

    output reg [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
    output reg [1 : 0] s_axi_rresp,
    output reg  s_axi_rvalid,
    input wire  s_axi_rready,

    // ================= AXI4-STREAM INPUT ====================
    input wire [C_AXIS_DATA_WIDTH-1 : 0] s_axis_tdata,
    input wire  s_axis_tlast,
    input wire  s_axis_tvalid,
    output wire s_axis_tready,

    // ================= AXI4-STREAM OUTPUT ===================
    output wire [C_AXIS_DATA_WIDTH-1 : 0] m_axis_tdata,
    output wire m_axis_tlast,
    output wire m_axis_tvalid,
    input wire  m_axis_tready
);

    // =========================================================================
    // 1. CONTROL REGISTERS
    // -------------------------------------------------------------------------
    // reg_ctrl[0] : enable / bypass
    // reg_drive   : drive parameter (Q2.14)
    // =========================================================================
    reg [15:0] reg_ctrl;
    reg [15:0] reg_drive;

    // =========================================================================
    // 2. AXI-LITE WRITE CHANNEL
    // -------------------------------------------------------------------------
    // Simple single-cycle register write handling.
    // Address decoding uses word-aligned access.
    // =========================================================================
    always @(posedge aclk) begin
        if (~aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;

            // Default state
            reg_ctrl  <= 16'd0;      // bypass enabled
            reg_drive <= 16'd16384;  // drive = 1.0 (Q2.14)
        end else begin
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;

            if (s_axi_awvalid && s_axi_wvalid) begin
                case (s_axi_awaddr[3:2])
                    2'h0: reg_ctrl  <= s_axi_wdata[15:0];
                    2'h1: reg_drive <= s_axi_wdata[15:0];
                    default: ; // reserved
                endcase
                s_axi_bvalid <= 1'b1;
            end

            if (s_axi_bready && s_axi_bvalid)
                s_axi_bvalid <= 1'b0;
        end
    end

    // =========================================================================
    // 3. AXI-LITE READ CHANNEL
    // -------------------------------------------------------------------------
    // Readback of control and drive registers.
    // =========================================================================
    always @(posedge aclk) begin
        if (~aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
            s_axi_rresp   <= 2'b00;
        end else begin
            s_axi_arready <= 1'b1;

            if (s_axi_arvalid) begin
                s_axi_rvalid <= 1'b1;
                case (s_axi_araddr[3:2])
                    2'h0: s_axi_rdata <= {16'b0, reg_ctrl};
                    2'h1: s_axi_rdata <= {16'b0, reg_drive};
                    default: s_axi_rdata <= 32'd0;
                endcase
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. AUDIO DATA PATH
    // -------------------------------------------------------------------------
    // Includes:
    // - NLD core instantiation
    // - Bypass pipeline for latency alignment
    // - Valid / TLAST delay matching core latency
    // =========================================================================
    wire signed [15:0] core_out_y;

    reg  signed [15:0] bypass_pipe [0:CORE_LATENCY-1];
    reg  [CORE_LATENCY-1:0] valid_pipe;
    reg  [CORE_LATENCY-1:0] last_pipe;

    integer i;

    // Core is advanced only when downstream is ready
    wire core_en = s_axis_tvalid && m_axis_tready;

    // ================= NLD CORE =================
    nld_tanh_core_16 nld_core (
        .clk   (aclk),
        .rst   (~aresetn),
        .en    (core_en),
        .x     (s_axis_tdata),
        .drive (reg_drive),
        .y     (core_out_y)
    );

    // ================= LATENCY ALIGNMENT =================
    // Ensures bypass path and processed path are time-aligned.
    always @(posedge aclk) begin
        if (~aresetn) begin
            valid_pipe <= {CORE_LATENCY{1'b0}};
            last_pipe  <= {CORE_LATENCY{1'b0}};
            for (i = 0; i < CORE_LATENCY; i = i + 1)
                bypass_pipe[i] <= 16'd0;
        end else if (m_axis_tready) begin
            valid_pipe <= {valid_pipe[CORE_LATENCY-2:0], s_axis_tvalid};
            last_pipe  <= {last_pipe[CORE_LATENCY-2:0],  s_axis_tlast};

            bypass_pipe[0] <= s_axis_tdata;
            for (i = 1; i < CORE_LATENCY; i = i + 1)
                bypass_pipe[i] <= bypass_pipe[i-1];
        end
    end

    // =========================================================================
    // 5. AXI-STREAM OUTPUT LOGIC
    // -------------------------------------------------------------------------
    // Select between bypassed signal and processed signal.
    // =========================================================================
    assign s_axis_tready = m_axis_tready;

    assign m_axis_tdata  = (reg_ctrl[0]) ? core_out_y
                                         : bypass_pipe[CORE_LATENCY-1];

    assign m_axis_tvalid = valid_pipe[CORE_LATENCY-1];
    assign m_axis_tlast  = last_pipe[CORE_LATENCY-1];

endmodule
