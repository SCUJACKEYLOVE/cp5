module dffe_ref(
    input  wire [31:0] data,
    input  wire clk, enable, clear,
    output reg  [31:0] out
);
    always @(posedge clk, posedge clear) begin
        if (clear) begin
            out <= 32'b0;
        end else if (enable) begin
            out <= data;
        end
    end
endmodule
