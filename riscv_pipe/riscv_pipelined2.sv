// riscvpipelined.sv

// RISC-V pipelined processor
// From Section 7.6 of Digital Design & Computer Architecture: RISC-V Edition
// 27 April 2020
// David_Harris@hmc.edu 
// Sarah.Harris@unlv.edu

// run 210
// Expect simulator to print "Simulation succeeded"
// when the value 25 (0x19) is written to address 100 (0x64)

// Pipelined implementation of RISC-V (RV32I)
// User-level Instruction Set Architecture V2.2 (May 7, 2017)
// Implements a subset of the base integer instructions:
//    lw, sw
//    add, sub, and, or, slt, 
//    addi, andi, ori, slti
//    beq
//    jal
// Exceptions, traps, and interrupts not implemented
// little-endian memory

// 31 32-bit registers x1-x31, x0 hardwired to 0
// R-Type instructions
//   add, sub, and, or, slt
//   INSTR rd, rs1, rs2
//   Instr[31:25] = funct7 (funct7b5 & opb5 = 1 for sub, 0 for others)
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// I-Type Instructions
//   lw, I-type ALU (addi, andi, ori, slti)
//   lw:         INSTR rd, imm(rs1)
//   I-type ALU: INSTR rd, rs1, imm (12-bit signed)
//   Instr[31:20] = imm[11:0]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// S-Type Instruction
//   sw rs2, imm(rs1) (store rs2 into address specified by rs1 + immm)
//   Instr[31:25] = imm[11:5] (offset[11:5])
//   Instr[24:20] = rs2 (src)
//   Instr[19:15] = rs1 (base)
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:0]  (offset[4:0])
//   Instr[6:0]   = opcode
// B-Type Instruction
//   beq rs1, rs2, imm (PCTarget = PC + (signed imm x 2))
//   Instr[31:25] = imm[12], imm[10:5]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:1], imm[11]
//   Instr[6:0]   = opcode
// J-Type Instruction
//   jal rd, imm  (signed imm is multiplied by 2 and added to PC, rd = PC+4)
//   Instr[31:12] = imm[20], imm[10:1], imm[11], imm[19:12]
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode

//   Instruction  opcode    funct3    funct7
//   add          0110011   000       0000000
//   sub          0110011   000       0100000
//   and          0110011   111       0000000
//   or           0110011   110       0000000
//   slt          0110011   010       0000000
//   addi         0010011   000       immediate
//   andi         0010011   111       immediate
//   ori          0010011   110       immediate
//   slti         0010011   010       immediate
//   beq          1100011   000       immediate
//   lw	          0000011   010       immediate
//   sw           0100011   010       immediate
//   jal          1101111   immediate immediate

module testbench();

   logic        clk;
   logic        reset;

   logic [31:0] WriteData, DataAdr;
   logic        MemWrite;
   logic        HaltReq;
   logic        ResumeReq;
   logic        DebugMode;
   logic 	DebugControl;   

   logic [31:0] RegIn;
   logic [31:0] RegOut;   
   logic [4:0] 	RegAddr;   
   logic 	DebugRegWrite;   

   // instantiate device to be tested
   top dut(clk, reset, WriteData, DataAdr, MemWrite, HaltReq, ResumeReq, 
	   DebugMode, DebugControl, RegIn, RegOut, RegAddr, DebugRegWrite);
	
   initial begin
      string memfilename;
      string dmemfilename;
      memfilename = {"../testing/testCSR3.memfile"};
      $readmemh(memfilename, dut.imem.RAM);
      $readmemh(memfilename, dut.dmem.RAM);	
   end
   
   // initialize test
   initial begin
      HaltReq = 0;
      ResumeReq = 0;
      DebugRegWrite = 1'b0;
      DebugControl = 1'b0;      
      reset <= 1; # 22; reset <= 0;       
   end
   
   // generate clock to sequence tests
   always begin
      clk <= 1; # 5; clk <= 0; # 5;
   end
   
   // check results
   always @(negedge clk)
      begin
	      if(MemWrite) begin
            if(DataAdr === 100 & WriteData === 10) begin
               $display("Simulation succeeded");
               $stop;
           end else if (DataAdr === 100 & WriteData === 17) begin
              $display("Simulation failed");
              $stop;
           end
	      end
      end
endmodule

module top(input logic         clk, reset, 
           output logic [31:0] WriteDataM, DataAdrM, 
           output logic        MemWriteM,
           input logic 	       HaltReq, ResumeReq,
           output logic        DebugMode,
           input logic 	       DebugControl,
           output logic [31:0] RegIn,
           input logic [31:0]  RegOut,
           input logic [4:0]   RegAddr,
           input logic 	       DebugRegWrite
);

   logic [31:0] 	       PCF, InstrF, ReadDataM;

   // instantiate processor and memories
   riscv rv32pipe(clk, reset, PCF, InstrF, MemWriteM, DataAdrM, 
		  WriteDataM, ReadDataM, HaltReq, ResumeReq, DebugMode, DebugControl,
		  RegIn, RegOut, RegAddr, DebugRegWrite);
   imem #("../testing/riscvtestCSR.memfile") imem(PCF, InstrF);
   dmem dmem(clk, MemWriteM, DataAdrM, WriteDataM, ReadDataM);
   
endmodule

