`timescale 1ns/1ps
// loads X/WQ/WK/WV from data/*.txt, dumps VCD + output.txt
module attn_tb;

    localparam N     = 2;
    localparam D     = 4;
    localparam WIDTH = 8;

    reg  clk, rst, start;
    wire done;

    reg  signed [WIDTH-1:0] X  [0:N-1][0:D-1];
    reg  signed [WIDTH-1:0] WQ [0:D-1][0:D-1];
    reg  signed [WIDTH-1:0] WK [0:D-1][0:D-1];
    reg  signed [WIDTH-1:0] WV [0:D-1][0:D-1];
    wire signed [WIDTH-1:0] out [0:N-1][0:D-1];

    attn_top #(.N(N), .D(D), .WIDTH(WIDTH)) dut (
        .clk(clk), .rst(rst), .start(start), .done(done),
        .X(X), .WQ(WQ), .WK(WK), .WV(WV), .out(out)
    );

    always #5 clk = ~clk;

    integer f, i, j, code, tmp;

    initial begin
        $dumpfile("attn_tb.vcd");
        $dumpvars(0, attn_tb);

        clk   = 0;
        rst   = 1;
        start = 0;

        f = $fopen("../data/X.txt", "r");
        if (f == 0) begin $display("ERROR: cannot open X.txt"); $finish; end
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < D; j = j + 1) begin
                code = $fscanf(f, "%d", tmp);
                if (code != 1) begin
                    $display("ERROR reading X[%0d][%0d]", i, j);
                    $finish;
                end
                X[i][j] = tmp;
            end
        $fclose(f);

        f = $fopen("../data/WQ.txt", "r");
        if (f == 0) begin $display("ERROR: cannot open WQ.txt"); $finish; end
        for (i = 0; i < D; i = i + 1)
            for (j = 0; j < D; j = j + 1) begin
                code = $fscanf(f, "%d", tmp);
                WQ[i][j] = tmp;
            end
        $fclose(f);

        f = $fopen("../data/WK.txt", "r");
        if (f == 0) begin $display("ERROR: cannot open WK.txt"); $finish; end
        for (i = 0; i < D; i = i + 1)
            for (j = 0; j < D; j = j + 1) begin
                code = $fscanf(f, "%d", tmp);
                WK[i][j] = tmp;
            end
        $fclose(f);

        f = $fopen("../data/WV.txt", "r");
        if (f == 0) begin $display("ERROR: cannot open WV.txt"); $finish; end
        for (i = 0; i < D; i = i + 1)
            for (j = 0; j < D; j = j + 1) begin
                code = $fscanf(f, "%d", tmp);
                WV[i][j] = tmp;
            end
        $fclose(f);

        $display("Loaded inputs from ../data/*.txt");

        #20 rst = 0;
        #10 start = 1;
        #10 start = 0;

        wait (done);
        #20;

        $display("==== Q ====");
        for (i = 0; i < N; i = i + 1)
            $display("  %d %d %d %d", dut.Q[i][0], dut.Q[i][1], dut.Q[i][2], dut.Q[i][3]);
        $display("==== K ====");
        for (i = 0; i < N; i = i + 1)
            $display("  %d %d %d %d", dut.K[i][0], dut.K[i][1], dut.K[i][2], dut.K[i][3]);
        $display("==== V ====");
        for (i = 0; i < N; i = i + 1)
            $display("  %d %d %d %d", dut.V[i][0], dut.V[i][1], dut.V[i][2], dut.V[i][3]);
        $display("==== scores (after scale) ====");
        for (i = 0; i < N; i = i + 1)
            $display("  %d %d", dut.scores[i][0], dut.scores[i][1]);
        $display("==== attn weights ====");
        for (i = 0; i < N; i = i + 1)
            $display("  %d %d", dut.attn_w[i][0], dut.attn_w[i][1]);
        $display("==== output ====");
        for (i = 0; i < N; i = i + 1)
            $display("  %d %d %d %d", out[i][0], out[i][1], out[i][2], out[i][3]);

        f = $fopen("../data/output.txt", "w");
        if (f == 0) begin $display("ERROR: cannot write output.txt"); $finish; end
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < D; j = j + 1)
                $fwrite(f, "%d%s", out[i][j], (j == D-1) ? "" : " ");
            $fwrite(f, "\n");
        end
        $fclose(f);
        $display("Wrote ../data/output.txt");

        $finish;
    end

endmodule
