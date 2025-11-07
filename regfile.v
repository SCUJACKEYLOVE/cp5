module regfile (
    input  clock, ctrl_writeEnable, ctrl_reset,
    input  [4:0]  ctrl_writeReg, ctrl_readRegA, ctrl_readRegB,
    input  [31:0] data_writeReg,
    output [31:0] data_readRegA, data_readRegB
);
    genvar reg_idx;

    generate
        for (reg_idx = 0; reg_idx < 32; reg_idx = reg_idx + 1) begin: gen_reg
            wire sel_write, sel_readA, sel_readB;
            cmp_const #(5, reg_idx) cmpA (ctrl_readRegA, sel_readA);
            cmp_const #(5, reg_idx) cmpB (ctrl_readRegB, sel_readB);
            cmp_const #(5, reg_idx) cmpW (ctrl_writeReg, sel_write);

            wire [31:0] out;
            if (reg_idx == 0) begin: gen_reg0
                // R0 does not accept writes and always outputs 0
                assign out = 32'b0;
            end else begin: gen_regN
                wire write_enable = ctrl_writeEnable & sel_write;
                dffe_ref regN (
                    .data(data_writeReg), .clk(clock), .enable(write_enable),
                    .clear(ctrl_reset), .out(out)
                );
            end

            assign data_readRegA = sel_readA ? out : 32'bz;
            assign data_readRegB = sel_readB ? out : 32'bz;
        end
    endgenerate
endmodule