module riscv(
   input logic 	       clk, 
   input logic 	       reset,
   output logic [31:0] PCF,
   input logic [31:0]  InstrF,
   output logic        MemWriteM,
   output logic [31:0] ALUResultM, WriteDataM,
   input logic [31:0]  ReadDataM,
   // Debug Stuff
   input logic         HaltReq,
   input logic         ResumeReq,
   output logic        DebugMode,
   input logic         DebugControl,
   output logic [31:0] RegIn,
   input logic [31:0]  RegOut,
   input logic [4:0]   RegAddr,
   input logic         DebugRegWrite
);

   logic [6:0] 			 opD;
   logic [2:0] 			 funct3D;
   logic 			 funct7b5D;
   logic [2:0] 			 ImmSrcD;
   logic [3:0]			 FlagsE;
   logic 			 PCSrcE;
   logic [3:0] 			 ALUControlE;
   logic 			 ALUSrcAE;   
   logic 			 ALUSrcBE;
   logic 			 PCTargetSrcE;   
   logic 			 ResultSrcEb0;
   logic 			 RegWriteM;
   logic [1:0] 			 ResultSrcW;
   logic 			 RegWriteW;
   logic [2:0] 			 LoadTypeM;
   logic [1:0] 			 StoreTypeM;   

   logic [1:0] 			 ForwardAE, ForwardBE;
   logic 			 StallF, StallD, FlushD, FlushE;

   logic 			 csr_weE;
   logic [11:0] 		 csr_addrE;
   logic [31:0] 		 csr_wdataE;
   logic [31:0] 		 csr_rdata;

   logic 			 CsrEnE;
   logic [1:0] 			 CsrOpE;
   logic 			 CsrImmE;

   logic [4:0] 			 Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;

   csr csr0(clk, reset, PCF, HaltReq, ResumeReq, DebugMode, 
	    csr_weE, csr_addrE, csr_wdataE, csr_rdata);
   
   controller c(clk, reset,
		opD, funct3D, funct7b5D, ImmSrcD,
		FlushE, FlagsE, PCSrcE, ALUControlE, ALUSrcAE, ALUSrcBE, PCTargetSrcE,
		ResultSrcEb0, MemWriteM, RegWriteM, 
		LoadTypeM, StoreTypeM, RegWriteW, ResultSrcW, CsrEnE, CsrOpE, CsrImmE);

   datapath dp(clk, reset,
               StallF, PCF, InstrF, opD, funct3D, funct7b5D, StallD, FlushD, ImmSrcD,
	       FlushE, ForwardAE, ForwardBE, PCSrcE, ALUControlE, 
	       ALUSrcAE, ALUSrcBE, PCTargetSrcE, FlagsE,
               MemWriteM, WriteDataM, ALUResultM, ReadDataM,
	       LoadTypeM, StoreTypeM, RegWriteW, ResultSrcW,
               Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
	       DebugControl, RegIn, RegOut, RegAddr, DebugRegWrite,
	       csr_weE, csr_addrE, csr_wdataE, csr_rdata,
	       CsrEnE, CsrOpE, CsrImmE);

   hazard  hu(Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
              PCSrcE, ResultSrcEb0, RegWriteM, RegWriteW,
              ForwardAE, ForwardBE, StallF, StallD, FlushD, FlushE, CsrEnE, DebugMode);
endmodule

module debugcsr(
   input logic 	      clk, 
   input logic 	      reset,
   input logic [31:0] PC,
   input logic 	      HaltReq,
   input logic 	      ResumeReq,
   output logic       DebugMode
);
   logic [31:0] dcsr;
   logic [31:0] dpc;
   logic [31:0] dscratch0;

   logic [2:0]  dcause;

   enum logic {RUNNING, HALTED} DebugState;

   always_ff @(posedge clk) begin
      if (reset) begin
         DebugState <= RUNNING;
      end else begin
         case(DebugState)
            RUNNING: if (HaltReq) DebugState <= HALTED;
            HALTED: if (ResumeReq) DebugState <= RUNNING;
            default: DebugState <= RUNNING;
         endcase
      end
   end

   // Needs to update cause when halting, not after halt.
   assign dcause = HaltReq ? 3'b011 : 3'b000;
   flopr #(32) dcsr_reg(clk, reset, {23'b0, dcause, 6'b0}, dcsr);
   assign DebugMode = (DebugState == HALTED);
endmodule

module controller(
   input logic 	      clk, reset,
   // Decode stage control signals
   input logic [6:0]  opD,
   input logic [2:0]  funct3D,
   input logic 	      funct7b5D,
   output logic [2:0] ImmSrcD,
   // Execute stage control signals
   input logic 	      FlushE, 
   input logic [3:0]  FlagsE, 
   output logic       PCSrcE, // for datapath and Hazard Unit
   output logic [3:0] ALUControlE,
   output logic       ALUSrcAE,
   output logic       ALUSrcBE,
   output logic       PCTargetSrcE,
   output logic       ResultSrcEb0, // for Hazard Unit
   // Memory stage control signals
   output logic       MemWriteM,
   output logic       RegWriteM, // for Hazard Unit
   output logic [2:0] LoadTypeM, 
   output logic [1:0] StoreTypeM,
   // Writeback stage control signals
   output logic       RegWriteW, // for datapath and Hazard Unit
   output logic [1:0] ResultSrcW,
   output logic       CsrEnE,
   output logic [1:0] CsrOpE,
   output logic       CsrImmE
);

   // pipelined control signals
   logic 			     RegWriteD;
   logic 			     RegWriteE;
   logic 			     RegWriteFinalD;   
   logic [1:0] 			     ResultSrcD, ResultSrcE, ResultSrcM;
   logic 			     MemWriteD, MemWriteE;
   logic 			     JumpD, JumpE;
   logic 			     BranchD, BranchE;
   logic 			     BranchTakenE;   
   logic [1:0] 			     ALUOpD;
   logic [3:0] 			     ALUControlD;
   logic 			     ALUSrcAD;   
   logic 			     ALUSrcBD;
   logic 			     PCTargetSrcD;   
   logic [2:0] 			     funct3E;
   logic [2:0] 			     LoadTypeE;
   logic [1:0] 			     StoreTypeE;
   
   logic 			     CsrEnD;
   logic 			     CsrImmD;
   logic [1:0] 			     CsrOpD;  
   
   // Decode stage logic
   maindec md(opD, ResultSrcD, MemWriteD, BranchD, ALUSrcAD, ALUSrcBD, 
	      PCTargetSrcD, RegWriteD, JumpD, ImmSrcD, ALUOpD);
   // ALU decoder
   aludec  ad(opD[5], funct3D, funct7b5D, ALUOpD, ALUControlD);
   // CSR decoder 
   csrdec  csrd(opD, funct3D, CsrEnD, CsrOpD, CsrImmD);
   
   // Execute stage pipeline control register and logic
   floprc #(20) controlregE(clk, reset, FlushE,
                            {RegWriteFinalD, ResultSrcD, MemWriteD, JumpD, BranchD, ALUControlD, ALUSrcAD, ALUSrcBD, PCTargetSrcD, funct3D, CsrEnD, CsrOpD, CsrImmD},
                            {RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, ALUControlE, ALUSrcAE, ALUSrcBE, PCTargetSrcE, funct3E, CsrEnE, CsrOpE, CsrImmE});

   bu branchunit (BranchE, FlagsE, funct3E, BranchTakenE);
   lsu lsu (funct3E, LoadTypeE, StoreTypeE);
   assign RegWriteFinalD = RegWriteD | CsrEnD;   
   assign PCSrcE = BranchTakenE | JumpE;  
   assign ResultSrcEb0 = ResultSrcE[0];
   
   // Memory stage pipeline control register
   flopr #(9) controlregM(clk, reset,
                          {RegWriteE, ResultSrcE, MemWriteE, LoadTypeE, StoreTypeE},
                          {RegWriteM, ResultSrcM, MemWriteM, LoadTypeM, StoreTypeM});
   
   // Writeback stage pipeline control register
   flopr #(3) controlregW(clk, reset,
                          {RegWriteM, ResultSrcM},
                          {RegWriteW, ResultSrcW});     
