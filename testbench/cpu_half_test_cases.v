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

module cpu_half_test_cases();
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
        wait (dut.address_imem == 12'd24);
        @(posedge regfile_clock);

        `CHECK_REG( 1, 32'd65535,     "r1 = 65535")
        `CHECK_REG( 2, 32'h7FFF8000,  "r2 = r1 << 15")
        `CHECK_REG( 3, 32'h7FFFFFFF,  "r3 = r2 + 32767")
        `CHECK_REG( 4, 32'd1,         "r4 = 1")
        `CHECK_REG( 6, 32'd65536,     "r6 = r1 + r4")
        `CHECK_REG( 7, 32'h80000000,  "r7 = 1 << 31")
        `CHECK_REG( 9, 32'd65534,     "r9 = r1 - r4")
        `CHECK_REG(10, 32'd32768,     "r10 = r1 & r2")
        `CHECK_REG(12, 32'h7FFFFFFF,  "r12 = r1 | r2")

        `CHECK_REG(20, 32'd2,         "r20 = 2")
        `CHECK_REG(21, 32'd3,         "r21 = r4 + r20")
        `CHECK_REG(22, 32'd1,         "r22 = r20 - r4")
        `CHECK_REG(23, 32'd1,         "r23 = r22 & r21")
        `CHECK_REG(24, 32'd3,         "r24 = r20 | r23")
        `CHECK_REG(25, 32'd2,         "r25 = r23 << 1")
        `CHECK_REG(26, 32'd1,         "r26 = r25 >>> 1")

        `CHECK_REG(27, 32'd456,       "r27 = 456")
        `CHECK_REG(28, 32'd1,         "r28 = mem[1]")
        `CHECK_REG(29, 32'd2,         "r29 = mem[2]")
        `CHECK_REG(19, 32'd65535,     "r19 = mem[r27+0]")

        `CHECK_REG(30, 32'd0,         "r30 overflow status")

        $display("[PASS] All tests passed.");
        $stop;
    end
endmodule
