`timescale 1ns/1ps

// ============================================================================
// Testbench: nld_tanh_core_16
// ----------------------------------------------------------------------------
// Purpose:
// - Functional verification of the tanh-based NLD core
// - Validate saturation behavior and fixed-point correctness
// - Generate CSV output for offline analysis (Python / MATLAB)
//
// Strategy:
// - Drive a sine wave input (A4 = 440 Hz)
// - Sweep input amplitude to observe transition from linear to saturation
// - Align input/output samples using a fixed latency delay line
//
// Output:
// - tb_data_nld_core.csv
//   Columns: sample_index, x_input_aligned, y_output
// ============================================================================

module tb_nld_tanh_core_16;

    // =========================================================================
    // Clock Generation
    // -------------------------------------------------------------------------
    // 100 MHz simulation clock
    // =========================================================================
    reg clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // DUT Signals
    // =========================================================================
    reg  rst;
    reg  en;
    reg  signed [15:0] x;       // Input sample (Q1.15)
    reg  signed [15:0] drive;   // Drive parameter (Q2.14)
    wire signed [15:0] y;       // Output sample (Q1.15)

    // =========================================================================
    // File Output
    // -------------------------------------------------------------------------
    // CSV file for offline inspection and plotting
    // =========================================================================
    integer file_out;

    // =========================================================================
    // Device Under Test
    // =========================================================================
    nld_tanh_core_16 dut (
        .clk   (clk),
        .rst   (rst),
        .en    (en),
        .x     (x),
        .drive (drive),
        .y     (y)
    );

    // =========================================================================
    // Latency Alignment
    // -------------------------------------------------------------------------
    // The NLD core has a fixed pipeline latency.
    // Input samples are delayed to align with output samples.
    // =========================================================================
    localparam integer LAT = 4;
    reg signed [15:0] x_delayed [0:LAT-1];

    // =========================================================================
    // Audio Signal Generation (Real Domain)
    // -------------------------------------------------------------------------
    // Used only for stimulus generation inside the testbench.
    // =========================================================================
    real phase = 0.0;
    real freq  = 440.0;     // A4 tone
    real fs    = 48000.0;   // Sample rate
    real amp   = 0.0;

    integer i, k;

    // =========================================================================
    // Helper Function: Float to Q1.15 Conversion
    // =========================================================================
    function signed [15:0] f2q15(input real v);
        begin
            if (v >  1.0) v =  1.0;
            if (v < -1.0) v = -1.0;
            f2q15 = $rtoi(v * 32767.0);
        end
    endfunction

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        // Open CSV file and write header
        file_out = $fopen("tb_data_nld_core.csv", "w");
        $fdisplay(file_out, "sample,x_input,y_output");

        // Initial conditions
        rst   = 1'b1;
        en    = 1'b0;
        x     = 16'd0;
        drive = 16'h4000;   // Drive = 1.0 (Q2.14)

        for (k = 0; k < LAT; k = k + 1)
            x_delayed[k] = 16'd0;

        // Release reset
        #100;
        rst = 1'b0;
        en  = 1'b1;

        // ------------------------------------------------------------
        // Audio-style stimulus:
        // - First half: moderate amplitude (mostly linear region)
        // - Second half: high amplitude (strong saturation)
        // ------------------------------------------------------------
        for (i = 0; i < 10000; i = i + 1) begin
            amp = (i < 5000) ? 0.5 : 1.2;

            phase = phase + (2.0 * 3.1415926535 * freq / fs);
            x = f2q15(amp * $sin(phase));

            @(posedge clk);

            // Log aligned input/output samples
            if (i > LAT) begin
                $fdisplay(file_out, "%d,%d,%d",
                          i, x_delayed[LAT-1], y);
            end
        end

        // Close file and finish simulation
        $fclose(file_out);
        $display("Simulation complete. Output written to tb_data_nld_core.csv");
        $finish;
    end

    // =========================================================================
    // Input Delay Line (Latency Compensation)
    // =========================================================================
    always @(posedge clk) begin
        if (en) begin
            x_delayed[0] <= x;
            for (k = 1; k < LAT; k = k + 1)
                x_delayed[k] <= x_delayed[k-1];
        end
    end

endmodule
