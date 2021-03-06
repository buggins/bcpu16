BCPU16
======

This is small but powerful MCU softcore for using inside FPGA.

**Language: System Verilog**

**License: GNU LGPL V2**

**Platform: Xilinx Series 7 FPGA, but may be ported to other platforms**

**Main features:**

* RISC architecture, LOAD/STORE
* Fixed instruction width 16 bits
* 8 general purpose 16-bit registers
* 3-address ALU operations to reduce register-register moves
* 4-stage pipeline executing 4 threads (barrel CPU)
* Up to 64K x 16bit words of program/data address space
* Up to 128 bits of input and 128 bits ouput bus, atomic bit-masked access as 16-bit slices
* Special wait instructions to react on input signal change in one cycle - emulation of interrupts
* Low resource usage: Only 150 LUTs + 1 BRAM + 1 DSP on Xilinx Series 7 platform
* High performance: 260 MHz clock (65MHz x 4 threads) on Xilinx Series 7 FPGAs with speed grade -1



BCPU16 instruction set architecture
===================================

All instructions have fixed width: 16 bits

Registers
---------

8 x 16bit general purpose registers R0..R7
*R0* is readonly constant 0, writes ignored
*R7* is set to return address when CALL instruction is executed (acts as link register)
Registers encoded inside instructions as 3-bit indexes (aaa,bbb,ddd)

Program counter register PC, configurable width (10..16 bits)

Flags register: 4 flags

| name | description                   |
|------|-------------------------------|
| C    | carry                         |  
| Z    | zero                          |
| S    | sign                          |
| V    | signed arithmetic overflow    |

For 4-threaded barrel mode, 4 copies of all registers, flags and PC are needed - one per thread.


Instruction types
-----------------

| Instruction type | Description | Number of instructions | Address modes |
|------------------|-------------|------------------------|---------------|
| ALU instructions | Arithmetic, logic, multiplication, barrel shifter emulated by multiplication | 12 | 3-address: destination register, operand A register, operand B register or immediate constant |
| LOAD/STORE | Load from memory to register, store register to memory | 2 | register + 5-bit signed offset, PC + 8-bit signed offset |
| Conditional jumps/returns | Conditional jump based on flags (16 combinations) | 1 | register + 5-bit signed offset, PC + 8-bit signed offset |
| JUMP and CALL | Jump relative to PC, for CALL stores return address in R7 (link register) | 2 | PC + 13-bit signed offset |
| I/O BUS instructions | Write output bus bits, read input bus bits, wait for 0 or 1 on input bus | 3 | Bus address is 3 bits (8 16-bit slices) |


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

Instruction code fields:

| name  | description                                                   |
|-------|---------------------------------------------------------------|
| aaa   | operand A register index                                      |
| bbb   | operand B register index                                      |
| ddd   | destination register index, write ignored for R0 (ddd==000)   |
| iiiii | immediate address offset (3, 5, 8, 13 bits)                   |
| mm    | ALU op operand B mode (00: register, 01..11: table constants) |
| cccc  | condition code for jumps                                      |



Operand B for ALU
-----------------

As operand B, register or table constant can be used.
16 of 24 constants contain single bit set, the rest 8 contain several other useful values.

