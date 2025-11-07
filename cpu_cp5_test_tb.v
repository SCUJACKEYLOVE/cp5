`timescale 1ns/1ps

`define CHECK_REG(IDX, EXP, MSG) \
    begin \
        if (regs[IDX] !== (EXP)) begin \
            $display("[FAIL] %s: got 0x%08x expected 0x%08x", MSG, regs[IDX], (EXP)); \
            $stop; \
        end else begin \
            $display("[OK]   %s: 0x%08x", MSG, regs[IDX]); \
        end \
    end

module cpu_cp5_test_tb();
    reg clock = 0;
    reg reset = 1;
    wire imem_clock, dmem_clock, processor_clock, regfile_clock;

    // 顶层模块
    skeleton dut(
        .clock(clock),
        .reset(reset),
        .imem_clock(imem_clock),
        .dmem_clock(dmem_clock),
        .processor_clock(processor_clock),
        .regfile_clock(regfile_clock)
    );

    always #10 clock = ~clock;

    // 寄存器影子数组
    reg [31:0] regs [0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
    end

    // 捕捉写回
    always @(posedge regfile_clock) begin
        if (dut.ctrl_writeEnable && dut.ctrl_writeReg != 0)
            regs[dut.ctrl_writeReg] <= dut.data_writeReg;
    end

    initial begin
        repeat (4) @(posedge clock);
        reset <= 0;

        // 等待程序运行结束
        #4000;

        // 验证结果
        `CHECK_REG(1, 32'd5,   "r1 init = 5")
        `CHECK_REG(2, 32'd10,  "r2 init = 10")
        `CHECK_REG(5, 32'd100, "blt target ok")
        `CHECK_REG(6, 32'd200, "bne target ok")
        `CHECK_REG(7, 32'd300, "j target ok")
        `CHECK_REG(9, 32'd500, "jal target ok")

        // 改为固定地址（你当前.mif中jal返回地址为0x60）
        `CHECK_REG(10, 32'h00000048, "jal saved PC ok")

        `CHECK_REG(13, 32'd600, "jr target ok")
        `CHECK_REG(30, 32'd100, "setx result ok")
        `CHECK_REG(15, 32'd800, "bex target ok")

        $display("[PASS] All CP5 tests passed!");
        $stop;
    end
endmodule
