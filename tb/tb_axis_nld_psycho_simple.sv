`timescale 1ns / 1ps

// ============================================================================
// Testbench: axis_nld_psycho_simple
// ----------------------------------------------------------------------------
// Purpose:
// - End-to-end verification of AXI-Stream NLD wrapper
// - Validate:
//   * AXI-Lite control (bypass / enable / drive)
//   * AXI-Stream data flow
//   * Latency alignment between bypass and processed paths
//
// Strategy:
// - Generate sine wave stimulus (A4 = 440 Hz)
// - Run two phases:
//   1) Bypass mode
//   2) Active tanh NLD mode
// - Log aligned input/output samples to CSV
//
// Output:
// - tb_data_nld_axis.csv
//   Columns: sample_index, x_input_aligned, y_output, mode
// ============================================================================

module tb_axis_nld_psycho_simple;

    // ========================================================================
    // 1. CLOCK, RESET, AND BASIC SIGNALS
    // ========================================================================
    parameter CLK_PERIOD = 10; // 100 MHz

    reg aclk = 0;
    reg aresetn;

    // =========================================================================
    // AXI-Lite Signals (subset used for control only)
    // =========================================================================
    reg  [3:0]  s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire        s_axi_bvalid;
    reg         s_axi_bready;

    // =========================================================================
    // AXI-Stream Audio Signals
    // =========================================================================
    reg  [15:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    wire [15:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    // =========================================================================
    // File Logging & Audio Generation
    // =========================================================================
    integer file_csv;
    integer i, k;

    real phase = 0.0;
    real freq  = 440.0;   // A4 tone
    real fs    = 48000.0; // Sample rate
    real amp   = 0.8;     // Amplitude chosen to show saturation

    // =========================================================================
    // Latency Alignment
    // -------------------------------------------------------------------------
    // TOTAL_LAT = CORE_LATENCY (4) + output register / mux stage (1)
    // =========================================================================
    localparam integer TOTAL_LAT = 5;
    reg signed [15:0] x_history [0:TOTAL_LAT-1];

    // =========================================================================
    // 2. DEVICE UNDER TEST
    // =========================================================================
    axis_nld_psycho_simple #(
        .CORE_LATENCY(4)
    ) dut (
        .aclk            (aclk),
        .aresetn         (aresetn),

        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),

        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),

        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),

        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),

        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready),

        // Unused AXI-Lite read channels are tied off
        .s_axi_arvalid   (1'b0),
        .s_axi_rready    (1'b0)
    );

    // =========================================================================
    // Clock Generator
    // =========================================================================
    always #(CLK_PERIOD/2) aclk = ~aclk;

    // =========================================================================
    // AXI-Lite Write Task
    // -------------------------------------------------------------------------
    // Simplified single-register write transaction
    // =========================================================================
    task axi_write;
        input [3:0]  addr;
        input [31:0] data;
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            wait (s_axi_awready && s_axi_wready);
            @(posedge aclk);

            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            wait (s_axi_bvalid);
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    // =========================================================================
    // 3. MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        // Open CSV file
        file_csv = $fopen("tb_data_nld_axis.csv", "w");
        $fdisplay(file_csv, "sample,x_in,y_out,mode");

        // Reset and init
        aresetn        = 1'b0;
        s_axis_tvalid  = 1'b0;
        m_axis_tready  = 1'b1;

        for (k = 0; k < TOTAL_LAT; k = k + 1)
            x_history[k] = 16'd0;

        #100;
        aresetn = 1'b1;

        // ------------------------------------------------------------
        // TEST 1: BYPASS MODE
        // ------------------------------------------------------------
        $display("Testing Bypass Mode...");
        for (i = 0; i < 1000; i = i + 1) begin
            send_audio_sample();
        end

        // ------------------------------------------------------------
        // Configure NLD via AXI-Lite
        // ------------------------------------------------------------
        $display("Configuring NLD via AXI-Lite...");
        axi_write(4'h4, 32'd24576); // Drive = 1.5 (Q2.14)
        axi_write(4'h0, 32'd1);     // Enable NLD

        // ------------------------------------------------------------
        // TEST 2: ACTIVE TANH MODE
        // ------------------------------------------------------------
        $display("Testing Active Tanh Mode...");
        for (i = 1000; i < 3000; i = i + 1) begin
            send_audio_sample();
        end

        #200;
        $fclose(file_csv);
        $display("Simulation complete. Output written to tb_data_nld_axis.csv");
        $finish;
    end

    // =========================================================================
    // Audio Sample Generator
    // =========================================================================
    task send_audio_sample;
        begin
            @(posedge aclk);
            if (s_axis_tready) begin
                phase = phase + (2.0 * 3.14159265 * freq / fs);
                s_axis_tdata  = $rtoi($sin(phase) * 32000.0);
                s_axis_tvalid = 1'b1;
            end
        end
    endtask

    // =========================================================================
    // 4. DATA LOGGING WITH LATENCY ALIGNMENT
    // =========================================================================
    always @(posedge aclk) begin
        if (aresetn) begin
            // Shift input history for alignment
            x_history[0] <= $signed(s_axis_tdata);
            for (k = 1; k < TOTAL_LAT; k = k + 1)
                x_history[k] <= x_history[k-1];

            // Log aligned samples when output is valid
            if (m_axis_tvalid && m_axis_tready) begin
                $fdisplay(file_csv, "%0d,%d,%d,%d",
                          i,
                          $signed(x_history[TOTAL_LAT-1]),
                          $signed(m_axis_tdata),
                          dut.reg_ctrl[0]);
            end
        end
    end

endmodule