endmodule // controller

module bu (input logic       Branch,
	   input logic [3:0] Flags,
	   input logic [2:0] funct3,
	   output logic      taken);

   logic 		     v, c, n, z;
   logic 		     cond;
   
   assign {v, c, n, z} = Flags;
   assign taken = cond & Branch;
   always_comb
     case (funct3)
       3'b000: cond = z;         // beq
       3'b001: cond = ~z;        // bne
       3'b100: cond = (n ^ v);   // blt
       3'b101: cond = ~(n ^ v);  // bge 
       3'b110: cond = ~c;        // bltu
       3'b111: cond = c;         // bgeu
       default: cond = 1'b0;
     endcase // case (funct3)    

endmodule // bu

module maindec(input  logic [6:0] op,
               output logic [1:0] ResultSrc,
               output logic 	  MemWrite,
               output logic 	  Branch, ALUSrcA, ALUSrcB, PCTargetSrc,
               output logic 	  RegWrite, Jump,
               output logic [2:0] ImmSrc,
               output logic [1:0] ALUOp);

   logic [13:0] 		  controls;

   assign {RegWrite, ImmSrc, ALUSrcA, ALUSrcB, MemWrite,
           ResultSrc, Branch, ALUOp, Jump, PCTargetSrc} = controls;

   always_comb
     case(op)
       // RegWrite_ImmSrc_ALUSrcA_ALUSrcB_MemWrite_ResultSrc_Branch_ALUOp_Jump_PCTargetSrc
       7'b0000011: controls = 14'b1_000_0_1_0_01_0_00_0_x; // lw
       7'b0100011: controls = 14'b0_001_0_1_1_00_0_00_0_x; // sw
       7'b0110011: controls = 14'b1_xxx_0_0_0_00_0_10_0_x; // R-type 
       7'b1100011: controls = 14'b0_010_0_0_0_00_1_01_0_0; // beq
       7'b0010011: controls = 14'b1_000_0_1_0_00_0_10_0_x; // I-type ALU
       7'b1101111: controls = 14'b1_011_0_0_0_10_0_00_1_0; // jal
       7'b0110111: controls = 14'b1_100_1_1_0_00_0_00_0_x; // lui
       7'b0010111: controls = 14'b1_100_x_x_0_11_0_xx_0_0; // auipc       
       7'b1100111: controls = 14'b1_000_0_1_0_10_0_00_1_1; // jalr
       7'b1110011: controls = 14'b1_000_0_0_0_00_0_00_0_x; // csr
       7'b0000000: controls = 14'b0_000_0_0_0_00_0_00_0_0; // need valid values at reset
       default:    controls = 14'bx_xxx_x_x_x_xx_x_xx_x_x; // non-implemented instruction
     endcase
endmodule

module aludec(input  logic       opb5,
              input logic [2:0]  funct3,
              input logic 	 funct7b5, 
              input logic [1:0]  ALUOp,
              output logic [3:0] ALUControl);

   logic 			 RtypeSub;
   assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction

   always_comb
     case(ALUOp)
       2'b00: ALUControl = 4'b0000; // addition
       2'b01: ALUControl = 4'b0001; // subtraction
       default: case(funct3) // R–type or I–type ALU
		  3'b000: if (RtypeSub)
		    ALUControl = 4'b0001; // sub
		  else
		    ALUControl = 4'b0000; // add, addi
		  3'b001: ALUControl = 4'b0110; // sll, slli		  
		  3'b010: ALUControl = 4'b0101; // slt, slti
		  3'b011: ALUControl = 4'b1001; // sltu, sltiu
		  3'b100: ALUControl = 4'b0100; // xor, xori		  
		  3'b101: 
		    if (funct7b5)
		      ALUControl = 4'b1000;     // sra, srai
		    else
		      ALUControl = 4'b0111;     // srl, srli		    
		  3'b110: ALUControl = 4'b0011; // or, ori
		  3'b111: ALUControl = 4'b0010; // and, andi
		  default: ALUControl = 4'bxxxx; // ???
		endcase // case (funct3)       
     endcase // case (ALUOp)
endmodule // aludec

