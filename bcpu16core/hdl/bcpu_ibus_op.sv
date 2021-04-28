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

module bcpu_ibus_op
#(
    // data width
    parameter DATA_WIDTH = 16,
    // bus address width
    parameter BUS_ADDR_WIDTH = 3,
    // size of input bus, in bits, addressable by DATA_WIDTH slices (1..128)
    parameter IBUS_BITS = 4
)
(
    // input clock
    input logic CLK,
    // when 1, enable pipeline step, when 0 pipeline is paused
    input logic CE,
    // reset signal, active 1
    input logic RESET,

    // 1 if instruction is BUS READ operation
    input logic BUS_RD_EN,
    
    // Bus operation bist from instruction
    input logic [1:0] BUS_OP,
    
    // ibus or obus address (stage1)
    input logic [BUS_ADDR_WIDTH-1:0] BUS_ADDR,
    
    // register A operand value (stage1)
    input logic [DATA_WIDTH-1:0] A_VALUE,
    // register B operand value or immediate constant (stage1)
    input logic [DATA_WIDTH-1:0] B_VALUE,

    // stage2 output
    // 1 to repeat current instruction, 0 to allow moving to next instruction
    output logic WAIT_REQUEST,
    
    // stage3 outputs
    // read value, to store into register
    output logic [DATA_WIDTH-1:0] OUT_VALUE,
    
    // 1 to write OUT_VALUE to register
    //output logic SAVE_VALUE,
    // Z flag value output at stage2
    output logic OUT_ZFLAG,
    // 1 to replace ALU's Z flag with OUT_ZFLAG at stage2 
    output logic SAVE_ZFLAG,

    // bus connections
    // input bus
    input logic [IBUS_BITS-1:0] IBUS
);

localparam IBUS_SLICE_WIDTH = IBUS_BITS < 16 ? IBUS_BITS : 16;

localparam IBUS_ADDR_WIDTH = IBUS_BITS <= 16  ? 0
                           : IBUS_BITS <= 32  ? 1
                           : IBUS_BITS <= 64  ? 2
                           :                    3;

logic ibus_readop;
always_comb ibus_readop = (CE && BUS_RD_EN); 
logic [IBUS_SLICE_WIDTH-1:0] ibus_buf;
generate   
    // more than one slice: need multiplexing
    // truncate ibus address
    logic [(IBUS_ADDR_WIDTH > 0 ? IBUS_ADDR_WIDTH : 1)-1:0] ibus_addr;
    always_comb ibus_addr <= IBUS_ADDR_WIDTH > 0 ? BUS_ADDR[IBUS_ADDR_WIDTH-1:0] : 'b0;
    // pad input bus with zeroes to simplify indexing
    logic [DATA_WIDTH-1:0] ibus_extended[1 << IBUS_ADDR_WIDTH];
    always_comb
        for (int i = 0; i < (1 << IBUS_ADDR_WIDTH); i++)
            for (int j = 0; j < IBUS_SLICE_WIDTH; j++)
                ibus_extended[i][j] <= (i * IBUS_SLICE_WIDTH + j < IBUS_BITS) ?
                    IBUS[i * DATA_WIDTH + j] 
                    : 1'b0;
    // mux + FF for storing input value, address applied
    always_ff @(posedge CLK) begin
        if (RESET)
            ibus_buf <= 'b0;
        else if (CE & ibus_readop) begin
            ibus_buf <= ibus_extended[ibus_addr];
        end
    end

logic [IBUS_SLICE_WIDTH-1:0] a_buf;
logic [IBUS_SLICE_WIDTH-1:0] b_buf;
logic [1:0] busop_buf;
logic ibus_readop_buf;
always_ff @(posedge CLK) begin
    if (RESET) begin
        a_buf <= 'b0;
        b_buf <= 'b0;
        busop_buf <= 'b0;
    end else if (CE) begin // no ibus_readop to share buffer with other modules 
        a_buf <= A_VALUE[IBUS_SLICE_WIDTH-1:0];
        b_buf <= B_VALUE[IBUS_SLICE_WIDTH-1:0];
        busop_buf <= BUS_OP;
    end
end
always_ff @(posedge CLK)
    if (RESET)
        ibus_readop_buf <= 'b0;
    else if (CE)
        ibus_readop_buf <= ibus_readop;
logic [DATA_WIDTH-1:0] ibus_op_result;
always_comb begin
    if (busop_buf == BUSOP_READ)
        ibus_op_result = ibus_buf & b_buf;
    else
        ibus_op_result = (ibus_buf & b_buf) ^ (a_buf & b_buf);
end
logic zflag;
always_comb zflag = ~(|ibus_op_result); // all bits are zero
logic [DATA_WIDTH-1:0] ibus_out_buf;
always_ff @(posedge CLK)
    if (RESET)
        ibus_out_buf <= 'b0;
    else if (CE & ibus_readop_buf)
        ibus_out_buf <= ibus_op_result;

assign OUT_VALUE = {{DATA_WIDTH-IBUS_SLICE_WIDTH{1'b0}}, ibus_out_buf};
logic wait_req;
always_comb
    wait_req = ((busop_buf == BUSOP_WAITE) & ~zflag) || ((busop_buf == BUSOP_WAITNE) & zflag);

assign WAIT_REQUEST = wait_req;
assign OUT_ZFLAG = zflag;
assign SAVE_ZFLAG = ibus_readop_buf & (busop_buf == BUSOP_READ);

endgenerate


endmodule
