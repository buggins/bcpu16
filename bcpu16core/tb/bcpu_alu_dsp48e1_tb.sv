`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/21/2020 11:18:56 AM
// Design Name: 
// Module Name: ref_frequency_gen_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


import bcpu_defs::*;

`define DEBUG_bcpu_alu_dsp48e1

module bcpu_alu_dsp48e1_tb(

    );

localparam DATA_WIDTH = 16;


// input clock, ~200..260MHz
logic CLK;
// when 1, enable pipeline step, when 0 pipeline is paused
logic CE;
// reset signal, active 1
logic RESET;

// enable ALU, (when 1, inputs contain new ALU operation, result will be available after 3 CLK cycles)
logic ALU_EN;

// operand A input
logic [DATA_WIDTH-1 : 0] A_IN;

// operand B input
logic [DATA_WIDTH-1 : 0] B_IN;

// alu operation code, see aluop_t enum 
logic [3:0] ALU_OP;

// input flags {V, S, Z, C}
logic [3:0] FLAGS_IN;
    
// output flags {V, S, Z, C} - delayed by 3 clock cycles from inputs
logic [3:0] FLAGS_OUT;

// alu result output         - delayed by 3 clock cycles from inputs
logic [DATA_WIDTH-1 : 0] ALU_OUT;

`ifdef DEBUG_bcpu_alu_dsp48e1
    logic [47:0] debug_dsp_p_out;
`endif    


bcpu_alu_dsp48e1
#(
    .DATA_WIDTH(DATA_WIDTH)
)
bcpu_alu_dsp48e1_inst
(
    .*
);

initial begin
    RESET = 0;
    CE = 0;
    ALU_EN = 0;
    ALU_OP = 0;
    FLAGS_IN = 0;
    A_IN = 0;
    B_IN = 0;
    #200 RESET = 1;
    #100 @(posedge CLK) RESET = 0;
end

task testAluOp( input [3:0] op, input [15:0] a, input [15:0] b, input [3:0] flags_in, input [15:0] expected_result, input [3:0] expected_flags);
    begin
        @(posedge CLK) #1 ALU_OP = op; A_IN = a; B_IN = b; CE = 1; ALU_EN = 1; FLAGS_IN = flags_in;
        @(posedge CLK) #1 ALU_OP = 0; A_IN = 0; B_IN = 0; FLAGS_IN = 0; ALU_EN = 0;
        @(posedge CLK) #1 ALU_EN = 0;
        @(posedge CLK) #1 
        $display("    ALU_OP %b  a=%x (%d)  b=%x (%d) vszc[%b]    expected  %x (%d) vszc[%b]   result %x (%d) vszc[%b]", op, a, a, b, b, flags_in, expected_result, expected_result, expected_flags, ALU_OUT, ALU_OUT, FLAGS_OUT);
        //$display("     result = %x (%d) vszc[%b]", ALU_OUT, ALU_OUT, FLAGS_OUT); CE = 0;
        if (ALU_OUT != expected_result) begin
            $display("  *** ERROR: RESULT DOES NOT MATCH: actual result %x (%d)   but expected %x (%d) ", ALU_OUT, ALU_OUT, expected_result, expected_result);
`ifdef DEBUG_bcpu_alu_dsp48e1
        $display("       dsp_p = %x (%d)", debug_dsp_p_out, debug_dsp_p_out);
`endif    
            $display("ALU result does not match");
            $finish();
        end
        if (FLAGS_OUT != expected_flags) begin
            $display("  *** ERROR: FLAGS DO NOT MATCH: actual flags  vszc[%b]   but expected vszc[%b]", FLAGS_OUT, expected_flags);
`ifdef DEBUG_bcpu_alu_dsp48e1
        $display("       dsp_p = %x (%d)", debug_dsp_p_out, debug_dsp_p_out);
`endif    
            $display("FLAGS do not match");
            $finish();
        end
    end
endtask

