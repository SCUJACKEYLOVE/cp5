module cmp_const #(
    parameter width = 32,
    parameter const_val = {width{1'b0}}
) (
    input  [width-1:0] data,
    output             is_equal
);
    wire [width-1:0] const_wire = const_val[width-1:0];
    assign is_equal = ~| (data ^ const_wire);
endmodule