module lsu (input  logic [2:0] funct3,
	    output logic [2:0] LoadType,
	    output logic [1:0] StoreType);

   always_comb
     case(funct3)
       3'b000:     {LoadType, StoreType} = {3'b010, 2'b01}; // LB
       3'b001:     {LoadType, StoreType} = {3'b011, 2'b10}; // LH
       3'b010:     {LoadType, StoreType} = {3'b000, 2'b00}; // LW
       3'b101:     {LoadType, StoreType} = {3'b100, 2'bxx}; // LHU      
       3'b100:     {LoadType, StoreType} = {3'b001, 2'bxx}; // LBU
       default:    {LoadType, StoreType} = 5'bxxxxx;
     endcase // case (funct3)  

endmodule // lsu

module datapath(
   input logic 	       clk, reset,
   // Fetch stage signals
   input logic 	       StallF,
   output logic [31:0] PCF,
   input logic [31:0]  InstrF,
   // Decode stage signals
   output logic [6:0]  opD,
   output logic [2:0]  funct3D, 
   output logic        funct7b5D,
   input logic 	       StallD, FlushD,
   input logic [2:0]   ImmSrcD,
   // Execute stage signals
   input logic 	       FlushE,
   input logic [1:0]   ForwardAE, ForwardBE,
   input logic 	       PCSrcE,
   input logic [3:0]   ALUControlE,
   input logic 	       ALUSrcAE,
   input logic 	       ALUSrcBE,
   input logic 	       PCTargetSrcE,
   output logic [3:0]  FlagsE,
   // Memory stage signals
   input logic 	       MemWriteM, 
   output logic [31:0] WriteDataM, ALUResultM,
   input logic [31:0]  ReadDataM,
   input logic [2:0]   LoadTypeM,
   input logic [1:0]   StoreTypeM,
   // Writeback stage signals
   input logic 	       RegWriteW, 
   input logic [1:0]   ResultSrcW,
   // Hazard Unit signals 
   output logic [4:0]  Rs1D, Rs2D, Rs1E, Rs2E,
   output logic [4:0]  RdE, RdM, RdW,
   input logic 	       DebugControl,
   output logic [31:0] RegIn,
   input logic [31:0]  RegOut,
   input logic [4:0]   RegAddr,
   input logic 	       DebugRegWrite,
   // CSR handshake with csr
   output logic        csr_weE,
   output logic [11:0] CSRAddrE,
   output logic [31:0] csr_wdataE,
   input logic [31:0]  csr_rdata,
   // csr control from controller
   input logic 	       CsrEnE,
   input logic [1:0]   CsrOpE,
   input logic 	       CsrImmE		
);
   
   // Fetch stage signals
   logic [31:0] 		    PCNextF, PCPlus4F;
   // Decode stage signals
   logic [31:0] 		    InstrD;
   logic [31:0] 		    PCD, PCPlus4D;
   logic [31:0] 		    RD1D, RD2D;
   logic [31:0] 		    ImmExtD;
   logic [4:0] 			    RdD;
   logic [11:0] 		    CSRAddrD;
   logic [4:0] 			    ZimmD;
   // Execute stage signals
   logic [31:0] 		    RD1E, RD2E;
   logic [31:0] 		    PCE, ImmExtE;
   logic [31:0] 		    SrcAE, SrcBE;
   logic [31:0] 		    SrcAEforward;   
   logic [31:0] 		    ALUResultE;
   logic [31:0] 		    WriteDataE;
   logic [31:0] 		    PCPlus4E;
   logic [31:0] 		    PCTargetE;
   logic [31:0] 		    PCRelativeTargetE;
   logic [31:0] 		    csr_srcE;
   logic [31:0] 		    csr_oldE;
   logic [31:0] 		    csr_newE;
   logic 			    csr_writeE;
   logic 			    UseCSRResultE;
   logic [31:0] 		    CSRReadE;
   logic [4:0] 			    ZimmE;   
   // Memory stage signals
   logic [31:0] 		    PCPlus4M;
   logic [31:0] 		    PCTargetM;
   logic [7:0] 			    byteoutM;
   logic [15:0] 		    halfwordoutM;
   logic [31:0] 		    ZeroExtendByteM;
   logic [31:0] 		    SignExtendByteM;
   logic [31:0] 		    SignExtendWordM;
   logic [31:0] 		    ZeroExtendWordM;   
   logic [31:0] 		    WriteDataPreM;
   logic [31:0] 		    ReadDataMuxM;
   logic 			    UseCSRResultM;
   logic [31:0] 		    CSRReadM;   
   // Writeback stage signals
   logic [31:0] 		    ALUResultW;
   logic [31:0] 		    ReadDataW;
   logic [31:0] 		    PCPlus4W;
   logic [31:0] 		    ResultW2;
   logic [31:0] 		    ResultW;
   logic [31:0] 		    PCTargetW;
   logic 			    UseCSRResultW;
   logic [31:0] 		    CSRReadW;
   logic [31:0] 		    ResultFinalW2;   

   logic [4:0] 			    Rs1, Rs2;

   // Fetch stage pipeline register and logic
   mux2    #(32)  pcmux(PCPlus4F, PCTargetE, PCSrcE, PCNextF);
   flopenr #(32)  pcreg(clk, reset, ~StallF, PCNextF, PCF);
   adder          pcadd(PCF, 32'h4, PCPlus4F);

   // Decode stage pipeline register and logic
   flopenrc #(96) regD(clk, reset, FlushD, ~StallD, 
                       {InstrF, PCF, PCPlus4F},
                       {InstrD, PCD, PCPlus4D});
   assign opD       = InstrD[6:0];
   assign funct3D   = InstrD[14:12];
   assign funct7b5D = InstrD[30];
   assign Rs1       = InstrD[19:15];
   assign Rs2D      = InstrD[24:20];
   assign RdD       = InstrD[11:7];
   assign CSRAddrD  = InstrD[31:20];
   assign ZimmD     = InstrD[19:15];   

   // Mux to tie in input from Debug
   mux2 #(5)      rs1mux(Rs1, RegAddr, DebugControl, Rs1D);
   regfile        rf(clk, RegWriteW | DebugRegWrite, Rs1D, Rs2D, RdW, ResultW, RD1D, RD2D);
   extend         ext(InstrD[31:7], ImmSrcD, ImmExtD);

   assign RegIn = RD1D;

   // Execute stage pipeline register and logic
   floprc #(192) regE(clk, reset, FlushE, 
                      {RD1D, RD2D, PCD, Rs1D, Rs2D, RdD, ImmExtD, PCPlus4D, CSRAddrD, ZimmD}, 
                      {RD1E, RD2E, PCE, Rs1E, Rs2E, RdE, ImmExtE, PCPlus4E, CSRAddrE, ZimmE});

   mux3   #(32)  faemux(RD1E, ResultW, ALUResultM, ForwardAE, SrcAEforward);
   mux3   #(32)  fbemux(RD2E, ResultW, ALUResultM, ForwardBE, WriteDataE);
   mux2   #(32)  srcamux(SrcAEforward, 32'h0, ALUSrcAE, SrcAE);   
   mux2   #(32)  srcbmux(WriteDataE, ImmExtE, ALUSrcBE, SrcBE);
   alu           alu(SrcAE, SrcBE, ALUControlE, ALUResultE, FlagsE);
   adder         branchadd(ImmExtE, PCE, PCRelativeTargetE);
   mux2 #(32)    jalrmux (PCRelativeTargetE, ALUResultE, PCTargetSrcE, PCTargetE);

   // ---- CSR operation (Execute) ----
   assign csr_srcE = CsrImmE ? {27'b0, ZimmE} : SrcAEforward;
   assign csr_oldE = csr_rdata;

  // Compute new CSR value per the op
  always_comb begin
     case (CsrOpE)
      2'b01: csr_newE = csr_srcE;                 // CSRRW
      2'b10: csr_newE = csr_oldE | csr_srcE;      // CSRRS
      2'b11: csr_newE = csr_oldE & ~csr_srcE;     // CSRRC
      default: csr_newE = csr_oldE;
    endcase
  end
   
   // Per spec: CSRRS/CSRRC do not write if src==0
   assign csr_writeE = CsrEnE && ( (CsrOpE == 2'b01) || (csr_srcE != 32'b0) );

   // Drive the external CSR
   assign csr_weE = csr_writeE;
   assign csr_wdataE = csr_newE;
   assign UseCSRResultE = CsrEnE;
   assign CSRReadE      = csr_oldE;

   // CSR pipe
   flopr #(33) csr_pipe_M (clk, reset, {UseCSRResultE, CSRReadE}, {UseCSRResultM, CSRReadM});
   flopr #(33) csr_pipe_W (clk, reset, {UseCSRResultM, CSRReadM}, {UseCSRResultW, CSRReadW});

   // Memory stage pipeline register
   flopr  #(133) regM(clk, reset, 
                      {ALUResultE, WriteDataE, RdE, PCPlus4E, PCTargetE},
                      {ALUResultM, WriteDataPreM, RdM, PCPlus4M, PCTargetM});

   mux4 #(8) bytesel (ReadDataM[7:0], ReadDataM[15:8], ReadDataM[23:16], ReadDataM[31:24],
            ALUResultM[1:0], byteoutM);
   mux2 #(16) wordsel (ReadDataM[15:0], ReadDataM[31:16], ALUResultM[1], halfwordoutM);   
   zeroextend #(8) zeb (byteoutM, ZeroExtendByteM);
   signextend #(8) seb (byteoutM, SignExtendByteM);
   zeroextend #(16) zew (halfwordoutM, ZeroExtendWordM);   
   signextend #(16) sew (halfwordoutM, SignExtendWordM);   
   mux5 #(32) readdatamux (ReadDataM, ZeroExtendByteM, SignExtendByteM, 
            SignExtendWordM, ZeroExtendWordM, 
            LoadTypeM, ReadDataMuxM);  
   wdunit wdu (WriteDataPreM, ReadDataM, StoreTypeM, ALUResultM[1:0], WriteDataM); 

   // Writeback stage pipeline register and logic
   flopr  #(133) regW(clk, reset, 
                      {ALUResultM, ReadDataMuxM, RdM, PCPlus4M, PCTargetM},
                      {ALUResultW, ReadDataW, RdW, PCPlus4W, PCTargetW});
   mux4   #(32)  resultmux(ALUResultW, ReadDataW, PCPlus4W, PCTargetW, ResultSrcW, ResultW2);
   // If this is a CSR instruction, rd gets the OLD CSR value
   mux2 #(32) csrsel(ResultW2, CSRReadW, UseCSRResultW, ResultFinalW2);
   mux2 #(32) debugwritemux(ResultFinalW2, RegOut, DebugControl, ResultW);   
