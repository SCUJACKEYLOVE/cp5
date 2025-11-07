`timescale 1ns/1ps

`define CHECK_REG(IDX, EXP, MSG)                                                         \
    begin                                                                                \
        if (regs[IDX] !== (EXP)) begin                                                   \
            $display("[FAIL] %s: got 0x%08x expected 0x%08x", MSG, regs[IDX], (EXP));    \
            $stop;                                                                       \
        end else begin                                                                   \
            $display("[OK]   %s: 0x%08x", MSG, regs[IDX]);                               \
        end                                                                              \
    end

module cpu_basic_test();
    reg clock = 0;
    reg reset = 1;
    wire imem_clock, dmem_clock, processor_clock, regfile_clock;

    skeleton dut(
        .clock(clock),
        .reset(reset),
        .imem_clock(imem_clock),
        .dmem_clock(dmem_clock),
        .processor_clock(processor_clock),
        .regfile_clock(regfile_clock)
    );

    always #10 clock = ~clock;

    // Register shadow
    reg [31:0] regs [0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
    end

    // Update shadow on regfile writeback
    always @(posedge regfile_clock) begin
        if (dut.ctrl_writeEnable) begin
            // Skip r0 writes
            if (dut.ctrl_writeReg != 5'd0) begin
                regs[dut.ctrl_writeReg] <= dut.data_writeReg;
            end
        end
    end

    // Dmem read/write monitor
    always @(posedge dmem_clock) begin
        if (dut.wren) begin
            $display("%t [DMEM-W] addr=%0d data=0x%08x", $time, dut.address_dmem, dut.data);
        end else begin
            $display("%t [DMEM-R] addr=%0d data=0x%08x", $time, dut.address_dmem, dut.q_dmem);
        end
    end


    initial begin
        // Hold reset for 4 main clock cycles
        repeat (4) @(posedge clock);
        reset <= 1'b0;

        // Wait for PC to reach last instruction address and register writeback
        wait (dut.address_imem == 12'd16);
        @(posedge regfile_clock);

        // —— 断言 —— 对应给定 mif 的每条指令语义
        `CHECK_REG( 1, 32'd5,    "r1 = 5 (addi)")
        `CHECK_REG( 2, 32'd3,    "r2 = 3 (addi)")
        `CHECK_REG( 3, 32'd8,    "r3 = r1 + r2 (add)")
        `CHECK_REG( 4, 32'd2,    "r4 = r1 - r2 (sub)")
        `CHECK_REG( 5, 32'd0,    "r5 = r0 & r1 (and)")
        `CHECK_REG( 6, 32'd1,    "r6 = r1 & r2 (and)")
        `CHECK_REG( 7, 32'd3,    "r7 = r0 | r2 (or)")
        `CHECK_REG( 8, 32'd20,   "r8 = r1 << 2 (sll)")
        `CHECK_REG( 9, 32'd4,    "r9 = r3 >>> 1 (sra)")
        `CHECK_REG(10, 32'd345,  "r10 = 345 (addi)")
        `CHECK_REG(11, 32'd567,  "r11 = 567 (addi)")
        `CHECK_REG(12, 32'd345,  "r12 = mem[1] (lw after sw)")
        `CHECK_REG(13, 32'd567,  "r13 = mem[2] (lw after sw)")

        // 可选：保障 r0 恒为 0（如设计要求）
        `CHECK_REG( 0, 32'd0,    "r0 hard-wired zero")

        $display("[PASS] All tests passed.");
        $stop;
    end
endmodule
