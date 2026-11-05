`timescale 1ns / 1ps

module tb_conv_engine;

    localparam int NUM_TERMS = 9;

    logic clk;
    logic n_rst;
    logic start;
    logic input_valid;
    logic signed [7:0] activation;
    logic signed [7:0] weight;

    logic busy;
    logic done;
    logic signed [31:0] result;

    int checks;
    int expected_sum;

    conv_engine #(.NUM_TERMS(NUM_TERMS)) DUT (.clk(clk), .n_rst(n_rst), .start(start), .input_valid(input_valid), .activation(activation), .weight(weight), .busy(busy), .done(done), .result(result));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_state(
        input logic expected_busy,
        input logic expected_done,
        input logic signed [31:0] expected_result,
        input string test_name
    );
        checks++;

        if ((busy !== expected_busy) || (done !== expected_done) || (result !== expected_result)) begin
            $fatal(1, "%s: expected busy=%b done=%b result=%0d; got busy=%b done=%b result=%0d", test_name, expected_busy, expected_done, expected_result, busy, done, result);
        end
        $display("PASS: %s | busy=%b done=%b result=%0d", test_name, busy, done, result);
    endtask

    // Drive inputs on a falling edge and check after the
    // following rising edge, once sequential updates settle.
    task automatic run_cycle(
        input logic start_value,
        input logic valid_value,
        input logic signed [7:0] activation_value,
        input logic signed [7:0] weight_value,
        input logic expected_busy,
        input logic expected_done,
        input logic signed [31:0] expected_result,
        input string test_name
    );
        @(negedge clk);
        start = start_value;
        input_valid = valid_value;
        activation = activation_value;
        weight = weight_value;

        @(posedge clk);
        #1;
        check_state(expected_busy, expected_done, expected_result, test_name);
    endtask

    initial begin
        checks      = 0;
        expected_sum = 0;

        n_rst = 1'b1;
        start = 1'b0;
        input_valid = 1'b0;
        activation = '0;
        weight = '0;

        // Initial asynchronous reset.
        #1;
        n_rst = 1'b0;
        #1;
        check_state(0, 0, 0, "Initial reset");

        @(negedge clk);
        n_rst = 1'b1;

        // Valid data while idle must not be accumulated.
        run_cycle(0, 1, 8'sd10, 8'sd10, 0, 0, 0, "Ignore data while idle");

        // Start clears the accumulator. Data on this edge
        // must not be counted as the first term.
        run_cycle(1, 1, 8'sd100, 8'sd100, 1, 0, 0, "Start initializes computation");

        // First computation: 1*1 + 2*1 + ... + 9*1 = 45.
        for (int i = 1; i <= NUM_TERMS; i++) begin
            // Insert a pause before the fourth pair.
            if (i == 4) begin
                run_cycle(0, 0, 8'sd99, 8'sd99, 1, 0, expected_sum, "Pause preserves partial sum");
            end

            expected_sum = expected_sum + i;

            run_cycle(0, 1, i, 8'sd1, (i < NUM_TERMS), (i == NUM_TERMS), expected_sum, $sformatf("Positive computation, term %0d", i));
        end

        // Done must drop after one cycle. Extra valid data
        // while idle must not change the completed result.
        run_cycle(0, 1, 8'sd50, 8'sd50, 0, 0, 45, "Done pulse ends; result holds");

        // Start another computation without resetting.
        run_cycle(1, 0, 8'sd0, 8'sd0, 1, 0, 0, "Restart clears previous result");

        // Second computation: nine copies of (-2)*3 = -54.
        expected_sum = 0;

        for (int i = 1; i <= NUM_TERMS; i++) begin
            expected_sum = expected_sum - 6;

            // Assert start on term 3 to verify that it is
            // ignored while the engine is already busy.
            run_cycle((i == 3), 1, -8'sd2, 8'sd3, (i < NUM_TERMS), (i == NUM_TERMS), expected_sum, $sformatf("Signed computation, term %0d", i));
        end

        run_cycle(0, 0, 8'sd0, 8'sd0, 0, 0, -54, "Signed result holds");

        // Begin a third computation, then reset mid-operation.
        run_cycle(1, 0, 8'sd0, 8'sd0, 1, 0, 0, "Start before reset test");

        run_cycle(0, 1, 8'sd6, 8'sd7, 1, 0, 42, "Partial sum before reset");

        @(negedge clk);
        start = 1'b0;
        input_valid = 1'b0;

        #2;
        n_rst = 1'b0;
        #1;
        check_state(0, 0, 0, "Asynchronous reset while busy");

        @(negedge clk);
        n_rst = 1'b1;

        run_cycle(0, 0, 8'sd0, 8'sd0, 0, 0, 0, "Idle after reset");

        $display("All %0d checks passed.", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Testbench timed out");
    end

endmodule