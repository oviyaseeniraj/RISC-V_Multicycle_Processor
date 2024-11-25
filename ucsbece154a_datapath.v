// ucsbece154a_datapath.v
// All Rights Reserved
// Copyright (c) 2023 UCSB ECE
// Distribution Prohibited

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TO DO: Add mising code below  
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module ucsbece154a_datapath (
    input               clk, reset,
    input               PCEn_i,
    input         [1:0] ALUSrcA_i,
    input         [1:0] ALUSrcB_i,
    input               RegWrite_i,
    input               AdrSrc_i,
    input               IRWrite_i,
    input         [1:0] ResultSrc_i,
    input         [2:0] ALUControl_i,
    input         [2:0] ImmSrc_i,
    output  wire        zero_o,
    output  wire [31:0] Adr_o,                       
    output  wire [31:0] WriteData_o,                    
    input        [31:0] ReadData_i,
    output  wire [6:0]  op_o,
    output  wire [2:0]  funct3_o,
    output  wire        funct7_o
);

`include "ucsbece154a_defines.vh"


// Internal registers

reg [31:0] PC, OldPC, Instr, Data, A, B, ALUout;

// Buses connected to internal registers
reg [31:0] Result;
wire [4:0] a1 = Instr[19:15];
wire [4:0] a2 = Instr[24:20];
wire [4:0] a3 = Instr[11:7];
wire [31:0] rd1, rd2;
wire [31:0] ALUResult;

// intermediates for src muxes
wire [31:0] srcA, srcB;
reg [31:0] muxed_srcA, muxed_srcB;
assign srcA = muxed_srcA;
assign srcB = muxed_srcB;

// CONNECT outputs  
assign Adr_o = Adr;
assign funct3_o = Instr[14:12];
assign funct7_o = Instr[30];
assign op_o = Instr[6:0];

// Update for all internal registers

always @(posedge clk) begin
    if (reset) begin
        PC <= pc_start;
        OldPC <= {32{1'bx}};
        Instr <= {32{1'bx}};
        Data <= {32{1'bx}};
        A <= {32{1'bx}};
        B <= {32{1'bx}};
        ALUout <= {32{1'bx}};
    end else begin
        if (PCEn_i) PC <= Result;
        if (IRWrite_i) OldPC <= PC;
        if (IRWrite_i) Instr <= ReadData_i;
        Data <= ReadData_i;
        A <= rd1;
        B <= rd2;
        ALUout <= ALUResult;
    end
end

// **PUT THE REST OF YOUR CODE HERE**

ucsbece154a_rf rf (
    .clk(clk),
    .a1_i(a1),
    .a2_i(a2),
    .a3_i(a3),
    .rd1_o(rd1),
    .rd2_o(rd2),
    .we3_i(RegWrite_i),
    .wd3_i(ALUResult)
);


ucsbece154a_alu alu (
    .a_i(srcA),
    .b_i(srcB),
    .alucontrol_i(ALUControl_i),
    .result_o(ALUResult),
    .zero_o(zero_o)
);

// Extend unit block

reg [31:0] sign_extended_imm;
always @ * begin
    case (ImmSrc_i)
        imm_Itype: sign_extended_imm = {{20{Instr[31]}}, Instr[31:20]};
        imm_Utype: sign_extended_imm = {Instr[31:12], 12'b0}; // lui, left shift
        imm_Stype: sign_extended_imm = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
        imm_Btype: sign_extended_imm = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};
        imm_Jtype: sign_extended_imm = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0};
        default:   sign_extended_imm = 32'b0;
    endcase
end

// Muxes
assign WriteData_o = B;                  // Data written to memory comes from register B

// PC Mux - PCSrc_i selects between PC+4 and branch/jump target
always @ * begin
    case (AdrSrc_i)
        1'b0: Adr = PC;
        1'b1: Adr = Result;
    endcase
end

always @ * begin
    case (ALUSrcA_i)
        ALUSrcA_pc:    muxed_srcA = PC;
        ALUSrcA_oldpc: muxed_srcA = OldPC;
        ALUSrcA_reg:   muxed_srcA = A;     // Register file output
        default:       muxed_srcA = 32'b0;
    endcase
end

always @ * begin
    case (ALUSrcB_i)
        ALUSrcB_reg:   muxed_srcB = B;    // Register file output
        ALUSrcB_imm:   muxed_srcB = sign_extended_imm; // Immediate value
        ALUSrcB_4:     muxed_srcB = 32'd4; // Constant value (PC increment)
        default:       muxed_srcB = 32'b0;
    endcase
end


// Result Src Mux

always @ * begin
    case (ResultSrc_i)
        ResultSrc_aluout:    Result = ALUout;  // ALU result
        ResultSrc_data:      Result = Data;   // Memory data
        ResultSrc_aluresult: Result = ALUResult;
        ResultSrc_lui:       Result = sign_extended_imm; // LUI immediate
        default:             Result = 32'b0;
    endcase
end

endmodule
