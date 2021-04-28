`timescale 1ns / 1ps

/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: no LUTs, 1 RAMB18 for address width 10, 2 RAMB36 for address width 12 on Xilinx Series 7 FPGA

    Module bcpu_bus_op contains implementation of input and output bus operations.
    
    Resources:
       IBUS buffering:
            1 LUT for FF CE
            + 
              0 LUTS if IBUS_BITS<=16
              8 LUTS if IBUS_BITS<=32
              16 LUTS if IBUS_BITS<=64
              32 LUTS if IBUS_BITS<=128

Instructions table
------------------

| instruction code      | assembler          |  description                                      | flags |
|-----------------------|--------------------|---------------------------------------------------|-------|
| 0_0011_ddd_bbb_00_iii | IN Rd, Rb, i3      |  Bus read Rd = IBUS[i3] & Rb                      | --Z-  |
| 0_0011_aaa_bbb_01_iii | OUT Ra, Rb, i3     |  Bus write IBUS[i3] = (IBUS[i3] & ~Rb)\|(Ra & Rb) | ----  |
| 0_0011_aaa_bbb_10_iii | WAITE Ra, Rb, i3   |  Bus wait until (IBUS[i3] & Rb) == (Ra & Rb)      | ----  |
| 0_0011_aaa_bbb_11_iii | WAITNE Ra, Rb, i3  |  Bus wait until (IBUS[i3] & Rb) != (Ra & Rb)      | ----  |
    
*/

import bcpu_defs::*;

module bcpu_obus_op
#(
    // data width
    parameter DATA_WIDTH = 16,
    // bus address width
    parameter BUS_ADDR_WIDTH = 3,
    // size of output bus, in bits, addressable by DATA_WIDTH slices (1..128)
    parameter OBUS_BITS = 4
)
(
    // input clock
    input logic CLK,
    // when 1, enable pipeline step, when 0 pipeline is paused
    input logic CE,
    // reset signal, active 1
    input logic RESET,

    // 1 if instruction is BUS WRITE operation
    input logic BUS_WR_EN,
    
    // Bus operation bist from instruction
    //input logic [1:0] BUS_OP,
    
    // ibus or obus address (stage1)
    input logic [BUS_ADDR_WIDTH-1:0] BUS_ADDR,
    
    // register A operand value (stage1)
    input logic [DATA_WIDTH-1:0] A_VALUE,
    // register B operand value or immediate constant (stage1)
    input logic [DATA_WIDTH-1:0] B_VALUE,

    // output bus
    output logic [OBUS_BITS-1:0] OBUS
    
);


localparam OBUS_SLICE_WIDTH = OBUS_BITS < 16  ? OBUS_BITS : 16;
localparam OBUS_ADDR_WIDTH = OBUS_BITS <= 16  ? 0
                           : OBUS_BITS <= 32  ? 1
                           : OBUS_BITS <= 64  ? 2
                           :                    3;
localparam int OBUS_SLICE_COUNT = ((OBUS_BITS + 15) >> 4) + 1;
logic obus_slice_wren[OBUS_SLICE_COUNT];
logic [OBUS_BITS-1:0] obus_buf;
assign OBUS = obus_buf;
logic obus_wren;
always_comb obus_wren = CE && BUS_WR_EN;

generate
    always_comb
        for (int i = 0; i < OBUS_SLICE_COUNT; i++) begin
            if (OBUS_ADDR_WIDTH > 0)
                obus_slice_wren[i] = obus_wren && (i == BUS_ADDR[OBUS_ADDR_WIDTH-1:0]);
            else 
                obus_slice_wren[i] = obus_wren;
        end
    always_ff @(posedge CLK) begin
        for (int i = 0; i < OBUS_BITS; i++) begin
            if (RESET)
                obus_buf[i] <= 'b0;
            else if (obus_slice_wren[(i + 15) >> 4]) begin
                obus_buf[i] <= (obus_buf[i] & ~(B_VALUE[i & 4'b1111])) | (A_VALUE[i & 4'b1111] & B_VALUE[i & 4'b1111]);
            end
        end
    end
endgenerate

endmodule
