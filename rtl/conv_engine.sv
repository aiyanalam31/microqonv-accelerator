module conv_engine #(
    parameter int NUM_TERMS = 9
) (
    input logic clk,
    input logic n_rst,
    input logic start,
    input logic input_valid,
    input logic signed [7:0] activation,
    input logic signed [7:0] weight,
    output logic busy,
    output logic done,
    output logic signed [31:0] result
);

    localparam int COUNT_WIDTH = (NUM_TERMS > 1) ? $clog2(NUM_TERMS) : 1;
    localparam logic [COUNT_WIDTH-1:0] LAST_TERM = COUNT_WIDTH'($unsigned(NUM_TERMS - 1));
    logic [COUNT_WIDTH-1:0] term_count;

    logic mac_clear;
    logic mac_enable;
    logic signed [31:0] mac_result;

    // Accept a new computation only when idle.
    assign mac_clear = start && !busy;

    // Accumulate only when a valid pair is available.
    assign mac_enable = busy && input_valid;

    quant_mac MAC (.clk(clk), .n_rst(n_rst), .clear(mac_clear), .enable(mac_enable), .activation (activation), .weight(weight), .result(mac_result));

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            term_count <= '0;
            busy <= 1'b0;
            done <= 1'b0;
        end
        else begin
            // Done is a one-clock-cycle pulse.
            done <= 1'b0;

            if (!busy) begin
                if (start) begin
                    term_count <= '0;
                    busy <= 1'b1;
                end
            end
            else if (input_valid) begin
                if (term_count == LAST_TERM) begin
                    term_count <= '0;
                    busy <= 1'b0;
                    done <= 1'b1;
                end
                else begin
                    term_count <= term_count + 1'b1;
                end
            end
        end
    end

    assign result = mac_result;

endmodule