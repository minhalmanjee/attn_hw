// C = A * B, Q4.4 fixed-point (real = int/16)
// Q4.4*Q4.4 -> Q8.8, so >> 4 to get back to Q4.4
module matmul #(
    parameter ROWS   = 2,
    parameter COLS   = 4,
    parameter COLS_B = 4,
    parameter WIDTH  = 8
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start,
    input  signed [WIDTH-1:0]       A [0:ROWS-1][0:COLS-1],
    input  signed [WIDTH-1:0]       B [0:COLS-1][0:COLS_B-1],
    output reg signed [WIDTH-1:0]   C [0:ROWS-1][0:COLS_B-1],
    output reg                      done
);

    integer i, j, k;
    reg signed [2*WIDTH-1:0] acc;

    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
        end
        else if (start && !done) begin
            for (i = 0; i < ROWS; i = i + 1) begin
                for (j = 0; j < COLS_B; j = j + 1) begin
                    acc = 0;
                    for (k = 0; k < COLS; k = k + 1)
                        acc = acc + A[i][k] * B[k][j];
                    C[i][j] <= acc >>> 4;
                end
            end
            done <= 1'b1;
        end
        else if (!start) begin
            done <= 1'b0;
        end
    end

endmodule
