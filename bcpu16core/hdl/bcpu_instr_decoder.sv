`timescale 1ns / 1ps
/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: 
            44 LUTs
               16 LUTs: ALU const table
               15 LUTs address adder
            
    Module bcpu_instr_decoder contains implementation of instruction decoder
    
    Resources:

Instructions table
------------------

| instruction code      | assembler          |  description                                      | flags |
|-----------------------|--------------------|---------------------------------------------------|-------|
| 0_0000_aaa_bbb_mm_ddd | INC Rd, Ra, B      |  Rd = Rn + B (like ADD, but no flags changed)     | ----  |
| 0_0001_aaa_bbb_mm_ddd | DEC Rd, Ra, B      |  Rd = Rn - B                                      | ----  |
| 0_0010_aaa_bbb_mm_ddd | reserved           |  Reserved for future extension                    | ----  |
| 0_0011_ddd_bbb_00_iii | IN Rd, Rb, i3      |  Bus read Rd = IBUS[i3] & Rb                      | --Z-  |
| 0_0011_aaa_bbb_01_iii | OUT Ra, Rb, i3     |  Bus write IBUS[i3] = (IBUS[i3] & ~Rb)\|(Ra & Rb) | ----  |
| 0_0011_aaa_bbb_10_iii | WAITE Ra, Rb, i3   |  Bus wait until (IBUS[i3] & Rb) == (Ra & Rb)      | ----  |
| 0_0011_aaa_bbb_11_iii | WAITNE Ra, Rb, i3  |  Bus wait until (IBUS[i3] & Rb) != (Ra & Rb)      | ----  |
| 0_0100_aaa_bbb_mm_ddd | ADD Rd, Ra, B      |  Rd = Rn + B                                      | VSZC  |
| 0_0101_aaa_bbb_mm_ddd | ADC Rd, Ra, B      |  Rd = Rn + B + C                                  | VSZC  |
| 0_0110_aaa_bbb_mm_ddd | SUB Rd, Ra, B      |  Rd = Rn - B                                      | VSZC  |
| 0_0111_aaa_bbb_mm_ddd | SBC Rd, Ra, B      |  Rd = Rn - B + 1 - C                              | VSZC  |
| 0_1000_aaa_bbb_mm_ddd | AND Rd, Ra, B      |  Rd = Rn & B                                      | -SZ-  |
| 0_1001_aaa_bbb_mm_ddd | ANN Rd, Ra, B      |  Rd = Rn & ~B                                     | -SZ-  |
| 0_1010_aaa_bbb_mm_ddd | OR  Rd, Ra, B      |  Rd = Rn \| B                                     | -SZ-  |
| 0_1011_aaa_bbb_mm_ddd | XOR Rd, Ra, B      |  Rd = Rn ^ B                                      | -SZ-  |
| 0_1100_aaa_bbb_mm_ddd | MUU Rd, Ra, B      |  Rd = ((unsigned)Rn * (unsigned)B) >> 16          | -SZC  |
| 0_1101_aaa_bbb_mm_ddd | MUL Rd, Ra, B      |  Rd = (Rn * B) >> 0                               | -SZC  |
| 0_1110_aaa_bbb_mm_ddd | MSU Rd, Ra, B      |  Rd = ((signed)Rn * (unsigned)B) >> 16            | -SZC  |
| 0_1111_aaa_bbb_mm_ddd | MSS Rd, Ra, B      |  Rd = ((signed)Rn * (signed)B) >> 16              | -SZC  |
| 1_0000_ddd_bbb_ii_iii | LOAD Rd, Rb+imm5   |  Rd = memory[Rb+imm5]                             | ----  |
| 1_0001_aaa_bbb_ii_iii | STORE Ra, Rb+imm5  |  memory[Rb+imm5] = Ra                             | ----  |
| 1_0010_ddd_iii_ii_iii | LOAD Rd, PC+imm8   |  Rd = memory[PC+imm8]                             | ----  |
| 1_0011_aaa_iii_ii_iii | STORE Ra, PC+imm8  |  memory[PC+imm8] = Ra                             | ----  |
| 1_010_cccc_bbb_ii_iii | J_cond, Rb+imm5    |  if (cccc) PC = Rb + imm5                         | ----  |
| 1_011_cccc_iii_ii_iii | J_cond, imm8       |  if (cccc) PC = PC + imm8                         | ----  |
| 1_10_iiiii_iii_ii_iii | CALL imm13         |  R7=PC+1, PC = PC+imm13                           | ----  |
| 1_11_iiiii_iii_ii_iii | JMP  imm13         |  PC = PC+imm13                                    | ----  |
    
*/

import bcpu_defs::*;

module bcpu_instr_decoder
#(
    // data width
    parameter DATA_WIDTH = 16,
    // instruction width
    parameter INSTR_WIDTH = 16,
    // program counter width (limits program memory size, PC_WIDTH <= ADDR_WIDTH)
    // PC_WIDTH should match local program/data BRAM size
    parameter PC_WIDTH = 10,
    // address width (limited by DATA_WIDTH, ADDR_WIDTH <= DATA_WIDTH)
    // when PC_WIDTH == ADDR_WIDTH, no shared mem extension of number of threads is supported
    // when PC_WIDTH < ADDR_WIDTH, higher address space can be used for shared mem of two 4-core CPUs
    //      and for higher level integration in multicore CPU
    parameter ADDR_WIDTH = 10,
    // bus address width
    parameter BUS_ADDR_WIDTH = 3,
    // number of bits in bus opcode, see bus_op_t in bcpu_defs
    parameter BUS_OP_WIDTH = 2,
    // number of bits in ALU opcode
    parameter ALU_OP_WIDTH = 4,
    // number of bits in register index (number of registers is 1<<REG_INDEX_WIDTH)
    parameter REG_INDEX_WIDTH = 3
)
(
    // INPUTS
    // instruction to decode - from program memory
    input logic [INSTR_WIDTH-1:0] INSTR_IN,
    // current program counter (address of this instruction)
    input logic [PC_WIDTH-1:0] PC_IN,
    // input flags {V, S, Z, C} -- for conditional jumps
    input logic [3:0] FLAGS_IN,

    // decoded instruction outputs
    // register A index : to register file
    output logic [REG_INDEX_WIDTH-1:0] A_INDEX,
    // register B or immediate index : to register file 
    output logic [REG_INDEX_WIDTH-1:0] B_INDEX,
    
    // register B value from register file -- for address and ALU operand calculations 
    input logic [DATA_WIDTH-1:0] B_VALUE_IN,
    // register B or const for ALU and IOBUS ops
    output logic [DATA_WIDTH-1:0] B_VALUE_OUT,
    
    // calculated address value (for LOAD,STORE,CALL,JUMP)
    output logic [ADDR_WIDTH-1:0] ADDR_VALUE,

    // destination register index
    output logic [REG_INDEX_WIDTH-1:0] DST_REG_INDEX,
    // data source mux index for writing to register
    output logic [1:0] DST_REG_SOURCE,
    // 1 to enable writing of operation result to destination register
    output logic DST_REG_WREN,

    // 1 for ALU op
    output logic ALU_EN,
    // 1 for BUS read op
    output logic BUS_RD_EN,
    // 1 for BUS write op
    output logic BUS_WR_EN,
    // 1 for LOAD and STORE ops
    output logic MEM_EN,
    // 1 for STORE op
    output logic MEM_WRITE_EN,
    // 1 for CALL and JMP with condition met
    output logic JMP_EN,

    // ALU operation code (valid if ALU_EN==1)
    output logic [ALU_OP_WIDTH-1:0] ALU_OP,

    // bus operation
    output logic [BUS_OP_WIDTH-1:0] BUS_OP,
    // bus address
    output logic [BUS_ADDR_WIDTH-1:0] BUS_ADDR


);

// instruction parts
logic [REG_INDEX_WIDTH-1:0] ra_index;
logic [REG_INDEX_WIDTH-1:0] rb_index;
logic [3:0] jmp_cond;
logic [1:0] imm_mode;
logic [1:0] addr_mode;
logic [12:0] addr_offset;
logic [ALU_OP_WIDTH-1:0] alu_op;
logic [BUS_OP_WIDTH-1:0] bus_op;
logic [BUS_ADDR_WIDTH-1:0] bus_addr;

// 1 if condition is met
logic cond_result;


// register A index 
assign A_INDEX = ra_index;
// register B or immediate index 
assign B_INDEX = rb_index;

/*  

| instruction code      | assembler          |  description                                      | flags |
|-----------------------|--------------------|---------------------------------------------------|-------|
| 0_0000_aaa_bbb_mm_ddd | INC Rd, Ra, B      |  Rd = Rn + B (like ADD, but no flags changed)     | ----  |
| 0_0001_aaa_bbb_mm_ddd | DEC Rd, Ra, B      |  Rd = Rn - B                                      | ----  |
| 0_0010_aaa_bbb_mm_ddd | reserved           |  Reserved for future extension                    | ----  |
| 0_0011_ddd_bbb_00_iii | IN Rd, Rb, i3      |  Bus read Rd = IBUS[i3] & Rb                      | --Z-  |
| 0_0011_aaa_bbb_01_iii | OUT Ra, Rb, i3     |  Bus write IBUS[i3] = (IBUS[i3] & ~Rb)\|(Ra & Rb) | ----  |
| 0_0011_aaa_bbb_10_iii | WAITE Ra, Rb, i3   |  Bus wait until (IBUS[i3] & Rb) == (Ra & Rb)      | ----  |
| 0_0011_aaa_bbb_11_iii | WAITNE Ra, Rb, i3  |  Bus wait until (IBUS[i3] & Rb) != (Ra & Rb)      | ----  |
| 0_0100_aaa_bbb_mm_ddd | ADD Rd, Ra, B      |  Rd = Rn + B                                      | VSZC  |
| 0_0101_aaa_bbb_mm_ddd | ADC Rd, Ra, B      |  Rd = Rn + B + C                                  | VSZC  |
| 0_0110_aaa_bbb_mm_ddd | SUB Rd, Ra, B      |  Rd = Rn - B                                      | VSZC  |
| 0_0111_aaa_bbb_mm_ddd | SBC Rd, Ra, B      |  Rd = Rn - B + 1 - C                              | VSZC  |
| 0_1000_aaa_bbb_mm_ddd | AND Rd, Ra, B      |  Rd = Rn & B                                      | -SZ-  |
| 0_1001_aaa_bbb_mm_ddd | ANN Rd, Ra, B      |  Rd = Rn & ~B                                     | -SZ-  |
| 0_1010_aaa_bbb_mm_ddd | OR  Rd, Ra, B      |  Rd = Rn \| B                                     | -SZ-  |
| 0_1011_aaa_bbb_mm_ddd | XOR Rd, Ra, B      |  Rd = Rn ^ B                                      | -SZ-  |
| 0_1100_aaa_bbb_mm_ddd | MUU Rd, Ra, B      |  Rd = ((unsigned)Rn * (unsigned)B) >> 16          | -SZC  |
| 0_1101_aaa_bbb_mm_ddd | MUL Rd, Ra, B      |  Rd = (Rn * B) >> 0                               | -SZC  |
| 0_1110_aaa_bbb_mm_ddd | MSU Rd, Ra, B      |  Rd = ((signed)Rn * (unsigned)B) >> 16            | -SZC  |
| 0_1111_aaa_bbb_mm_ddd | MSS Rd, Ra, B      |  Rd = ((signed)Rn * (signed)B) >> 16              | -SZC  |
| 1_0000_ddd_bbb_ii_iii | LOAD Rd, Rb+imm5   |  Rd = memory[Rb+imm5]                             | ----  |
| 1_0001_aaa_bbb_ii_iii | STORE Ra, Rb+imm5  |  memory[Rb+imm5] = Ra                             | ----  |
| 1_0010_ddd_iii_ii_iii | LOAD Rd, PC+imm8   |  Rd = memory[PC+imm8]                             | ----  |
| 1_0011_aaa_iii_ii_iii | STORE Ra, PC+imm8  |  memory[PC+imm8] = Ra                             | ----  |
| 1_010_cccc_bbb_ii_iii | J_cond, Rb+imm5    |  if (cccc) PC = Rb + imm5                         | ----  |
| 1_011_cccc_iii_ii_iii | J_cond, imm8       |  if (cccc) PC = PC + imm8                         | ----  |
| 1_10_iiiii_iii_ii_iii | CALL imm13         |  R7=PC+1, PC = PC+imm13                           | ----  |
| 1_11_iiiii_iii_ii_iii | JMP  imm13         |  PC = PC+imm13                                    | ----  |
*/

// simple decoding - slice instruction fields
always_comb ra_index <= INSTR_IN[10:8];  // aaa Source register index - to write to memory or bus or ALU operand 1
always_comb rb_index <= INSTR_IN[7:5];   // bbb Base address register index or ALU operand 2 register index, mask register index for bus operations
always_comb jmp_cond <= INSTR_IN[11:8];  // cccc        Condition code for conditional jumps 
always_comb imm_mode <= { INSTR_IN[4], INSTR_IN[3]};    // ALU operand B immediate mode
always_comb addr_mode <= {INSTR_IN[14], INSTR_IN[12]};  // mem and jump address mode
always_comb addr_offset <= INSTR_IN[12:0]; // 5/8/13 bits of address offset
always_comb alu_op <= INSTR_IN[14:11];   // ALU opcode
always_comb bus_op <= INSTR_IN[4:3];     // bus op
always_comb bus_addr <= INSTR_IN[2:0];   // bus address for bus ops

assign A_INDEX = ra_index;
assign B_INDEX = rb_index;

//logic [2:0] instr_category;
//assign instr_category = INSTR_IN[17:15]; 

// 0 oo aaaa m bbbb oo rrrr
assign ALU_OP = alu_op;
assign BUS_OP = bus_op;

// ALU: bit15==0, except bus ops
logic is_alu_op;
always_comb is_alu_op <= (INSTR_IN[15] == 0) && (ALU_OP != ALUOP_RES0) && (ALU_OP != ALUOP_RES1);
assign ALU_EN    = is_alu_op;

/*
| 0_0011_ddd_bbb_00_iii | IN Rd, Rb, i3      |  Bus read Rd = IBUS[i3] & Rb                      | --Z-  |
| 0_0011_aaa_bbb_01_iii | OUT Ra, Rb, i3     |  Bus write IBUS[i3] = (IBUS[i3] & ~Rb)\|(Ra & Rb) | ----  |
| 0_0011_aaa_bbb_10_iii | WAITE Ra, Rb, i3   |  Bus wait until (IBUS[i3] & Rb) == (Ra & Rb)      | ----  |
| 0_0011_aaa_bbb_11_iii | WAITNE Ra, Rb, i3  |  Bus wait until (IBUS[i3] & Rb) != (Ra & Rb)      | ----  |
*/
logic is_bus_op;
logic is_bus_read;
always_comb is_bus_op <= (ALU_OP == ALUOP_RES1);
always_comb is_bus_read <= is_bus_op & (INSTR_IN[4:3] != BUSOP_WRITE);
always_comb BUS_RD_EN = is_bus_read;
always_comb BUS_WR_EN = is_bus_op & (INSTR_IN[4:3] == BUSOP_WRITE);

/*
| 1_0000_ddd_bbb_ii_iii | LOAD Rd, Rb+imm5   |  Rd = memory[Rb+imm5]                             | ----  |
| 1_0001_aaa_bbb_ii_iii | STORE Ra, Rb+imm5  |  memory[Rb+imm5] = Ra                             | ----  |
| 1_0010_ddd_iii_ii_iii | LOAD Rd, PC+imm8   |  Rd = memory[PC+imm8]                             | ----  |
| 1_0011_aaa_iii_ii_iii | STORE Ra, PC+imm8  |  memory[PC+imm8] = Ra                             | ----  |
*/
logic is_mem_read;
always_comb is_mem_read <= (INSTR_IN[15:13] == 3'b100) && (~INSTR_IN[11]);
always_comb MEM_EN    <= (INSTR_IN[15:13] == 3'b100);
always_comb MEM_WRITE_EN  <= (INSTR_IN[15:13] == 3'b100) && (INSTR_IN[11]);

/*
| 1_010_cccc_bbb_ii_iii | J_cond, Rb+imm5    |  if (cccc) PC = Rb + imm5                         | ----  |
| 1_011_cccc_iii_ii_iii | J_cond, imm8       |  if (cccc) PC = PC + imm8                         | ----  |
| 1_10_iiiii_iii_ii_iii | CALL imm13         |  R7=PC+1, PC = PC+imm13                           | ----  |
| 1_11_iiiii_iii_ii_iii | JMP  imm13         |  PC = PC+imm13                                    | ----  |
*/
logic is_call;
always_comb is_call <= (INSTR_IN[15:13] == 3'b110);
always_comb JMP_EN   <= (INSTR_IN[15:14] == 2'b11) // CALL and JMP
                      | ((INSTR_IN[15:13] == 3'b101) & cond_result); 

// 0 00 rrrr m bbbb 1 oo aaa
always_comb BUS_OP <= bus_op;
always_comb BUS_ADDR <= bus_addr;


logic [2:0] dst_reg;
/*
| 0_0000_aaa_bbb_mm_ddd | INC Rd, Ra, B      |  Rd = Rn + B (like ADD, but no flags changed)     | ----  |
| 1_0000_ddd_bbb_ii_iii | LOAD Rd, Rb+imm5   |  Rd = memory[Rb+imm5]                             | ----  |
| 1_10_iiiii_iii_ii_iii | CALL imm13         |  R7=PC+1, PC = PC+imm13                           | ----  |
| 1_11_iiiii_iii_ii_iii | JMP  imm13         |  PC = PC+imm13                                    | ----  |
*/
assign dst_reg = is_alu_op ? INSTR_IN[2:0] : (is_call ? 3'b111 : INSTR_IN[10:8]);

//    // destination register index
assign DST_REG_INDEX = dst_reg; 
//    // data source mux index for writing to register
assign DST_REG_SOURCE = is_alu_op    ? REG_WRITE_FROM_ALU
                      : is_mem_read  ? REG_WRITE_FROM_MEM
                      : is_call      ? REG_WRITE_FROM_JMP
                      :                REG_WRITE_FROM_BUS;
// 1 to enable writing of operation result to destination register
assign DST_REG_WREN 
                = (    is_alu_op 
                    || is_mem_read
                    || is_bus_read 
                    || is_call
                  ) 
                    && (dst_reg != 3'b000); 


logic [ADDR_WIDTH-1:0] addr_value;
assign ADDR_VALUE = addr_value;

bcpu_addr_adder
#(
    // address width
    .ADDR_WIDTH(ADDR_WIDTH)
)
bcpu_addr_adder_inst
(
    .RB_IN(B_VALUE_IN[ADDR_WIDTH-1:0]),
    .PC_IN({ {ADDR_WIDTH-PC_WIDTH{1'b0}},  PC_IN}),
    // offset 10 bits, for MODE=0 top 4 bits should be zeroed
    .OFFSET_IN(addr_offset),
    .MODE(addr_mode),
    .ADDR_OUT(addr_value)
);

logic [DATA_WIDTH - 1 : 0] b_value;
assign B_VALUE_OUT = b_value;

bcpu_breg_consts
#(
    .DATA_WIDTH(DATA_WIDTH)
)
bcpu_breg_consts_inst
(
    // input register value
    .B_VALUE_IN(B_VALUE_IN),
    // B register index from instruction - used as const index when CONST_MODE==1 
    .B_REG_INDEX(rb_index), 
    // const_mode- when !=00, replace B register value with constant
    .CONST_MODE(imm_mode),
    // output value: CONST_MODE?(1<<B_REG_INDEX):B_VALUE_IN    
    .B_VALUE_OUT(b_value)
);

bcpu_cond_eval bcpu_cond_eval_inst
(
    // input flag values {V,S,Z,C}
    .FLAGS_IN(FLAGS_IN),
    // condition code, 0000 is unconditional
    .CONDITION_CODE(jmp_cond),
    
    // 1 if condition is met
    .CONDITION_RESULT(cond_result)
);


endmodule
