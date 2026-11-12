// Attention(Q,K,V) = softmax( (Q K^T) / sqrt(d_k) ) V
// Q = X WQ,  K = X WK,  V = X WV
// N=2, D=4, Q4.4 (8-bit)
module attn_top #(
    parameter N     = 2,
    parameter D     = 4,
    parameter WIDTH = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done,

    input  signed [WIDTH-1:0] X  [0:N-1][0:D-1],
    input  signed [WIDTH-1:0] WQ [0:D-1][0:D-1],
    input  signed [WIDTH-1:0] WK [0:D-1][0:D-1],
    input  signed [WIDTH-1:0] WV [0:D-1][0:D-1],

    output reg signed [WIDTH-1:0] out [0:N-1][0:D-1]
);

    reg signed [WIDTH-1:0] Q      [0:N-1][0:D-1];
    reg signed [WIDTH-1:0] K      [0:N-1][0:D-1];
    reg signed [WIDTH-1:0] V      [0:N-1][0:D-1];
    reg signed [WIDTH-1:0] scores [0:N-1][0:N-1];
    reg signed [WIDTH-1:0] attn_w [0:N-1][0:N-1];

    reg  signed [WIDTH-1:0] mm_A [0:N-1][0:D-1];
    reg  signed [WIDTH-1:0] mm_B [0:D-1][0:D-1];
    wire signed [WIDTH-1:0] mm_C [0:N-1][0:D-1];
    reg  mm_start;
    wire mm_done;

    matmul #(.ROWS(N), .COLS(D), .COLS_B(D), .WIDTH(WIDTH)) u_mm (
        .clk(clk), .rst(rst), .start(mm_start),
        .A(mm_A), .B(mm_B), .C(mm_C), .done(mm_done)
    );

    reg  signed [WIDTH-1:0] sf_in  [0:N-1];
    wire signed [WIDTH-1:0] sf_out [0:N-1];
    reg  sf_start;
    wire sf_done;
    reg  [$clog2(N):0] sf_row;

    softmax #(.N(N), .WIDTH(WIDTH)) u_sf (
        .clk(clk), .rst(rst), .start(sf_start),
        .scores(sf_in), .weights(sf_out), .done(sf_done)
    );

    localparam S_IDLE   = 4'd0;
    localparam S_LOAD_Q = 4'd1;
    localparam S_WAIT_Q = 4'd2;
    localparam S_LOAD_K = 4'd3;
    localparam S_WAIT_K = 4'd4;
    localparam S_LOAD_V = 4'd5;
    localparam S_WAIT_V = 4'd6;
    localparam S_SCORE  = 4'd7;
    localparam S_SCALE  = 4'd8;
    localparam S_SF_LD  = 4'd9;
    localparam S_SF_WT  = 4'd10;
    localparam S_OUT    = 4'd11;
    localparam S_DONE   = 4'd12;

    reg [3:0] state;
    integer i, j, k;
    reg signed [2*WIDTH-1:0] acc;

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;
            done     <= 1'b0;
            mm_start <= 1'b0;
            sf_start <= 1'b0;
            sf_row   <= 0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start)
                        state <= S_LOAD_Q;
                end

                // Q = X * WQ
                S_LOAD_Q: begin
                    for (i = 0; i < N; i = i + 1)
                        for (j = 0; j < D; j = j + 1)
                            mm_A[i][j] <= X[i][j];
                    for (i = 0; i < D; i = i + 1)
                        for (j = 0; j < D; j = j + 1)
                            mm_B[i][j] <= WQ[i][j];
                    mm_start <= 1'b1;
                    state    <= S_WAIT_Q;
                end
                S_WAIT_Q: begin
                    if (mm_done) begin
                        mm_start <= 1'b0;
                        for (i = 0; i < N; i = i + 1)
                            for (j = 0; j < D; j = j + 1)
                                Q[i][j] <= mm_C[i][j];
                        state <= S_LOAD_K;
                    end
                end

                // K = X * WK
                S_LOAD_K: begin
                    for (i = 0; i < D; i = i + 1)
                        for (j = 0; j < D; j = j + 1)
                            mm_B[i][j] <= WK[i][j];
                    mm_start <= 1'b1;
                    state    <= S_WAIT_K;
                end
                S_WAIT_K: begin
                    if (mm_done) begin
                        mm_start <= 1'b0;
                        for (i = 0; i < N; i = i + 1)
                            for (j = 0; j < D; j = j + 1)
                                K[i][j] <= mm_C[i][j];
                        state <= S_LOAD_V;
                    end
                end

                // V = X * WV
                S_LOAD_V: begin
                    for (i = 0; i < D; i = i + 1)
                        for (j = 0; j < D; j = j + 1)
                            mm_B[i][j] <= WV[i][j];
                    mm_start <= 1'b1;
                    state    <= S_WAIT_V;
                end
                S_WAIT_V: begin
                    if (mm_done) begin
                        mm_start <= 1'b0;
                        for (i = 0; i < N; i = i + 1)
                            for (j = 0; j < D; j = j + 1)
                                V[i][j] <= mm_C[i][j];
                        state <= S_SCORE;
                    end
                end

                // scores = Q K^T
                S_SCORE: begin
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            acc = 0;
                            for (k = 0; k < D; k = k + 1)
                                acc = acc + Q[i][k] * K[j][k];
                            scores[i][j] <= acc >>> 4;
                        end
                    end
                    state <= S_SCALE;
                end

                // / sqrt(D), D=4 so >> 1
                S_SCALE: begin
                    for (i = 0; i < N; i = i + 1)
                        for (j = 0; j < N; j = j + 1)
                            scores[i][j] <= scores[i][j] >>> 1;
                    sf_row <= 0;
                    state  <= S_SF_LD;
                end

                // softmax row by row
                S_SF_LD: begin
                    for (j = 0; j < N; j = j + 1)
                        sf_in[j] <= scores[sf_row][j];
                    sf_start <= 1'b1;
                    state    <= S_SF_WT;
                end
                S_SF_WT: begin
                    if (sf_done) begin
                        sf_start <= 1'b0;
                        for (j = 0; j < N; j = j + 1)
                            attn_w[sf_row][j] <= sf_out[j];
                        if (sf_row == N-1)
                            state <= S_OUT;
                        else begin
                            sf_row <= sf_row + 1;
                            state  <= S_SF_LD;
                        end
                    end
                end

                // out = attn_w * V
                S_OUT: begin
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < D; j = j + 1) begin
                            acc = 0;
                            for (k = 0; k < N; k = k + 1)
                                acc = acc + attn_w[i][k] * V[k][j];
                            out[i][j] <= acc >>> 4;
                        end
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
