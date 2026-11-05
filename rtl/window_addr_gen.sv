module window_addr_gen #(
    parameter int unsigned IMAGE_WIDTH = 4,
    parameter int unsigned ADDR_WIDTH  = 8
) (
    input logic clk,
    input logic n_rst,
    input logic start,
    input logic [ADDR_WIDTH-1:0] base_addr,
    input  logic ready,
    output logic valid,
    output logic done,
    output logic [ADDR_WIDTH-1:0] image_addr,
    output logic [3:0] weight_addr
);

    logic active;
    logic [ADDR_WIDTH-1:0] row_base;
    logic [1:0] kernel_row;
    logic [1:0] kernel_col;
    logic [3:0] term_index;

    localparam logic [ADDR_WIDTH-1:0] ROW_STRIDE = ADDR_WIDTH'(IMAGE_WIDTH);

    // Current activation and weight addresses.
    assign image_addr = row_base + {{(ADDR_WIDTH-2){1'b0}}, kernel_col};

    assign weight_addr = term_index;
    assign valid = active;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            active <= 1'b0;
            done <= 1'b0;
            row_base <= '0;
            kernel_row <= '0;
            kernel_col <= '0;
            term_index <= '0;
        end
        else begin
            done <= 1'b0;

            if (!active) begin
                if (start) begin
                    active <= 1'b1;
                    row_base <= base_addr;
                    kernel_row <= '0;
                    kernel_col <= '0;
                    term_index <= '0;
                end
            end
            else if (ready) begin
                if (term_index == 4'd8) begin
                    active <= 1'b0;
                    done <= 1'b1;
                end
                else begin
                    term_index <= term_index + 4'd1;

                    if (kernel_col == 2'd2) begin
                        kernel_col <= '0;
                        kernel_row <= kernel_row + 2'd1;
                        row_base <= row_base + ROW_STRIDE;
                    end
                    else begin
                        kernel_col <= kernel_col + 2'd1;
                    end
                end
            end
        end
    end

endmodule