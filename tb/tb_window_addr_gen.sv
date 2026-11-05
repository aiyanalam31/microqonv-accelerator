`timescale 1ns / 1ps

module tb_window_addr_gen;

    localparam int IMAGE_WIDTH = 4;
    localparam int ADDR_WIDTH  = 8;

    logic clk;
    logic n_rst;
    logic start;
    logic ready;
    logic [ADDR_WIDTH-1:0] base_addr;
    logic valid;
    logic done;
    logic [ADDR_WIDTH-1:0] image_addr;
    logic [3:0] weight_addr;

    int checks;

    window_addr_gen #(.IMAGE_WIDTH(IMAGE_WIDTH), .ADDR_WIDTH (ADDR_WIDTH)) DUT (.clk(clk), .n_rst(n_rst), .start(start), .base_addr(base_addr), .ready(ready), .valid(valid), .done(done), .image_addr(image_addr), .weight_addr(weight_addr));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_status(
        input logic expected_valid,
        input logic expected_done,
        input string test_name
    );
        checks++;

        if ((valid !== expected_valid) ||
            (done !== expected_done)) begin
            $fatal(1, "%s: expected valid=%b done=%b; got valid=%b done=%b", test_name, expected_valid, expected_done, valid, done);
        end

        $display("PASS: %s", test_name);
    endtask

    task automatic check_address(
        input int expected_image,
        input int expected_weight,
        input string test_name
    );
        checks++;

        if ((image_addr !== ADDR_WIDTH'(expected_image)) || (weight_addr !== 4'(expected_weight))) begin
            $fatal(1, "%s: expected image=%0d weight=%0d; got image=%0d weight=%0d", test_name, expected_image, expected_weight, image_addr, weight_addr);
        end

        $display("PASS: %s | image=%0d weight=%0d", test_name, image_addr, weight_addr);
    endtask

    task automatic run_window(input int window_base);

        // Start while ready is low: no address is consumed.
        @(negedge clk);
        start = 1'b1;
        ready = 1'b0;
        base_addr = ADDR_WIDTH'(window_base);

        @(posedge clk);
        #1;
        check_status(1, 0, "Window started");

        // Change base_addr after start to verify it was captured.
        @(negedge clk);
        start = 1'b0;
        base_addr = 8'd100;

        for (int i = 0; i < 9; i++) begin

            // Inspect the address before accepting it.
            check_status(1, 0, $sformatf("Term %0d is available", i));

            check_address(window_base + (i / 3) * IMAGE_WIDTH + (i % 3), i, $sformatf("Term %0d address", i));

            // Pause for two cycles before accepting term 3.
            if (i == 3) begin
                repeat (2) begin
                    @(negedge clk);
                    ready = 1'b0;

                    @(posedge clk);
                    #1;
                    check_status(1, 0, "Valid holds during pause");

                    check_address(window_base + IMAGE_WIDTH, 3, "Addresses hold during pause");
                end
            end

            // Accept exactly one address.
            @(negedge clk);
            ready = 1'b1;

            @(posedge clk);
            #1;

            // Prevent another acceptance before the next iteration.
            @(negedge clk);
            ready = 1'b0;
        end

        check_status(0, 1, "Ninth acceptance completes window");

        @(posedge clk);
        #1;
        check_status(0, 0, "Done pulse ends");
    endtask

    initial begin
        checks = 0;
        n_rst = 1'b1;
        start = 1'b0;
        ready = 1'b0;
        base_addr = '0;

        #1;
        n_rst = 1'b0;
        #1;
        check_status(0, 0, "Initial asynchronous reset");
        check_address(0, 0, "Reset addresses");

        @(negedge clk);
        n_rst = 1'b1;

        // Top-left and top-right windows of a 4x4 image.
        run_window(0);
        run_window(1);

        $display("All %0d checks passed.", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Testbench timed out");
    end

endmodule