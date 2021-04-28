`timescale 1ns / 1ps
/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: 
            ADDR_WIDTH    LUTs
            10            15
            12            19
            14            23
            16            27
            
            
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


module bcpu_addr_adder
#(
    // address width
    parameter ADDR_WIDTH = 10
)
(
    // general purpose register value
    input logic [ADDR_WIDTH-1:0] RB_IN,
    // program counter value
    input logic [ADDR_WIDTH-1:0] PC_IN,
    // offset 13, 8, or 5 bits
    input logic signed [12:0] OFFSET_IN,
    // 00: Rb+offset5, 01: PC+offset8, 1x: PC+offset13 
    input logic [1:0] MODE,
    // effective address calculated: reg + offset
    output logic [ADDR_WIDTH-1:0] ADDR_OUT
);

// fill unused offset bits with sign
logic signed [12:0] offset;
always_comb offset[4:0] <= OFFSET_IN[4:0];
always_comb offset[7:5] <= (MODE == 2'b00) ? {3{OFFSET_IN[4]}} : OFFSET_IN[7:5];
always_comb offset[12:8] <= (~MODE[1]) ? {5{MODE[0] ? OFFSET_IN[7] : OFFSET_IN[4]}} : OFFSET_IN[12:8];

// base register mux
logic [ADDR_WIDTH-1:0] base;
always_comb base <= (MODE == 2'b00) ? RB_IN : PC_IN;


assign ADDR_OUT = base + offset; //addr[ADDR_WIDTH-1:0];

endmodule
