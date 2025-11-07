module alu(
    input  [31:0] data_operandA, data_operandB,
    input  [4:0]  ctrl_ALUopcode, ctrl_shiftamt,
    output [31:0] data_result,
    output        isNotEqual, isLessThan, overflow
);
    // Generate variable
    genvar i, j;

    // ==================== Preprocessing ====================
    // Identify the operation
    wire op_n0, op_n1, op_n2, op_n3, op_n4;
    wire op_add, op_sub, op_and, op_or, op_sll, op_sra;

    not (op_n0, ctrl_ALUopcode[0]);
    not (op_n1, ctrl_ALUopcode[1]);
    not (op_n2, ctrl_ALUopcode[2]);
    not (op_n3, ctrl_ALUopcode[3]);
    not (op_n4, ctrl_ALUopcode[4]);
    
    and (op_add, op_n4, op_n3, op_n2, op_n1, op_n0);
    and (op_sub, op_n4, op_n3, op_n2, op_n1, ctrl_ALUopcode[0]);
    and (op_and, op_n4, op_n3, op_n2, ctrl_ALUopcode[1], op_n0);
    and (op_or,  op_n4, op_n3, op_n2, ctrl_ALUopcode[1], ctrl_ALUopcode[0]);
    and (op_sll, op_n4, op_n3, ctrl_ALUopcode[2], op_n1, op_n0);
    and (op_sra, op_n4, op_n3, ctrl_ALUopcode[2], op_n1, ctrl_ALUopcode[0]);

    // Bitwise NOT B for isLessThan and possible subtraction
    wire [31:0] not_B;
    generate
        for (i = 0; i < 32; i = i + 1) begin: gen_not_B
            not (not_B[i], data_operandB[i]);
        end
    endgenerate

    // ==================== Add/Sub ====================
    wire [31:0] sel_B;
    generate
        for (i = 0; i < 32; i = i + 1) begin: gen_bsel
            assign sel_B[i] = op_add ? data_operandB[i] : not_B[i];
        end
    endgenerate

    // For subtraction, we add the negation of B, which is ~B + 1
    // Use op_sub as cin to add the 1
    wire [31:0] add_sub_out;
    cla32 cla_addsub (
        .num1(data_operandA), .num2(sel_B), .cin(op_sub),
        .sum(add_sub_out), .cout()
    );

    // ==================== Overflow Detection ====================
    // overflow_add = ~(A31 ^ B31) & (sum31 ^ A31)
    // overflow_sub = (A31 ^ B31) & (sum31 ^ A31)
    wire xor_a31b31, not_xor_a31b31, xor_sum_a31;
    wire overflow_add, overflow_sub;

    not (not_xor_a31b31, xor_a31b31);
    xor (xor_sum_a31, add_sub_out[31], data_operandA[31]);

    and (overflow_add, not_xor_a31b31, xor_sum_a31);
    and (overflow_sub, xor_a31b31, xor_sum_a31);

    // Only care about overflow when doing add or sub
    wire overflow_add_out, overflow_sub_out;
    and (overflow_add_out, overflow_add, op_add);
    and (overflow_sub_out, overflow_sub, op_sub);
    or  (overflow, overflow_add_out, overflow_sub_out);

    // ==================== AND/OR ====================
    wire [31:0] and_out, or_out;
    generate
        for (i = 0; i < 32; i = i + 1) begin: gen_andor
            and (and_out[i], data_operandA[i], data_operandB[i]);
            or  (or_out[i],  data_operandA[i], data_operandB[i]);
        end
    endgenerate

    // ==================== SLL ====================
    wire [31:0] sll_out;
    wire [31:0] sll_stages [5:0];
    assign sll_stages[0] = data_operandA;

    generate 
        for (i = 0; i < 5; i = i + 1) begin: gen_sll
            localparam k = (1 << i);
            for (j = 0; j < 32; j = j + 1) begin: gen_sll_mux
                if (j >= k) begin
                    assign sll_stages[i+1][j] = 
                        ctrl_shiftamt[i] ? sll_stages[i][j-k] : sll_stages[i][j];
                end else begin
                    assign sll_stages[i+1][j] = 
                        ctrl_shiftamt[i] ? 1'b0 : sll_stages[i][j];
                end 
            end
        end
    endgenerate
    assign sll_out = sll_stages[5];

    // ==================== SRA ====================
    wire [31:0] sra_out;
    wire [31:0] sra_stages [5:0];
    assign sra_stages[0] = data_operandA;
    assign sra_sign = data_operandA[31];

    generate
        for (i = 0; i < 5; i = i + 1) begin: gen_sra
            localparam k = (1 << i);
            for (j = 0; j < 32; j = j + 1) begin: gen_sra_mux
                if (j + k < 32) begin
                    assign sra_stages[i+1][j] = 
                        ctrl_shiftamt[i] ? sra_stages[i][j+k] : sra_stages[i][j];
                end else begin
                    assign sra_stages[i+1][j] = 
                        ctrl_shiftamt[i] ? sra_sign : sra_stages[i][j];
                end
            end
        end 
    endgenerate
    assign sra_out = sra_stages[5];

    // ==================== Final MUX ====================
    wire [31:0] add_out_choose, sub_out_choose;
    wire [31:0] and_out_choose, or_out_choose;
    wire [31:0] sll_out_choose, sra_out_choose;

    generate
        for (i = 0; i < 32; i = i + 1) begin: gen_final_mux
            and (add_out_choose[i], add_sub_out[i], op_add);
            and (sub_out_choose[i], add_sub_out[i], op_sub);
            and (and_out_choose[i], and_out[i],op_and);
            and (or_out_choose[i],  or_out[i], op_or);
            and (sll_out_choose[i], sll_out[i],op_sll);
            and (sra_out_choose[i], sra_out[i],op_sra);
            or  (data_result[i], add_out_choose[i], sub_out_choose[i], 
                                 and_out_choose[i], or_out_choose[i],
                                 sll_out_choose[i], sra_out_choose[i]);
        end 
    endgenerate

    // ==================== isNotEqual/isLessThan ====================
    wire [31:0] diff;
    wire xor_diff_a31, overflow_diff;

    cla32 cla_diff (
        .num1(data_operandA), .num2(not_B), .cin(1'b1),
        .sum(diff), .cout()
    );

    // overflow_diff = (A31 ^ B31) & (diff31 ^ A31)
    xor (xor_a31b31, data_operandA[31], data_operandB[31]);
    xor (xor_diff_a31, diff[31], data_operandA[31]);
    and (overflow_diff, xor_a31b31, xor_diff_a31);

    // isNotEqual = |diff
    // isLessThan = diff31 ^ overflow_diff
    reduce_or32 or32(.in(diff), .out(isNotEqual));
    xor (isLessThan, diff[31], overflow_diff);
endmodule

module reduce_or32(
    input  [31:0] in,
    output        out
);
    wire [15:0] s1;
    wire [7:0]  s2;
    wire [3:0]  s3;
    wire [1:0]  s4;
    genvar i;

    generate
        for (i = 0; i < 16; i = i + 1) begin: L1
            or (s1[i], in[i], in[i+16]);
        end
        for (i = 0; i < 8; i = i + 1) begin: L2
            or (s2[i], s1[i], s1[i+8]);
        end
        for (i = 0; i < 4; i = i + 1) begin: L3
            or (s3[i], s2[i], s2[i+4]);
        end
    endgenerate

    or (s4[0], s3[0], s3[1]);
    or (s4[1], s3[2], s3[3]);
    or (out,   s4[0], s4[1]);
endmodule