| mm | bbb | B operand value     |  Description                    |
|----|-----|---------------------|---------------------------------|
| 00 | 000 | R0                  |  Register R0 value (constant 0) |
| 00 | 001 | R1                  |  Register R1 value              |
| 00 | 010 | R2                  |  Register R2 value              |
| 00 | 011 | R3                  |  Register R3 value              |
| 00 | 100 | R4                  |  Register R4 value              |
| 00 | 101 | R5                  |  Register R5 value              |
| 00 | 110 | R6                  |  Register R6 value              |
| 00 | 111 | R7                  |  Register R7 value              |
| 01 | 000 | 0000_0000_0000_0011 |  3                              |
| 01 | 001 | 0000_0000_0000_0101 |  5                              |
| 01 | 010 | 0000_0000_0000_0110 |  6                              |
| 01 | 011 | 0000_0000_0000_0111 |  7                              |
| 01 | 100 | 0000_0000_0000_1111 |  15                             |
| 01 | 101 | 0000_0000_1111_1111 |  0x00FF (lower byte mask)       |
| 01 | 110 | 1111_1111_0000_0000 |  0xFF00 (higher byte mask)      |
| 01 | 111 | 1111_1111_1111_1111 |  0xFFFF (-1, all bits set)      |
| 10 | 000 | 0000_0000_0000_0001 |  1 (bit 0 mask)                 |
| 10 | 001 | 0000_0000_0000_0010 |  2 (bit 1 mask)                 |
| 10 | 010 | 0000_0000_0000_0100 |  4 (bit 2 mask)                 |
| 10 | 011 | 0000_0000_0000_1000 |  8 (bit 3 mask)                 |
| 10 | 100 | 0000_0000_0001_0000 |  16 (bit 4 mask)                |
| 10 | 101 | 0000_0000_0010_0000 |  32 (bit 5 mask)                |
| 10 | 110 | 0000_0000_0100_0000 |  64 (bit 6 mask)                |
| 10 | 111 | 0000_0000_1000_0000 |  128 (bit 7 mask)               |
| 11 | 000 | 0000_0001_0000_0000 |  256 (bit 8 mask)               |
| 11 | 001 | 0000_0010_0000_0000 |  512 (bit 9 mask)               |
| 11 | 010 | 0000_0100_0000_0000 |  1024 (bit 10 mask)             |
| 11 | 011 | 0000_1000_0000_0000 |  2048 (bit 11 mask)             |
| 11 | 100 | 0001_0000_0000_0000 |  4096 (bit 12 mask)             |
| 11 | 101 | 0010_0000_0000_0000 |  8192 (bit 13 mask)             |
| 11 | 110 | 0100_0000_0000_0000 |  16384 (bit 14 mask)            |
| 11 | 111 | 1000_0000_0000_0000 |  32768 (bit 15 mask)            |


Condition codes
---------------

| cccc | asm    | condition       |  description                       |     |
|------|--------|-----------------|------------------------------------|-----|
| 0000 | jmp    | 1               |  unconditional                     |     |
| 0001 | jnc    | c = 0           |  for C==1 test, use JB code        |     |
| 0010 | jnz    | z = 0           |  not equal (jne)                   | !=  |
| 0011 | jz     | z = 1           |  equal (je)                        | ==  |
| 0100 | jns    | s = 0           |  sign is 0                         |     |
| 0101 | js     | s = 1           |  sign is 1                         |     |
| 0110 | jno    | v = 0           |  no overflow                       |     |
| 0111 | jo     | v = 1           |  overflow                          |     |
| 1000 | ja     | c = 0 & z = 0   |  above (unsigned compare)          |  >  |
| 1001 | jae    | c = 0 \| z = 1  |  above or equal (unsigned compare) |  >= |
| 1010 | jb, jc | c = 1           |  below (unsigned compare)          |  <  |
| 1011 | jbe    | c = 1 \| z = 1  |  below or equal (unsigned compare) |  <= |
| 1100 | jl     | v != s          |  less (signed compare)             |  <  |
| 1101 | jle    | v != s \| z = 1 |  less or equal (signed compare)    |  <= |
| 1110 | jg     | v = s & z = 0   |  greater (signed compare)          |  >  |
| 1111 | jge    | v = s \| z = 1  |  less or equal (signed compare)    |  >= |

Instruction aliases
-------------------

Specifying destination register to 0 in ALU operations allows to implement instructions which only setting flags as a result.

| Alias instruction  | Implemented as | Description                             |
|--------------------|----------------|-----------------------------------------|
| NOP                | INC R0, R0, R0 | No operation, instruction code is 16'b0 |
| MOV Rd, Ra         | INC Rd, Ra, R0 | Move value from one register to another |
| CMP Ra, Rb         | SUB R0, Ra, B  | Compare two registers                   |
| CMPC Ra, Rb        | SBC R0, Ra, B  | Compare two registers with carry        |



