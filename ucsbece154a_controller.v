// ucsbece154a_controller.v
// All Rights Reserved
// Copyright (c) 2023 UCSB ECE
// Distribution Prohibited

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// TO DO: Replace all `z` values with the correct values  
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module ucsbece154a_controller (
    input               clk, reset,
    input         [6:0] op_i, 
    input         [2:0] funct3_i,
    input               funct7_i,
    input 	        zero_i,
    output wire         PCWrite_o,
    output reg          MemWrite_o,    
    output reg          IRWrite_o,
    output reg          RegWrite_o,
    output reg    [1:0] ALUSrcA_o,
    output reg          AdrSrc_o,
    output reg    [1:0] ResultSrc_o,
    output reg    [1:0] ALUSrcB_o,
    output reg    [2:0] ALUControl_o,
    output reg    [2:0] ImmSrc_o
);


 `include "ucsbece154a_defines.vh"


// **********   Extend unit    *********
 always @ * begin
   case (op_i)
    instr_lw_op:        ImmSrc_o = 3'b000;       
    instr_sw_op:        ImmSrc_o = 3'b001; 
    instr_Rtype_op:     ImmSrc_o = 3'bxxx;  
    instr_beq_op:       ImmSrc_o = 3'b010;  
    instr_ItypeALU_op:  ImmSrc_o = 3'b000; 
    instr_jal_op:       ImmSrc_o = 3'b011; 
    instr_lui_op:       ImmSrc_o = 3'b100;  
    default: 	    ImmSrc_o = 3'b000; 
   endcase
 end


// **********  ALU Control  *********
 reg  [1:0] ALUOp;    // these are FFs updated each cycle 
 wire RtypeSub = funct7_i & op_i[5];

 always @ * begin
    case (ALUOp)
      ALUop_mem:    ALUControl_o = ALUcontrol_add;  // Load/Store uses ADD
      ALUop_beq:    ALUControl_o = ALUcontrol_sub;  // Branch uses SUB
      ALUop_other:  // R-type or I-type ALU instructions
          case (funct3_i)
              instr_addsub_funct3: ALUControl_o = (RtypeSub) ? ALUcontrol_sub : ALUcontrol_add;
              instr_slt_funct3:    ALUControl_o = ALUcontrol_slt;
              instr_or_funct3:     ALUControl_o = ALUcontrol_or;
              instr_and_funct3:    ALUControl_o = ALUcontrol_and;
              default:             ALUControl_o = ALUcontrol_add;
          endcase
      default:       ALUControl_o = ALUcontrol_add;
    endcase
 end



// **********  Generating PC Write  *********
 reg Branch, PCUpdate;   // these are FFs updated each cycle 

 assign PCWrite_o = Branch & zero_i | PCUpdate; 


// ******************************************
// *********  Main FSM  *********************
// ******************************************


// *********  FSM state transistion  ****** 
 reg [3:0] state; //  FSM FFs encoding the state 
 reg [3:0] state_next;

 always @ * begin
    if (reset) begin
                               state_next = 4'b0000;  
    end else begin             
      case (state) 
        state_Fetch:           state_next = 4'b0001;  
        state_Decode: begin
          case (op_i) 
            instr_lw_op:       state_next = 4'b0010;  
            instr_sw_op:       state_next = 4'b0010;  
            instr_Rtype_op:    state_next = 4'b0110;  
            instr_beq_op:      state_next = 4'b1010;  
            instr_ItypeALU_op: state_next = 4'b1000;  
            instr_lui_op:      state_next = 4'b1011;  
            instr_jal_op:      state_next = 4'b1001;  
            default:           state_next = 4'bxxxx;
          endcase
        end
        state_MemAdr: begin 
          case (op_i)
            instr_lw_op:       state_next = 4'b0011;  
            instr_sw_op:       state_next = 4'b0101;  
            default:           state_next = 4'bxxxx;
          endcase
        end
        state_MemRead:         state_next = 4'b0100;  
        state_MemWB:           state_next = 4'b0000;  
        state_MemWrite:        state_next = 4'b0000;  
        state_ExecuteR:        state_next = 4'b0111;  
        state_ALUWB:           state_next = 4'b0000;  
        state_ExecuteI:        state_next = 4'b0111;  
        state_JAL:             state_next = 4'b0111;  
        state_BEQ:             state_next = 4'b0000;  
        state_LUI:             state_next = 4'b0000; // lui needs to regwrite    - test skip step 
        default:               state_next = 4'bxxxx;
     endcase
   end
 end

// *******  Control signal generation  ********

 reg [13:0] controls_next;
 wire       PCUpdate_next, Branch_next, MemWrite_next, IRWrite_next, RegWrite_next, AdrSrc_next;
 wire [1:0] ALUSrcA_next, ALUSrcB_next, ResultSrc_next, ALUOp_next;

 assign {
	PCUpdate_next, Branch_next, MemWrite_next, IRWrite_next, RegWrite_next,
        ALUSrcA_next, ALUSrcB_next, AdrSrc_next, ResultSrc_next, ALUOp_next
	} = controls_next;

 always @ * begin
   case (state_next)
      state_Fetch:    controls_next = {1'b1, 1'b0, 1'b0, 1'b1, 1'b0, ALUSrcA_pc,      ALUSrcB_4,      1'b0, ResultSrc_aluresult,  ALUop_mem};      
        state_Decode:   controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALUSrcA_oldpc,   ALUSrcB_imm,    1'b0, 2'b00,                ALUop_mem};       
        state_MemAdr:   controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALUSrcA_reg,     ALUSrcB_imm,    1'b0, 2'b00,                ALUop_mem};      
        state_MemRead:  controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00,           2'b00,          1'b1, ResultSrc_aluout,     2'b00};        
        state_MemWB:    controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00,           2'b00,          1'b0, ResultSrc_data,       2'b00};       
        state_MemWrite: controls_next = {1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00,           2'b00,          1'b1, ResultSrc_aluout,     2'b00};       
        state_ExecuteR: controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALUSrcA_reg,     ALUSrcB_reg,    1'b0, 2'b00,                ALUop_other};       
        state_ALUWB:    controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00,           2'b00,          1'b0, ResultSrc_aluout,     2'b00};           
        state_ExecuteI: controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALUSrcA_reg,     ALUSrcB_imm,    1'b0, 2'b00,                ALUop_other};         
        state_JAL:      controls_next = {1'b1, 1'b0, 1'b0, 1'b0, 1'b0, ALUSrcA_oldpc,   ALUSrcB_4,      1'b0, ResultSrc_aluout,     ALUop_mem};       
        state_BEQ:      controls_next = {1'b0, 1'b1, 1'b0, 1'b0, 1'b0, ALUSrcA_reg,     ALUSrcB_reg,    1'b0, ResultSrc_aluout,     ALUop_beq};       
        state_LUI:      controls_next = {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00,           2'b00,          1'b0, ResultSrc_lui,        2'b00};       
		default:        controls_next = 14'bx_x_x_x_x_xx_xx_x_xx_xx;
   endcase
 end

 // *******  Updating control and main FSM FFs  ********
 always @(posedge clk) begin
    state <= state_next;
    PCUpdate <= PCUpdate_next;
    Branch <= Branch_next;
    MemWrite_o <= MemWrite_next;
    IRWrite_o <= IRWrite_next;
    RegWrite_o <= RegWrite_next;
    ALUSrcA_o <= ALUSrcA_next;
    ALUSrcB_o <= ALUSrcB_next;
    AdrSrc_o <= AdrSrc_next;
    ResultSrc_o <= ResultSrc_next;
    ALUOp <= ALUOp_next;
  end


endmodule

