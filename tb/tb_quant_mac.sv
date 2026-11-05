`timescale 1ns / 1ps

module tb_quant_mac;
    logic clk;
    logic n_rst;
    logic clear;
    logic enable;
    logic signed [7:0] activation;
    logic signed [7:0] weight;
    logic signed [31:0] result;

    int checks;

    quant_mac DUT (.clk(clk), .n_rst(n_rst), .clear(clear), .enable(enable), .activation(activation), .weight(weight), .result(result));

    inital clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_result(
        input logic signed [31:0] expected,
        input string test_name
    );
        checks++;

        // Case inequality also catches X and Z values.
        if (result !== expected) begin
            $fatal(1, "%s: expected %0d, got %0d",
                   test_name, expected, result);
        end

        $display("PASS: %s | result = %0d", test_name, result);
    endtask

    task automatic run_cycle(
        input logic clear_value,
        input logic enable_value,
        input logic signed [7:0] activation_value,
        input logic signed [7:0] weight_value,
        input logic signed [31:0] expected,
        input string test_name
    );
        @(negedge clk);
        clear      = clear_value;
        enable     = enable_value;
        activation = activation_value;
        weight     = weight_value;

        @(posedge clk);
        #1;
        check_result(expected, test_name);
    endtask

    initial begin
        checks     = 0;
        n_rst      = 1'b1;
        clear      = 1'b0;
        enable     = 1'b0;
        activation = '0;
        weight     = '0;

        // Assert reset between clock edges.
        #1;
        n_rst = 1'b0;
        #1;
        check_result(0, "Initial asynchronous reset");

        @(negedge clk);
        n_rst = 1'b1;

        run_cycle(0, 1,  8'sd3,  8'sd4,  12, "Positive product: 3 * 4");

        run_cycle(0, 1, -8'sd2,  8'sd5,   2, "Negative product: 12 + (-2 * 5)");

        run_cycle(0, 1, -8'sd3, -8'sd4,  14, "Two negative inputs: 2 + (-3 * -4)");

        run_cycle(0, 0,  8'sd7,  8'sd9,  14, "Disabled accumulator holds");

        run_cycle(0, 1,  8'sd0,  8'sd9,  14, "Zero product");

        run_cycle(1, 0,  8'sd0,  8'sd0,   0, "Synchronous clear");

        run_cycle(0, 1,  8'sd127, 8'sd127, 16129, "Maximum positive operands");

        // 8'sh80 represents -128 in signed 8-bit format.
        run_cycle(0, 1,  8'sh80, 8'sh80, 32513, "Minimum operands: -128 * -128");

        run_cycle(0, 1,  8'sh80, 8'sd127, 16257, "Boundary negative product: -128 * 127");

        run_cycle(1, 1,  8'sd10, 8'sd10, 0, "Clear takes priority over enable");

        run_cycle(0, 1,  8'sd6, 8'sd7, 42, "Accumulate after clear");

        // Assert reset while the accumulator is nonzero,
        // before the next rising clock edge.
        @(negedge clk);
        enable = 1'b0;
        #2;
        n_rst = 1'b0;
        #1;
        check_result(0, "Asynchronous reset of nonzero accumulator");

        @(negedge clk);
        n_rst = 1'b1;

        run_cycle(0, 1, -8'sd7, 8'sd6, -42, "Accumulate after reset");

        $display("All %0d checks passed.", checks);
        $finish;
    end

    // Stop if the testbench unexpectedly hangs.
    initial begin
        #1000;
        $fatal(1, "Testbench timed out");
    end

endmodule