endmodule

// HazardUnit: forward, stall, and flush
module hazard(input  logic [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
              input logic 	 PCSrcE, ResultSrcEb0, 
              input logic 	 RegWriteM, RegWriteW,
              output logic [1:0] ForwardAE, ForwardBE,
              output logic 	 StallF, StallD, FlushD, FlushE,
	      input logic 	 UseCSRResultE,
              input logic 	 DebugMode
  );

   logic 			 lwStallD;
   logic 			 csrStallD;   

   // forwarding logic
   always_comb begin
      ForwardAE = 2'b00;
      ForwardBE = 2'b00;
      if (Rs1E != 5'b0)
         if      ((Rs1E == RdM) & RegWriteM) ForwardAE = 2'b10;
         else if ((Rs1E == RdW) & RegWriteW) ForwardAE = 2'b01;

      if (Rs2E != 5'b0)
         if      ((Rs2E == RdM) & RegWriteM) ForwardBE = 2'b10;
         else if ((Rs2E == RdW) & RegWriteW) ForwardBE = 2'b01;
   end
   
   // stalls and flushes
   assign lwStallD = ResultSrcEb0 & ((Rs1D == RdE) | (Rs2D == RdE));
   assign csrStallD = UseCSRResultE & (RdE != 5'd0) &
                      ((Rs1D == RdE) | (Rs2D == RdE));  
   assign StallD = lwStallD | csrStallD | DebugMode;
   assign StallF = lwStallD | csrStallD | DebugMode;

   assign FlushD = PCSrcE;
   assign FlushE = lwStallD | csrStallD | PCSrcE;
endmodule

module regfile(input  logic        clk, 
               input logic 	   we3, 
               input logic [ 4:0]  a1, a2, a3, 
               input logic [31:0]  wd3, 
               output logic [31:0] rd1, rd2);

   logic [31:0] 		   rf[31:0];

   // three ported register file
   // read two ports combinationally (A1/RD1, A2/RD2)
   // write third port on rising edge of clock (A3/WD3/WE3)
   // write occurs on falling edge of clock
   // register 0 hardwired to 0

   always_ff @(negedge clk)
      if (we3) rf[a3] <= wd3;	

   assign rd1 = (a1 != 0) ? rf[a1] : 0;
   assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule

module adder(input  [31:0] a, b,
             output [31:0] y);

   assign y = a + b;
endmodule

module extend(input  logic [31:7] instr,
              input logic [2:0]   immsrc,
              output logic [31:0] immext);

   always_comb
     case(immsrc) 
       // I-type 
       3'b000:   immext = {{20{instr[31]}}, instr[31:20]};  
       // S-type (stores)
       3'b001:   immext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
       // B-type (branches)
       3'b010:   immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
       // J-type (jal)
       3'b011:   immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
       // U−type (lui/auipc) 
       3'b100:  immext = {instr[31:12], 12'h0};  
       default: immext = 32'bx; // undefined
     endcase             
endmodule

module flopr #(parameter WIDTH = 8)
   (input  logic             clk, reset,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset) q <= 0;
     else       q <= d;
endmodule

module flopenr #(parameter WIDTH = 8)
   (input  logic             clk, reset, en,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= 0;
     else if (en) q <= d;
endmodule // flopenr

module flopenrc #(parameter WIDTH = 8)
   (input  logic             clk, reset, clear, en,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= 0;
     else if (en) 
       if (clear) q <= 0;
       else       q <= d;
endmodule 

module csr_reg_en #(parameter WIDTH = 32, ADDR = 12)
   (input logic              clk,
    input logic 	     reset,
    input logic [ADDR-1:0]   address,
    input logic 	     csr_we,
    input logic [ADDR-1:0]   csr_addr,
    input logic [WIDTH-1:0]  d_in,
    output logic [WIDTH-1:0] q);

  logic           en;

  assign en = csr_we & (csr_addr == address);
  flopenr #(WIDTH) u_reg (clk, reset, en, d_in, q);
endmodule // csr_reg_en

module misa_reg_en #(parameter WIDTH = 32, ADDR = 12)
   (input  logic             clk,
    input logic 	     reset,
    input logic [ADDR-1:0]   address, 
    input logic 	     csr_we,
    input logic [ADDR-1:0]   csr_addr, 
    input logic [WIDTH-1:0]  d_in,
    output logic [WIDTH-1:0] q);

   logic 		     en;
   // misa default: RV32I => MXL=01 in [31:30], 'I' bit (bit 8) set, others 0.
   logic [31:0] 	     MISA_RV32I = (32'h1 << 30) | (32'h1 << 8);

   assign en = csr_we & (csr_addr == address);
   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= MISA_RV32I;
     else if (en) q <= d_in;
endmodule // misa_reg_en

module floprc #(parameter WIDTH = 8)
   (input  logic clk,
    input logic 	     reset,
    input logic 	     clear,
    input logic [WIDTH-1:0]  d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset) q <= 0;
     else       
       if (clear) q <= 0;
       else       q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, 
    input logic 	     s, 
    output logic [WIDTH-1:0] y);

   assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, d2,
    input logic [1:0] 	     s, 
    output logic [WIDTH-1:0] y);

   assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule // mux3

module mux4 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s, 
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0); 

endmodule // mux4

module mux5 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4,
  input  logic [2:0]       s, 
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? d4 : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0)); 
endmodule

