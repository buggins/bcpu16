`timescale 1ns / 1ps

/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: 24 LUTs as distributed RAM on Xilinx Series 7 FPGA

    Module bcpu_regfile implements 8 regs * 16 bits * 4 threads, 
    dual read ports, single write port, 
    async read, sync write register file.
*/

module bcpu_regfile
#(
    parameter DATA_WIDTH = 16,     // 16, 17, 18
    parameter REG_ADDR_WIDTH = 5   // 2^3 regs * 2^2 threads = 5 bits for 32 registers addressing 
)
(
    // input clock: write operation is done synchronously using this clock
    input logic CLK,
    
    //=========================================
    // Synchronous write port
    // when WR_EN == 1, write value WR_DATA to address WR_ADDR on raising edge of CLK 
    input logic REG_WR_EN,
    input logic [REG_ADDR_WIDTH-1:0] WR_REG_ADDR,
    input logic [DATA_WIDTH-1:0] WR_REG_DATA,
    
    //=========================================
    // asynchronous read port A
    // always exposes value from address RD_ADDR_A to RD_DATA_A
    input logic [REG_ADDR_WIDTH-1:0] RD_REG_ADDR_A,
    output logic [DATA_WIDTH-1:0] RD_REG_DATA_A,

    //=========================================
    // asynchronous read port B 
    // always exposes value from address RD_ADDR_B to RD_DATA_B
    input logic [REG_ADDR_WIDTH-1:0] RD_REG_ADDR_B,
    output logic [DATA_WIDTH-1:0] RD_REG_DATA_B
);

localparam MEMSIZE = 1 << REG_ADDR_WIDTH;
logic [DATA_WIDTH-1:0] memory[MEMSIZE] = { 
                            0, 0, 0, 0, 0, 0, 0, 0,
                            0, 0, 0, 0, 0, 0, 0, 0,
                            0, 0, 0, 0, 0, 0, 0, 0,
                            0, 0, 0, 0, 0, 0, 0, 0 
                        };

// one channe for synchronous write
always_ff @(posedge CLK)
    if (REG_WR_EN)
        memory[WR_REG_ADDR] <= WR_REG_DATA;

// two channels for asynchronous read
always_comb RD_REG_DATA_A <= memory[RD_REG_ADDR_A];
always_comb RD_REG_DATA_B <= memory[RD_REG_ADDR_B];

endmodule
