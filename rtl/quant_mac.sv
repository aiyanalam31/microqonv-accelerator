module quant_mac (
    input logic clk,
    input logic n_rst,
    input logic clear,
    input logic enable,
    input logic signed [7:0] activation,
    input logic signed [7:0] weight,
    output logic signed [31:0] result
);
    logic signed [15:0] product;
    logic signed [31:0] product_extended;
    logic signed [31:0] accumulator;

    assign product = activation * weight;

    assign product_extended = {{16{product[15]}}, product};

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            accumulator <= '0;
        end
        else if (clear) begin
            accumulator <= '0;
        end
        else if (enable) begin
            accumulator <= accumulator + product_extended;
        end
    end

    assign result = accumulator;
endmodule