`timescale 1ns / 1ps
/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: 24 LUTs as distributed RAM on Xilinx Series 7 FPGA

    Package bcpu_regfile contains enum definitions shared between different modules of bcpu16 core

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


package bcpu_defs;

// flag indexes
typedef enum logic[1:0] {
    FLAG_C,        // carry flag, 1 when there is carry out or borrow from ADD/SUB, or shifted out bit for shifts
    FLAG_Z,        // zero flag, set to 1 when all bits of result are zeroes
    FLAG_S,        // sign flag, meaningful for signed operations (usually derived from HSB of result, sign bit)
    FLAG_V         // signed overflow flag, meaningful for signed arithmetic operations
} flag_index_t;
// flags: C,Z,S,V
typedef logic[3:0] bcpu_flags_t;

// BUS operation codes (operands: RB_imm is mask, RA is destination register for result)
typedef enum logic[1:0] {
    BUSOP_READ          = 2'b00, //  Bus read Rd = IBUS[i3] & Rb
    BUSOP_WRITE         = 2'b01, //  Bus write IBUS[i3] = (IBUS[i3] & ~Rb)\|(Ra & Rb)
    BUSOP_WAITE         = 2'b10, //  Bus wait until (IBUS[i3] & Rb) == (Ra & Rb)
    BUSOP_WAITNE        = 2'b11  //  Bus wait until (IBUS[i3] & Rb) != (Ra & Rb)
} bus_wr_op_t;

// Memory/jump address modes
typedef enum logic[1:0] {
//  mnemonic             opcode      
	ADDR_MODE_REG_OFFS5        = 2'b00,  // Rx + offset(5 bits)  Load/Store and Cond jumps
	ADDR_MODE_PC_OFFS8         = 2'b01,  // PC + offset(8 bits)  Load/Store and Cond jumps
	ADDR_MODE_PC_OFFS13_CALL   = 2'b10,  // PC + offset(13 bits) CALL
	ADDR_MODE_PC_OFFS13_JMP    = 2'b11   // PC + offset(13 bits) JMP
} addr_mode_t;

// Register write MUX control - source indexes
typedef enum logic [1:0] {
    // name                 index      
	REG_WRITE_FROM_ALU  = 2'b00,    //   Write to register from ALU
	REG_WRITE_FROM_BUS  = 2'b01,    //   Write to register from BUS
	REG_WRITE_FROM_MEM  = 2'b10,    //   Write to register from MEM
	REG_WRITE_FROM_JMP  = 2'b11     //   Write to register from JMP
} reg_write_source_t;

// ALU opcodes
typedef enum logic[3:0] {
//  mnemonic             opcode                                                   flags      mapped
	ALUOP_INC        = 4'b0000, //   RC = RA + RB                                 ....       MOV, NOP
	ALUOP_DEC        = 4'b0001, //   RC = RA - RB                                 ....
	ALUOP_RES0       = 4'b0010, //   reserved, not an ALU op                      ....
	ALUOP_RES1       = 4'b0011, //   reserved, not an ALU op                      ....

	ALUOP_ADD        = 4'b0100, //   RC = RA + RB                                 VSZC
	ALUOP_SUB        = 4'b0101, //   RC = RA - RB                                 VSZC       CMP
	ALUOP_ADDC       = 4'b0110, //   RC = RA + RB + CF                            VSZC
	ALUOP_SUBC       = 4'b0111, //   RC = RA - RB - CF                            VSZC       CMPC
	
	ALUOP_AND        = 4'b1000, //   RC = RA & RB                                 .SZ.
	ALUOP_XOR        = 4'b1001, //   RC = RA ^ RB                                 .SZ.
	ALUOP_OR         = 4'b1010, //   RC = RA | RB                                 .SZ.
	ALUOP_ANDN       = 4'b1011, //   RC = RA & ~RB                                .SZ.
	
	ALUOP_MUL        = 4'b1100, //   RC = low(RA * RB)                            .SZ.       SHL, SAL
	ALUOP_MULHUU     = 4'b1101, //   RC = high(unsigned RA * unsigned RB)         .SZ.       SHR
	ALUOP_MULHSS     = 4'b1110, //   RC = high(signed RA * signed RB)             .SZ.
	ALUOP_MULHSU     = 4'b1111  //   RC = high(signed RA * unsigned RB)           .SZ.       SAR
} aluop_t;



// condition codes for conditional jumps
typedef enum logic[3:0] {
    COND_NONE = 4'b0000, // jmp  1                 unconditional
    
    COND_NC   = 4'b0001, // jnc  c = 0             for C==1 test, use JB code
    COND_NZ   = 4'b0010, // jnz  z = 0             jne                                        !=
    COND_Z    = 4'b0011, // jz   z = 1             je                                         ==

    COND_NS   = 4'b0100, // jns  s = 0
    COND_S    = 4'b0101, // js   s = 1
    COND_NO   = 4'b0110, // jno  v = 0
    COND_O    = 4'b0111, // jo   v = 1

    COND_A    = 4'b1000, // ja   c = 0 & z = 0     above (unsigned compare)            !jbe    >
    COND_AE   = 4'b1001, // jae  c = 0 | z = 1     above or equal (unsigned compare)           >=
    COND_B    = 4'b1010, // jb   c = 1             below (unsigned compare)            jc      <
    COND_BE   = 4'b1011, // jbe  c = 1 | z = 1     below or equal (unsigned compare)   !ja     <=

    COND_L    = 4'b1100, // jl   v != s            less (signed compare)                       <
    COND_LE   = 4'b1101, // jle  v != s | z = 1    less or equal (signed compare)      !jg     <=
    COND_G    = 4'b1110, // jg   v = s & z = 0     greater (signed compare)            !jle    >
    COND_GE   = 4'b1111  // jge  v = s | z = 1     less or equal (signed compare)              >=
} jmp_condition_t;



endpackage
