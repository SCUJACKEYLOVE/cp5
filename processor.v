/**
 * READ THIS DESCRIPTION!
 *
 * The processor takes in several inputs from a skeleton file.
 *
 * Inputs
 * clock: this is the clock for your processor at 50 MHz
 * reset: we should be able to assert a reset to start your pc from 0 (sync or
 * async is fine)
 *
 * Imem: input data from imem
 * Dmem: input data from dmem
 * Regfile: input data from regfile
 *
 * Outputs
 * Imem: output control signals to interface with imem
 * Dmem: output control signals and data to interface with dmem
 * Regfile: output control signals and data to interface with regfile
 *
 * Notes
 *
 * Ultimately, your processor will be tested by subsituting a master skeleton, imem, dmem, so the
 * testbench can see which controls signal you active when. Therefore, there needs to be a way to
 * "inject" imem, dmem, and regfile interfaces from some external controller module. The skeleton
 * file acts as a small wrapper around your processor for this purpose.
 *
 * You will need to figure out how to instantiate two memory elements, called
 * "syncram," in Quartus: one for imem and one for dmem. Each should take in a
 * 12-bit address and allow for storing a 32-bit value at each address. Each
 * should have a single clock.
 *
 * Each memory element should have a corresponding .mif file that initializes
 * the memory element to certain value on start up. These should be named
 * imem.mif and dmem.mif respectively.
 *
 * Importantly, these .mif files should be placed at the top level, i.e. there
 * should be an imem.mif and a dmem.mif at the same level as process.v. You
 * should figure out how to point your generated imem.v and dmem.v files at
 * these MIF files.
 *
 * imem
 * Inputs:  12-bit address, 1-bit clock enable, and a clock
 * Outputs: 32-bit instruction
 *
 * dmem
 * Inputs:  12-bit address, 1-bit clock, 32-bit data, 1-bit write enable
 * Outputs: 32-bit data at the given address
 *
 */