module imem #(parameter MEM_INIT_FILE)
    (input  logic [31:0] a,
     output logic [31:0] rd);
   
   logic [31:0]      RAM[63:0];

   initial begin
      if (MEM_INIT_FILE != "") begin
        $readmemh(MEM_INIT_FILE, RAM);
      end
   end
   
   assign rd = RAM[a[31:2]]; // word aligned
   
endmodule // imem

module dmem (input  logic        clk, we,
	     input  logic [31:0] a, wd,
	     output logic [31:0] rd);
   
   logic [31:0] 		 RAM[8191:0];
   
   assign rd = RAM[a[31:2]]; // word aligned
   always_ff @(posedge clk)
     if (we) RAM[a[31:2]] <= wd;
   
endmodule // dmem

module alu(input  logic [31:0] a, b,
           input logic [3:0]   alucontrol,
           output logic [31:0] result,
           output logic [3:0]  flags);

   logic [31:0] 	       condinvb, sum;
   logic 		       v, c, n, z;
   logic 		       Asign, Bsign;
   logic 		       Neg;   
   logic 		       LT, LTU; 
   logic 		       cout;   
   logic 		       isAddSub;       // true when is add or sub

   assign flags = {v, c, n, z};   
   assign condinvb = alucontrol[0] ? ~b : b;
   assign {cout, sum} = a + condinvb + alucontrol[0];
   assign isAddSub = (~alucontrol[3] & ~alucontrol[2] & ~alucontrol[1]) |
                     (~alucontrol[3] & ~alucontrol[1] & alucontrol[0]);
   assign Asign = a[31];
   assign Bsign = b[31];
   assign Neg  = sum[31];   
   assign LT = Asign & ~Bsign | Asign & Neg | ~Bsign & Neg; 
   assign LTU = ~cout;  

   always_comb
     case (alucontrol)
       4'b0000:  result = sum;                  // add
       4'b0001:  result = sum;                  // subtract
       4'b0010:  result = a & b;                // and
       4'b0011:  result = a | b;                // or
       4'b0100:  result = a ^ b;                // xor
       4'b0101:  result = {{31{1'b0}}, LT};     // slt
       4'b1001:  result = {{31{1'b0}}, LTU};    // sltu 
       4'b0110:  result = a << b[4:0];          // sll
       4'b0111:  result = a >> b[4:0];          // srl
       4'b1000: result = $signed(a) >>> b[4:0]; // sra        
       default: result = 32'bx;
     endcase // case (alucontrol)

   assign z = (result == 32'b0);
   assign n = result[31];
   assign c = cout & isAddSub;   
   assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
   
endmodule // alu

module zeroextend #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] a,
    output logic [31:0] zeroimmext);

   assign zeroimmext = {{{32-WIDTH}{1'b0}}, a};

endmodule // zeroextend

module signextend #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0]  a,
    output logic [31:0] signext);

   assign signext = {{{32-WIDTH}{a[WIDTH-1]}}, a};

endmodule // signextend

module wdunit (input  logic [31:0] rd2, 
	       input  logic [31:0] readdata,
	       input  logic [1:0]  StoreType,
	       input  logic [1:0]  byteoffset,
	       output logic [31:0] WriteData);
   
   logic [31:0] 		   storeb0;
   logic [31:0] 		   storeb1;
   logic [31:0] 		   storeb2;
   logic [31:0] 		   storeb3;
   logic [31:0] 		   storeh0;
   logic [31:0] 		   storeh1;   
   logic [31:0] 		   sbword;
   logic [31:0] 		   shword;

   assign storeb0 = {readdata[31:8], rd2[7:0]};
   assign storeb1 = {readdata[31:16], rd2[7:0], readdata[7:0]};
   assign storeb2 = {readdata[31:24], rd2[7:0], readdata[15:0]};
   assign storeb3 = {rd2[7:0], readdata[31:8]};

   assign storeh0 = {readdata[31:16], rd2[15:0]};
   assign storeh1 = {rd2[15:0], readdata[31:16]};

   mux4 #(32) sbmux (storeb0, storeb1, storeb2, storeb3, byteoffset, sbword);
   mux2 #(32) shmux (storeh0, storeh1, byteoffset[1], shword);   
   mux3 #(32) wdmux (rd2, sbword, shword, StoreType, WriteData);     
   
endmodule // wdunit

module csr(
        input logic 	    clk,
	input logic 	    reset,
   
	// PC for capturing into dpc on entry to debug
	input logic [31:0]  PC,
   
	// External debug requests
	input logic 	    HaltReq,
	input logic 	    ResumeReq,
	output logic 	    DebugMode,
   
	// Pipeline CSR access (E stage)
	input logic 	    csr_we, // write enable for CSR (after RS/RC zero-mask checks)
	input logic [11:0]  csr_addr, // CSR address from instruction
	input logic [31:0]  csr_wdata, // new value to write
	output logic [31:0] csr_rdata // old/current value (combinational)
);
   
   // ----------------------------
   // Debug state machine
   // ----------------------------
   typedef enum 	       logic {RUNNING, HALTED} dbg_state_e;
   dbg_state_e state, state_n;
   
   // Debug CSRs
   logic [31:0] 	       dcsr;       // 0x7B0
   logic [31:0] 	       dpc;        // 0x7B1
   logic [31:0] 	       dscratch0;  // 0x7B2
   
   // Machine CSRs (basic, WARL/WIRI behavior ignored for simplicity)
   logic [31:0] 	       mstatus;    // 0x300
   logic [31:0] 	       misa;       // 0x301
   logic [31:0] 	       mtvec;      // 0x305
   logic [31:0] 	       mepc;       // 0x341
   logic [31:0] 	       mcause;     // 0x342
   logic [31:0] 	       mtval;      // 0x343

   // ----------------------------
   // Debug Mode FSM
   // ----------------------------     
   // Debug cause (3 = halt request)
   logic [2:0] 		       dcause;
   
   assign dcause = (HaltReq) ? 3'd3 : 3'd0;

   // State Machine flop
   always_ff @(posedge clk) begin
      if (reset) begin
         state <= RUNNING;
      end else if (HaltReq | ResumeReq) begin // Using the requests as enables
         state <= state_n;
      end
   end
   
   // Next-state debug mode
   always_comb begin
      // state_n = state;
      unique case (state)
	      RUNNING: if (HaltReq) state_n = HALTED;
	      HALTED:  if (ResumeReq) state_n = RUNNING;
         default: state_n = RUNNING;
      endcase
   end
   
   assign DebugMode = (state == HALTED);
   
   // ----------------------------
   // CSR read mux (combinational)
   // ----------------------------
   always_comb begin
      case (csr_addr)
	12'h300: csr_rdata = mstatus;
	12'h301: csr_rdata = misa;
	12'h305: csr_rdata = mtvec;
	12'h341: csr_rdata = mepc;
	12'h342: csr_rdata = mcause;
	12'h343: csr_rdata = mtval;
	12'h7B0: csr_rdata = dcsr;
	12'h7B1: csr_rdata = dpc;
	12'h7B2: csr_rdata = dscratch0;
	default: csr_rdata = 32'h0000_0000; 
      endcase
   end
   
   // misa default: RV32I => MXL=01 in [31:30], 'I' bit (bit 8) set, others 0.
   localparam [31:0] MISA_RV32I = (32'h1 << 30) | (32'h1 << 8);

   csr_reg_en #(32, 12) mstatus_reg(clk, reset, 12'h300, csr_we, csr_addr, csr_wdata, mstatus);
   csr_reg_en #(32, 12) mtvec_reg(clk, reset, 12'h305, csr_we, csr_addr, csr_wdata, mtvec);
   csr_reg_en #(32, 12) mepc_reg(clk, reset, 12'h341, csr_we, csr_addr, csr_wdata, mepc);
   csr_reg_en #(32, 12) mcause_reg(clk, reset, 12'h342, csr_we, csr_addr, csr_wdata, mcause);
   csr_reg_en #(32, 12) mtval_reg(clk, reset, 12'h343, csr_we, csr_addr, csr_wdata, mtval);
   csr_reg_en #(32, 12) dscratch0_reg(clk, reset, 12'h7b2, csr_we, csr_addr, csr_wdata, dscratch0);
   misa_reg_en #(32, 12) misa_reg(clk, reset, 12'h301, csr_we, csr_addr, csr_wdata, misa);
   
   /// FIXME:  have to implement correctly as a FSM :(
   // ----------------------------
   // Debug Registers
   // ----------------------------


   // DPC
   always_ff @(posedge clk) begin
      if (reset) begin
         dpc <= '0;
      end else if (state == RUNNING && state_n == HALTED) begin
         dpc <= PC; // needs address of next instruction on halt. PC can vary by cause
      end else if (csr_we & csr_addr == 12'h7B1) begin
         dpc <= csr_wdata;
      end
   end
   
   // On entry to debug: latch PC into dpc and set dcsr.cause
   always_ff @(posedge clk) begin
      if (reset) begin
                        // | Name      | Access | Status          | Description                                                                  |
                        // |-----------+--------+-----------------+------------------------------------------------------------------------------|
         dcsr <= {4'd4, // | debugver  | R      | implemented     | Debug Version                                                                |
                  1'b0, // | reserved  | -      | -               |                                                                              |
                  3'd0, // | extcause  | R      | optional=0      | Reserved for extra debug causes when dcause=other                            |
                  4'd0, // | reserved  | -      | -               |                                                                              |
                  1'b0, // | cetrig    | WARL   | unimplemented=0 | Optional Smdbltrp extension                                                  |
                  1'b0, // | pelp      | WARL   | unimplemented=0 | Zicfilp extension                                                            |
                  1'b0, // | ebreakvs  | WARL   | unimplemented=0 | VS-mode debug ebreak                                                         |
                  1'b0, // | ebreakvu  | WARL   | unimplmeneted=0 | VU-mode debug ebreak                                                         |
                  1'b0, // | ebreakm   | R/W    | mandatory       | M-mode debug ebreak                                                          |
                  1'b0, // | reserved  | -      | -               | -                                                                            |
                  1'b0, // | ebreaks   | WARL   | unimplemented=0 | S-mode debug ebreak                                                          |
                  1'b0, // | ebreaku   | WARL   | unimplemented=0 | U-mode debug ebreak                                                          |
                  1'b0, // | stepie    | WARL   | unimplemented=0 | Interrupt enable during single stepping.                                     |
                  1'b0, // | stopcount | WARL   | continue=0      | Increment or freeze counters in debug mode (e.g.cycle)                       |
                  1'b0, // | stoptime  | WARL   | continue=0      | Increment or freeze mtime                                                    |
                  3'd0, // | cause     | R      | mandatory       | Explains why debug mode was entered                                          |
                  1'b0, // | v         | WARL   | unimplemented=0 | Extends the prv field with virtualization enabled                            |
                  1'b0, // | mprven    | WARL   | unimplemented=0 | 0 means mprv in mstatus is ignored in Debug Mode                             |
                  1'b0, // | nmip      | R      | unimplemented=0 | Set = non-maskable interrupt. Implementation dependent                       |
                  1'b0, // | step      | R/W    | mandatory       | Execute single instruction, re-enter debug mode. Debugger sets in Debug mode |
                  2'd3  // | prv       | WARL   | reset=3         | Privileged mode when debug mode was entered                                  |
         };
      end else if (state == RUNNING && state_n == HALTED) begin // Debug Mode
         // dcsr[8:6] = cause (simplified placement into bits[8:6])
         dcsr <= { dcsr[31:9], dcause, dcsr[5:0] };
      end else if (csr_we & csr_addr == 12'h7B0) begin
         dcsr <= {4'd4, 12'd0, csr_wdata[15], 6'd0, dcause, 3'd0, csr_wdata[2], dcsr[1:0]};
      end 
   end
endmodule // csr

module csrdec(input logic [6:0]  op, // Instr[6:0]
	      input logic [2:0]  funct3, // Instr[14:12]
	      output logic 	 CsrEn, // instruction is CSRR*
	      output logic [1:0] CsrOp, // 01=RW, 10=RS, 11=RC
	      output logic 	 CsrImm    // 1: immediate (zimm), 0: rs1
	      );
   
   // SYSTEM opcode = 0x73 = 7'b1110011
   logic 			 is_system;
   
   assign is_system = (op == 7'b1110011);

   always_comb begin
      CsrEn  = 1'b0;
      CsrOp  = 2'b00;
      CsrImm = 1'b0;
      if (is_system && (funct3 != 3'b000)) begin
	 CsrEn  = 1'b1;
	 CsrImm = funct3[2];
	 unique case (funct3[1:0]) // lower 2 bits decide op
           2'b01: CsrOp = 2'b01; // CSRRW / CSRRWI
           2'b10: CsrOp = 2'b10; // CSRRS / CSRRSI
           2'b11: CsrOp = 2'b11; // CSRRC / CSRRCI
           default: CsrOp = 2'b00;
	 endcase
      end
   end
endmodule 
