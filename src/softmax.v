// softmax(x)_i = exp(x_i) / sum_j exp(x_j)
// approx: subtract max, LUT for exp, then normalize
module softmax #(
    parameter N     = 2,
    parameter WIDTH = 8
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start,
    input  signed [WIDTH-1:0]       scores [0:N-1],
    output reg signed [WIDTH-1:0]   weights [0:N-1],
    output reg                      done
);

    integer i;
    reg signed [WIDTH-1:0] max_val;
    reg signed [WIDTH-1:0] shifted;
    reg [WIDTH-1:0] e_val [0:N-1];
    reg [2*WIDTH-1:0] sum_e;

    // Q4.4 LUT for e^x
    function [WIDTH-1:0] exp_lut;
        input signed [WIDTH-1:0] x;
        begin
            case (x)
                8'sd16:  exp_lut = 8'd43;  // e^1
                8'sd8:   exp_lut = 8'd26;  // e^0.5
                8'sd0:   exp_lut = 8'd16;  // e^0
                -8'sd8:  exp_lut = 8'd10;  // e^-0.5
                -8'sd16: exp_lut = 8'd6;   // e^-1
                -8'sd32: exp_lut = 8'd3;   // e^-2
                default: exp_lut = 8'd16;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
        end
        else if (start && !done) begin
            // max for numerical stability
            max_val = scores[0];
            for (i = 1; i < N; i = i + 1)
                if (scores[i] > max_val)
                    max_val = scores[i];

            sum_e = 0;
            for (i = 0; i < N; i = i + 1) begin
                shifted  = scores[i] - max_val;
                e_val[i] = exp_lut(shifted);
                sum_e    = sum_e + e_val[i];
            end

            // (exp/sum)*16 in Q4.4
            for (i = 0; i < N; i = i + 1)
                weights[i] <= (e_val[i] << 4) / sum_e;

            done <= 1'b1;
        end
        else if (!start) begin
            done <= 1'b0;
        end
    end

endmodule
