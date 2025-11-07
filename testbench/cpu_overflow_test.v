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

module cpu_overflow_test();
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
            $display("%t Write dmem[%0d] = 0x%08x", $time, dut.address_dmem, dut.data);
        end else begin
            $display("%t Read dmem[%0d] = 0x%08x", $time, dut.address_dmem, dut.q_dmem);
        end
    end


    initial begin
        // Hold reset for 4 main clock cycles
        repeat (4) @(posedge clock);
        reset <= 1'b0;

        // Wait for PC to reach last instruction address and register writeback
        wait (dut.address_imem == 12'd10);
        @(posedge regfile_clock);

        `CHECK_REG(1, 32'h7FFF_FFFF,  "r1 = 0x7FFFFFFF")
        `CHECK_REG(4, 32'd1,          "r4 = 1")
        `CHECK_REG(7, 32'h8000_0000,  "r7 = 0x80000000")

        `CHECK_REG(10, 32'd0,         "add overflow: r10 must remain 0")
        `CHECK_REG(11, 32'd0,         "addi overflow: r11 must remain 0")
        `CHECK_REG(12, 32'd0,         "sub overflow: r12 must remain 0")

        `CHECK_REG(30, 32'd3,         "rstatus after sub overflow = 3")
        `CHECK_REG(13, 32'd2,         "non-overflow add: r13 = 2")

        $display("[PASS] All tests passed.");
        $stop;
    end
endmodule