module processor(
    // Control signals
    clock,                          // I: The master clock
    reset,                          // I: A reset signal

    // Imem
    address_imem,                   // O: The address of the data to get from imem
    q_imem,                         // I: The data from imem

    // Dmem
    address_dmem,                   // O: The address of the data to get or put from/to dmem
    data,                           // O: The data to write to dmem
    wren,                           // O: Write enable for dmem
    q_dmem,                         // I: The data from dmem

    // Regfile
    ctrl_writeEnable,               // O: Write enable for regfile
    ctrl_writeReg,                  // O: Register to write to in regfile
    ctrl_readRegA,                  // O: Register to read from port A of regfile
    ctrl_readRegB,                  // O: Register to read from port B of regfile
    data_writeReg,                  // O: Data to write to for regfile
    data_readRegA,                  // I: Data from port A of regfile
    data_readRegB                   // I: Data from port B of regfile
);

    // ==================== Port Declarations ====================

    // Control signals
    input clock, reset;

    // Imem
    output [11:0] address_imem;
    input  [31:0] q_imem;

    // Dmem
    output [11:0] address_dmem;
    output [31:0] data;
    output        wren;
    input  [31:0] q_dmem;

    // Regfile
    output        ctrl_writeEnable;
    output [4:0]  ctrl_writeReg;
    output [4:0]  ctrl_readRegA;
    output [4:0]  ctrl_readRegB;
    output [31:0] data_writeReg;
    input  [31:0] data_readRegA;
    input  [31:0] data_readRegB;

    // ==================== PC ====================
    wire [31:0] pc;
    wire [31:0] pc_next;

    
    cla32 pc_incrementer(
        .num1(pc), .num2(32'd4), .cin(1'd0),
        .sum(pc_next), .cout()
    );

    // the PC that actually write to reg
    wire [31:0] next_pc_final;

    dffe_ref pc_reg(
        .data(next_pc_final),
        .clk(clock), .enable(1'b1), .clear(reset),
        .out(pc)
    );

    // ==================== Decode from Imem ====================
    assign address_imem = pc[13:2];

    wire [4:0] op_code = q_imem[31:27];
    wire [4:0] rd = q_imem[26:22];
    wire [4:0] rs = q_imem[21:17];
    wire [4:0] rt = q_imem[16:12];
    wire [4:0] shamt = q_imem[11:7];
    wire [4:0] func = q_imem[6:2];
    wire [16:0] immediate = q_imem[16:0];
    wire [26:0] target_T  = q_imem[26:0];
    wire [31:0] immediate_sext = {{15{immediate[16]}}, immediate};

    // ---- opcode compare ----
    wire op_rtype, op_addi, op_sw, op_lw;
    cmp_const #(5, 5'b00000) cmp_rtype (op_code, op_rtype);
    cmp_const #(5, 5'b00101) cmp_addi  (op_code, op_addi);
    cmp_const #(5, 5'b00111) cmp_sw    (op_code, op_sw);
    cmp_const #(5, 5'b01000) cmp_lw    (op_code, op_lw);

    // ==== CP5 instr ====
    wire op_j, op_bne, op_jal, op_jr, op_blt, op_bex, op_setx;
    cmp_const #(5, 5'b00001) cmp_j     (op_code, op_j);
    cmp_const #(5, 5'b00010) cmp_bne   (op_code, op_bne);
    cmp_const #(5, 5'b00011) cmp_jal   (op_code, op_jal);
    cmp_const #(5, 5'b00100) cmp_jr    (op_code, op_jr);
    cmp_const #(5, 5'b00110) cmp_blt   (op_code, op_blt);
    cmp_const #(5, 5'b10110) cmp_bex   (op_code, op_bex);
    cmp_const #(5, 5'b10101) cmp_setx  (op_code, op_setx);

    // ==================== ALU ====================
    wire alu_use_immediate = op_addi | op_lw | op_sw;
    wire [31:0] alu_operandA = data_readRegA;
    wire [31:0] alu_operandB = alu_use_immediate ? immediate_sext : data_readRegB;

    wire [4:0]  alu_opcode   = op_rtype ? func : 5'b0;
    wire [4:0]  alu_shiftamt = shamt;
    wire [31:0] alu_result;
    wire        alu_overflow;
    wire        alu_isNotEqual, alu_isLessThan;

    alu alu_inst (
        .data_operandA(alu_operandA),
        .data_operandB(alu_operandB),
        .ctrl_ALUopcode(alu_opcode),
        .ctrl_shiftamt(alu_shiftamt),
        .data_result(alu_result),
        .isNotEqual(alu_isNotEqual),
        .isLessThan(alu_isLessThan),
        .overflow(alu_overflow)
    );

    // ==================== Dmem ====================
    assign address_dmem = alu_result[11:0];
    assign data = data_readRegB;
    assign wren = op_sw;

    // ==================== Regfile & Overflow ====================
    wire func_add, func_sub;
    cmp_const #(5, 5'b00000) cmp_func_add (func, func_add);
    cmp_const #(5, 5'b00001) cmp_func_sub (func, func_sub);

    wire overflow_add   = op_rtype & func_add  & alu_overflow;
    wire overflow_sub   = op_rtype & func_sub  & alu_overflow;
    wire overflow_addi  = op_addi  & alu_overflow;
    wire overflow_any   = overflow_add | overflow_sub | overflow_addi;

    // ==================== PC / branch control ====================

    // modified offset
    wire [31:0] branch_offset = {{13{immediate[16]}}, immediate, 2'b00};
    wire [31:0] pc_branch;
    cla32 pc_branch_adder(
        .num1(pc_next), .num2(branch_offset), .cin(1'b0),
        .sum(pc_branch), .cout()
    );

    wire [31:0] pc_jump_target = {5'b0, target_T, 2'b00};
    wire [31:0] pc_jr_target   = data_readRegA;

    wire take_bne   = op_bne & alu_isNotEqual;
    wire take_blt   = op_blt & alu_isLessThan;
    wire take_branch= take_bne | take_blt;
    wire rstatus_is_nonzero = |data_readRegA;
    wire take_bex   = op_bex & rstatus_is_nonzero;
    wire take_abs_j = op_j | op_jal | take_bex;
    wire take_jr    = op_jr;

    // ==== default path for next_pc_final  ====
    assign next_pc_final = (take_abs_j) ? pc_jump_target :
                           (take_jr)    ? pc_jr_target   :
                           (take_branch)? pc_branch      :
                           pc_next; 

    wire [4:0] readA_sel_jr   = rd;
    wire [4:0] readA_sel_bex  = 5'd30;
    wire [4:0] readA_sel_br   = rd;
    wire [4:0] readA_sel_norm = rs;

    wire selA_jr  = op_jr;
    wire selA_bex = op_bex;
    wire selA_br  = op_bne | op_blt;

    wire [4:0] readA_after_jr  = selA_jr  ? readA_sel_jr  : readA_sel_norm;
    wire [4:0] readA_after_bex = selA_bex ? readA_sel_bex : readA_after_jr;
    wire [4:0] readA_after_br  = selA_br  ? readA_sel_br  : readA_after_bex;
    assign ctrl_readRegA = readA_after_br;

    wire [4:0] readB_sel_rtype = rt;
    wire [4:0] readB_sel_br    = rs;
    wire [4:0] readB_sel_oth   = rd;

    wire selB_rtype = op_rtype;
    wire selB_br    = op_bne | op_blt;

    wire [4:0] readB_after_rtype = selB_rtype ? readB_sel_rtype : readB_sel_oth;
    wire [4:0] readB_after_br    = selB_br    ? readB_sel_br    : readB_after_rtype;
    assign ctrl_readRegB = readB_after_br;

    // ==================== WB control ====================
    wire [31:0] normal_wdata = op_lw ? q_dmem : alu_result;

    wire [31:0] overflow_status =
        overflow_add  ? 32'd1 :
        overflow_addi ? 32'd2 :
        overflow_sub  ? 32'd3 : 32'd0;

    wire [31:0] setx_value = {5'b0, target_T};
    
    wire [31:0] jal_ra = pc_next;

    wire we_overflow = overflow_any;
    wire we_setx     = op_setx;
    wire we_jal      = op_jal;
    wire we_normal   = op_rtype | op_addi | op_lw;

    assign ctrl_writeEnable = we_overflow | we_setx | we_jal | we_normal;

    wire [4:0] wreg_overflow = 5'd30;
    wire [4:0] wreg_setx     = 5'd30;
    wire [4:0] wreg_jal      = 5'd31;
    wire [4:0] wreg_normal   = rd;

    wire [4:0] wreg_after_overflow = we_overflow ? wreg_overflow : wreg_normal;
    wire [4:0] wreg_after_setx     = we_setx     ? wreg_setx     : wreg_after_overflow;
    wire [4:0] wreg_after_jal      = we_jal      ? wreg_jal      : wreg_after_setx;
    assign ctrl_writeReg = wreg_after_jal;

    wire [31:0] wdata_after_overflow = we_overflow ? overflow_status : normal_wdata;
    wire [31:0] wdata_after_setx     = we_setx     ? setx_value      : wdata_after_overflow;
    wire [31:0] wdata_after_jal      = we_jal      ? jal_ra          : wdata_after_setx;
    assign data_writeReg = wdata_after_jal;
endmodule
