module clk_div2N #(parameter N = 1) (
    input  clk, reset,
    output clk_out
);
    localparam WIDTH = (N <= 1) ? 1 : $clog2(N);

    reg [WIDTH-1:0] cnt;
    reg             clk_q;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt <= 0;
            clk_q <= 0;
        end else if (cnt == N-1) begin
            cnt <= 0;
            clk_q <= ~clk_q;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    assign clk_out = clk_q;
endmodule