initial begin
    @(negedge RESET);
    #10
    $display("Testing ALUOP_ADD");
    testAluOp( ALUOP_ADD, 0, 0, 4'b0000, 0, 4'b0010);
    testAluOp( ALUOP_ADD, 0, 0, 4'b1111, 0, 4'b0010);
    testAluOp( ALUOP_ADD, 3, -3, 4'b0000, 3-3, 4'b0011);
    testAluOp( ALUOP_ADD, 3, -3, 4'b1111, 3-3, 4'b0011);
    testAluOp( ALUOP_ADD, 10, 23, 4'b0000, 10+23, 4'b0000);
    testAluOp( ALUOP_ADD, 10, 23, 4'b1111, 10+23, 4'b0000);
    testAluOp( ALUOP_ADD, 20000, 20000, 4'b1111, 20000+20000, 4'b1100);
    testAluOp( ALUOP_ADD, -20000, -20000, 4'b1111, -20000-20000, 4'b1001);
    $display("Testing ALUOP_ADÑ");
    testAluOp( ALUOP_ADDC, 0, 0, 4'b0000, 0, 4'b0010);
    testAluOp( ALUOP_ADDC, 0, 0, 4'b1111, 0+1, 4'b0000);
    testAluOp( ALUOP_ADDC, 3, -3, 4'b0000, 3-3, 4'b0011);
    testAluOp( ALUOP_ADDC, 3, -3, 4'b1111, 3-3+1, 4'b0001);
    testAluOp( ALUOP_ADDC, 10, 23, 4'b0000, 10+23, 4'b0000);
    testAluOp( ALUOP_ADDC, 10, 23, 4'b1111, 10+23+1, 4'b0000);
    testAluOp( ALUOP_ADDC, 20000, 20000, 4'b0000, 20000+20000, 4'b1100);
    testAluOp( ALUOP_ADDC, 20000, 20000, 4'b1111, 20000+20000+1, 4'b1100);
    testAluOp( ALUOP_ADDC, -20000, -20000, 4'b0000, -20000-20000, 4'b1001);
    testAluOp( ALUOP_ADDC, -20000, -20000, 4'b1111, -20000-20000+1, 4'b1001);
    $display("Testing ALUOP_INC");
    testAluOp( ALUOP_INC, 0, 0, 4'b0000, 0, 4'b0000);
    testAluOp( ALUOP_INC, 0, 0, 4'b1111, 0, 4'b1111);
    testAluOp( ALUOP_INC, 123, 456, 4'b0000, 123+456, 4'b0000);
    testAluOp( ALUOP_INC, 123, 456, 4'b1111, 123+456, 4'b1111);
    $display("Testing ALUOP_DEC");
    testAluOp( ALUOP_DEC, 0, 0, 4'b0000, 0, 4'b0000);
    testAluOp( ALUOP_DEC, 0, 0, 4'b1111, 0, 4'b1111);
    testAluOp( ALUOP_DEC, 1, 2, 4'b0000, 1-2, 4'b0000);
    testAluOp( ALUOP_DEC, 2, 1, 4'b1111, 2-1, 4'b1111);
    testAluOp( ALUOP_DEC, 12345, 54321, 4'b0000, 12345-54321, 4'b0000);
    testAluOp( ALUOP_DEC, 54321, 12345, 4'b1111, 54321-12345, 4'b1111);
    $display("Testing ALUOP_SUB");
    testAluOp( ALUOP_SUB, 0, 0, 4'b0000, 0, 4'b0010);
    testAluOp( ALUOP_SUB, 0, 0, 4'b1111, 0, 4'b0010);
    testAluOp( ALUOP_SUB, -20000, 20000, 4'b1111, -20000-20000, 4'b1000);
    testAluOp( ALUOP_SUB, 100, 200, 4'b0000, 100-200, 4'b0101);
    testAluOp( ALUOP_SUB, 200, 100, 4'b1111, 200-100, 4'b0000);
    $display("Testing ALUOP_SUBC");
    testAluOp( ALUOP_SUBC, 0, 0, 4'b0000, 0, 4'b0010);
    testAluOp( ALUOP_SUBC, 0, 0, 4'b1111, 0-1, 4'b0101);
    testAluOp( ALUOP_SUBC, -20000, 20000, 4'b0000, -20000-20000, 4'b1000);
    testAluOp( ALUOP_SUBC, -20000, 20000, 4'b1111, -20000-20000-1, 4'b1000);
    testAluOp( ALUOP_SUBC, 100, 200, 4'b0000, 100-200, 4'b0101);
    testAluOp( ALUOP_SUBC, 100, 200, 4'b1111, 100-200-1, 4'b0101);
    testAluOp( ALUOP_SUBC, 200, 100, 4'b0000, 200-100, 4'b0000);
    testAluOp( ALUOP_SUBC, 200, 100, 4'b1111, 200-100-1, 4'b0000);
    $display("Testing ALUOP_MUL");
    testAluOp( ALUOP_MUL, 0, 0, 4'b0000, 0, 4'b0000);
    testAluOp( ALUOP_MUL, 0, 0, 4'b1111, 0, 4'b1111);
    testAluOp( ALUOP_MUL, 1234, 5678, 4'b0000, 1234*5678, 4'b0000);
    testAluOp( ALUOP_MUL, 5432, 8765, 4'b1111, 5432*8765, 4'b1111);
    testAluOp( ALUOP_MUL, -1234, 5678, 4'b0000, -1234*5678, 4'b0000);
    testAluOp( ALUOP_MUL, 5432, -8765, 4'b1111, -5432*8765, 4'b1111);
    testAluOp( ALUOP_MUL, -1234,-5678, 4'b0000, 1234*5678, 4'b0000);
    testAluOp( ALUOP_MUL, 5432, -123, 4'b1111, -5432*123, 4'b1111);
    $finish();
end

always begin
    // CLK
    #2.5 CLK=0;
    #2.5 CLK=1;
end


endmodule
