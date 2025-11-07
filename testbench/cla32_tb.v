`timescale 1ns/1ps

module cla32_tb;
    reg  [31:0] num1, num2;
    reg         cin;
    wire [31:0] sum;
    wire        cout;

    cla32 cla (
        .num1(num1), .num2(num2), .cin (cin),
        .sum (sum), .cout(cout)
    );

    reg  [31:0] ref_sum;
    reg         ref_cout;

    task automatic apply_and_check(input [31:0] a, input [31:0] b, input c);
        reg [32:0] ref;
        begin
            num1 = a; num2 = b; cin = c;
            #1;

            ref = a + b + c;
            ref_sum  = ref[31:0];
            ref_cout = ref[32];

            if (sum !== ref_sum || cout !== ref_cout) begin
                $display("[FAIL] a=%h b=%h cin=%0d | DUT sum=%h cout=%0d | REF sum=%h cout=%0d",
                        a, b, c, sum, cout, ref_sum, ref_cout);
                $fatal(1);
            end
        end
    endtask

    integer i;

    initial begin
        apply_and_check(32'h0000_0000, 32'h0000_0000, 1'b0);
        apply_and_check(32'h0000_0000, 32'h0000_0000, 1'b1);
        apply_and_check(32'hFFFF_FFFF, 32'h0000_0001, 1'b0);
        apply_and_check(32'hFFFF_FFFF, 32'h0000_0000, 1'b1);
        apply_and_check(32'hAAAA_AAAA, 32'h5555_5555, 1'b0);
        apply_and_check(32'h8000_0000, 32'h8000_0000, 1'b0);
        apply_and_check(32'h7FFF_FFFF, 32'h0000_0001, 1'b1);
        apply_and_check(32'h1234_5678, 32'h1111_1111, 1'b0);
        apply_and_check(32'hDEAD_BEEF, 32'h0123_4567, 1'b1);

        for (i = 0; i < 1000; i = i + 1) begin
            apply_and_check($random, $random, $random % 2);
        end

        $display("[PASS] All tests passed.");
        $finish;
    end
endmodule
