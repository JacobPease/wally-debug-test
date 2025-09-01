// ============================================================
// Testbench
// ============================================================
module testbench();

   logic        clk;
   logic        reset;

   logic [31:0] WriteData, DataAdr;
   logic        MemWrite;
   logic        HaltReq;
   logic        ResumeReq;
   logic        DebugMode;
   logic        DebugControl;   

   logic [31:0] RegIn;
   logic [31:0] RegOut;   
   logic [4:0]  RegAddr;   
   logic        DebugRegWrite;   

   // instantiate device to be tested
   top dut(clk, reset, WriteData, DataAdr, MemWrite, HaltReq, ResumeReq, 
           DebugMode, DebugControl, RegIn, RegOut, RegAddr, DebugRegWrite);
	
   initial begin
      string memfilename;
      memfilename = {"../testing/riscvtestCSR.memfile"};
      $readmemh(memfilename, dut.imem.RAM);
      $readmemh(memfilename, dut.dmem.RAM);	
   end
   
   // init
   initial begin
      HaltReq = 0;
      ResumeReq = 0;
      DebugRegWrite = 1'b0;
      DebugControl = 1'b0;      
      reset <= 1; #22; reset <= 0;       
   end
   
   // clock
   always begin
      clk <= 1; #5; clk <= 0; #5;
   end
   
   // done check
   always @(negedge clk) begin
      if (MemWrite) begin
         if (DataAdr === 32'd100 && WriteData === 32'd10) begin
            $display("Simulation succeeded");
            $stop;
         end else if (DataAdr === 32'd100 && WriteData === 32'd17) begin
            $display("Simulation failed");
            $stop;
         end
      end
   end
endmodule

// ============================================================
// Top
// ============================================================
module top(input  logic        clk, reset, 
           output logic [31:0] WriteDataM, DataAdrM, 
           output logic        MemWriteM,
           input  logic        HaltReq, ResumeReq,
           output logic        DebugMode,
           input  logic        DebugControl,
           output logic [31:0] RegIn,
           input  logic [31:0] RegOut,
           input  logic [4:0]  RegAddr,
           input  logic        DebugRegWrite);

   logic [31:0] PCF, InstrF, ReadDataM;

   riscv rv32pipe(clk, reset, PCF, InstrF, MemWriteM, DataAdrM, 
                  WriteDataM, ReadDataM, HaltReq, ResumeReq, DebugMode, DebugControl,
                  RegIn, RegOut, RegAddr, DebugRegWrite);

   imem #("../testing/riscvtestCSR.memfile") imem(PCF, InstrF);
   dmem dmem(clk, MemWriteM, DataAdrM, WriteDataM, ReadDataM);
   
endmodule

// ============================================================
// Core (riscv)
// ============================================================
module riscv(input  logic        clk, 
             input  logic        reset,
             output logic [31:0] PCF,
             input  logic [31:0] InstrF,
             output logic        MemWriteM,
             output logic [31:0] ALUResultM, WriteDataM,
             input  logic [31:0] ReadDataM,
             input  logic        HaltReq,
             input  logic        ResumeReq,
             output logic        DebugMode,
             input  logic        DebugControl,
             output logic [31:0] RegIn,
             input  logic [31:0] RegOut,
             input  logic [4:0]  RegAddr,
             input  logic        DebugRegWrite);

   // Decode/Execute control+status
   logic [6:0]  opD;
   logic [2:0]  funct3D;
   logic        funct7b5D;
   logic [2:0]  ImmSrcD;
   logic [3:0]  FlagsE;
   logic        PCSrcE;
   logic [3:0]  ALUControlE;
   logic        ALUSrcAE;   
   logic        ALUSrcBE;
   logic        PCTargetSrcE;   
   logic        ResultSrcEb0;
   logic        RegWriteM;
   logic [1:0]  ResultSrcW;
   logic        RegWriteW;
   logic [2:0]  LoadTypeM;
   logic [1:0]  StoreTypeM;   

   logic [1:0]  ForwardAE, ForwardBE;
   logic        StallF, StallD, FlushD, FlushE;

   // CSR pipe wires
   logic        csr_weE;
   logic [11:0] csr_addrE;
   logic [31:0] csr_wdataE;
   logic [31:0] csr_rdata;

   logic        CsrEnE;
   logic [1:0]  CsrOpE;
   logic        CsrImmE;

   logic [4:0]  Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;

   // NEW: validity + illegal CSR in Execute
   logic        instr_validE;
   logic        csr_illegalE;

   // CSR block
   csr csr0(clk, reset, PCF, HaltReq, ResumeReq, DebugMode, 
            csr_weE, csr_addrE, csr_wdataE, csr_rdata);
   
   // Controller (now also receives CSRAddrD/ZimmD/Rs1D)
   logic [11:0] CSRAddrD;
   logic [4:0]  ZimmD;
   controller c(clk, reset,
                opD, funct3D, funct7b5D, ImmSrcD,
                FlushE, FlagsE, PCSrcE, ALUControlE, ALUSrcAE, ALUSrcBE, PCTargetSrcE,
                ResultSrcEb0, MemWriteM, RegWriteM, 
                LoadTypeM, StoreTypeM, RegWriteW, ResultSrcW,
                // CSR decode outputs (to E)
                CsrEnE, CsrOpE, CsrImmE,
                // NEW inputs for CSR decoder in controller
                CSRAddrD, ZimmD, Rs1D,
                // NEW outputs
                instr_validE, csr_illegalE);

   // Datapath consumes instr_validE + csr_illegalE to guard CSR writes
   datapath dp(clk, reset,
               // Fetch
               StallF, PCF, InstrF,
               // Decode -> to controller
               opD, funct3D, funct7b5D, StallD, FlushD, ImmSrcD,
               // Execute
               FlushE, ForwardAE, ForwardBE, PCSrcE, ALUControlE, 
               ALUSrcAE, ALUSrcBE, PCTargetSrcE, FlagsE,
               // Memory
               MemWriteM, WriteDataM, ALUResultM, ReadDataM,
               LoadTypeM, StoreTypeM, RegWriteW, ResultSrcW,
               // Hazard
               Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
               // Debug
               DebugControl, RegIn, RegOut, RegAddr, DebugRegWrite,
               // CSR bus (E)
               csr_weE, csr_addrE, csr_wdataE, csr_rdata,
               // CSR control (from controller)
               CsrEnE, CsrOpE, CsrImmE,
               // NEW: validity + illegal in Execute
               instr_validE, csr_illegalE,
               // NEW: expose D-stage CSR slices to controller
               CSRAddrD, ZimmD);

   // Hazard unit (CSR hazard input uses CsrEnE as "UseCSRResultE" equivalent)
   hazard  hu(Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
              PCSrcE, ResultSrcEb0, RegWriteM, RegWriteW,
              ForwardAE, ForwardBE, StallF, StallD, FlushD, FlushE,
              CsrEnE, DebugMode);
endmodule

// ============================================================
// Controller (adds instr_validE + csr_illegalE, drives Csr*E)
// ============================================================
module controller(input  logic       clk, reset,
                  input  logic [6:0] opD,
                  input  logic [2:0] funct3D,
                  input  logic       funct7b5D,
                  output logic [2:0] ImmSrcD,
                  input  logic       FlushE, 
                  input  logic [3:0] FlagsE, 
                  output logic       PCSrcE, 
                  output logic [3:0] ALUControlE,
                  output logic       ALUSrcAE,
                  output logic       ALUSrcBE,
                  output logic       PCTargetSrcE,
                  output logic       ResultSrcEb0, 
                  output logic       MemWriteM,
                  output logic       RegWriteM, 
                  output logic [2:0] LoadTypeM, 
                  output logic [1:0] StoreTypeM,
                  output logic       RegWriteW, 
                  output logic [1:0] ResultSrcW,
                  // CSR control to E
                  output logic       CsrEnE,
                  output logic [1:0] CsrOpE,
                  output logic       CsrImmE,
                  // NEW: need csr_addr/zimm/rs1 from Decode
                  input  logic [11:0] CSRAddrD,
                  input  logic [4:0]  ZimmD,
                  input  logic [4:0]  Rs1D,
                  // NEW: pipelined validity + illegal CSR flags
                  output logic       instr_validE,
                  output logic       csr_illegalE
                  );

   logic             RegWriteD, RegWriteE;
   logic [1:0]       ResultSrcD, ResultSrcE, ResultSrcM;
   logic             MemWriteD, MemWriteE;
   logic             JumpD, JumpE;
   logic             BranchD, BranchE;
   logic             BranchTakenE;   
   logic [1:0]       ALUOpD;
   logic [3:0]       ALUControlD;
   logic             ALUSrcAD;   
   logic             ALUSrcBD;
   logic             PCTargetSrcD;   
   logic [2:0]       funct3E;
   logic [2:0]       LoadTypeE;
   logic [1:0]       StoreTypeE;

   // NEW: instruction-valid bookkeeping
   logic             InstrValidD, InstrValidE;

   // Decode stage logic
   maindec md(opD, ResultSrcD, MemWriteD, BranchD, ALUSrcAD, ALUSrcBD, 
              PCTargetSrcD, RegWriteD, JumpD, ImmSrcD, ALUOpD);

   aludec  ad(opD[5], funct3D, funct7b5D, ALUOpD, ALUControlD);

   // ---------------- CSR decode in D ----------------
   logic        csr_en_d_pre;
   logic [1:0]  csr_op_d;
   logic        csr_imm_d;
   logic        csr_illegal_d;

   csrdec  csrd(
      .op(opD),
      .funct3(funct3D),
      .csr_addr(CSRAddrD),
      .rs1_is_x0(Rs1D == 5'd0),
      .zimm(ZimmD),
      .csr_en(csr_en_d_pre),
      .csr_op(csr_op_d),
      .csr_imm(csr_imm_d),
      .csr_illegal_o(csr_illegal_d)
   );

   // Valid instruction in Decode (treat op=0 as reset filler)
   assign InstrValidD = (opD != 7'b0000000);

   // Gate CSR enable with instruction validity
   logic CsrEnD;
   assign CsrEnD = InstrValidD & csr_en_d_pre;

   // Execute stage control register bundle (20 bits)
   // {RegWrite|CSR, ResultSrc(2), MemWrite, Jump, Branch, ALUControl(4),
   //  ALUSrcA, ALUSrcB, PCTargetSrc, funct3(3), CsrEn, CsrOp(2), CsrImm}
   floprc #(20) controlregE(clk, reset, FlushE,
                            {RegWriteD | CsrEnD, ResultSrcD, MemWriteD, JumpD, BranchD, ALUControlD, 
                             ALUSrcAD, ALUSrcBD, PCTargetSrcD, funct3D, CsrEnD, csr_op_d, csr_imm_d},
                            {RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, ALUControlE, 
                             ALUSrcAE, ALUSrcBE, PCTargetSrcE, funct3E, CsrEnE, CsrOpE, CsrImmE});

   // Pipeline InstrValidD -> InstrValidE (cleared on FlushE)
   floprc #(1) instrvalidE_reg(clk, reset, FlushE, InstrValidD, InstrValidE);
   assign instr_validE = InstrValidE;

   // Pipeline csr_illegal_d -> csr_illegalE (cleared on FlushE)
   floprc #(1) csr_illegalE_reg(clk, reset, FlushE, csr_illegal_d, csr_illegalE);

   // Branch/load-store helpers
   bu  branchunit (BranchE, FlagsE, funct3E, BranchTakenE);
   lsu lsu (funct3E, LoadTypeE, StoreTypeE);
   
   assign PCSrcE       = BranchTakenE | JumpE;  
   assign ResultSrcEb0 = ResultSrcE[0];
   
   // Memory stage pipeline
   flopr #(9) controlregM(clk, reset,
                          {RegWriteE, ResultSrcE, MemWriteE, LoadTypeE, StoreTypeE},
                          {RegWriteM, ResultSrcM, MemWriteM, LoadTypeM, StoreTypeM});
   
   // Writeback stage pipeline
   flopr #(3) controlregW(clk, reset, {RegWriteM, ResultSrcM}, {RegWriteW, ResultSrcW});     
endmodule // controller

// ============================================================
// Branch Unit
// ============================================================
module bu (input  logic       Branch,
           input  logic [3:0] Flags,
           input  logic [2:0] funct3,
           output logic       taken);

   logic v, c, n, z;
   logic cond;
   
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
     endcase 
endmodule 

// ============================================================
// Main Decoder
// ============================================================
module maindec(input  logic [6:0] op,
               output logic [1:0] ResultSrc,
               output logic       MemWrite,
               output logic       Branch, ALUSrcA, ALUSrcB, PCTargetSrc,
               output logic       RegWrite, Jump,
               output logic [2:0] ImmSrc,
               output logic [1:0] ALUOp);

   logic [13:0] controls;

   assign {RegWrite, ImmSrc, ALUSrcA, ALUSrcB, MemWrite,
           ResultSrc, Branch, ALUOp, Jump, PCTargetSrc} = controls;

   always_comb
     case(op)
       // RegWrite_ImmSrc_ALUSrcA_ALUSrcB_MemWrite_ResultSrc_Branch_ALUOp_Jump_PCTargetSrc
       7'b0000011: controls = 14'b1_000_0_1_0_01_0_00_0_x; // lw
       7'b0100011: controls = 14'b0_001_0_1_1_00_0_00_0_x; // sw
       7'b0110011: controls = 14'b1_xxx_0_0_0_00_0_10_0_x; // R-type 
       7'b1100011: controls = 14'b0_010_0_0_0_00_1_01_0_0; // branch
       7'b0010011: controls = 14'b1_000_0_1_0_00_0_10_0_x; // I-type ALU
       7'b1101111: controls = 14'b1_011_0_0_0_10_0_00_1_0; // jal
       7'b0110111: controls = 14'b1_100_1_1_0_00_0_00_0_x; // lui
       7'b0010111: controls = 14'b1_100_x_x_0_11_0_xx_0_0; // auipc       
       7'b1100111: controls = 14'b1_000_0_1_0_10_0_00_1_1; // jalr
       7'b1110011: controls = 14'b1_000_0_0_0_00_0_00_0_x; // csr (handled by csrdec)
       7'b0000000: controls = 14'b0_000_0_0_0_00_0_00_0_0; // reset filler
       default:    controls = 14'bx_xxx_x_x_x_xx_x_xx_x_x; // undefined
     endcase
endmodule

// ============================================================
// ALU Decoder
// ============================================================
module aludec(input  logic       opb5,
              input  logic [2:0] funct3,
              input  logic       funct7b5, 
              input  logic [1:0] ALUOp,
              output logic [3:0] ALUControl);

   logic RtypeSub;
   assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction

   always_comb begin
     unique case (ALUOp)
       2'b00: ALUControl = 4'b0000; // addition (loads/stores)
       2'b01: ALUControl = 4'b0001; // subtraction (branches)
       default: begin
         unique case (funct3) // R–type or I–type ALU
           3'b000: ALUControl = RtypeSub ? 4'b0001 : 4'b0000; // sub or add/addi
           3'b001: ALUControl = 4'b0110; // sll, slli		  
           3'b010: ALUControl = 4'b0101; // slt, slti
           3'b011: ALUControl = 4'b1001; // sltu, sltiu
           3'b100: ALUControl = 4'b0100; // xor, xori		  
           3'b101: ALUControl = funct7b5 ? 4'b1000 : 4'b0111; // sra/srai or srl/srli
           3'b110: ALUControl = 4'b0011; // or, ori
           3'b111: ALUControl = 4'b0010; // and, andi
           default: ALUControl = 4'bxxxx;
         endcase
       end
     endcase
   end
endmodule // aludec

// ============================================================
// LSU Decode
// ============================================================
module lsu (input  logic [2:0] funct3,
            output logic [2:0] LoadType,
            output logic [1:0] StoreType);

   always_comb
     case(funct3)
       3'b000: {LoadType, StoreType} = {3'b010, 2'b01}; // LB
       3'b001: {LoadType, StoreType} = {3'b011, 2'b10}; // LH
       3'b010: {LoadType, StoreType} = {3'b000, 2'b00}; // LW
       3'b101: {LoadType, StoreType} = {3'b100, 2'bxx}; // LHU      
       3'b100: {LoadType, StoreType} = {3'b001, 2'bxx}; // LBU
       default:{LoadType, StoreType} = 5'bxxxxx;
     endcase  
endmodule // lsu

// ============================================================
// Datapath (CSR write gated by instr_validE & ~csr_illegalE)
// ============================================================
module datapath(input  logic        clk, reset,
                // Fetch
                input  logic        StallF,
                output logic [31:0] PCF,
                input  logic [31:0] InstrF,
                // Decode (exports slices)
                output logic [6:0]  opD,
                output logic [2:0]  funct3D, 
                output logic        funct7b5D,
                input  logic        StallD, FlushD,
                input  logic [2:0]  ImmSrcD,
                // Execute
                input  logic        FlushE,
                input  logic [1:0]  ForwardAE, ForwardBE,
                input  logic        PCSrcE,
                input  logic [3:0]  ALUControlE,
                input  logic        ALUSrcAE,
                input  logic        ALUSrcBE,
                input  logic        PCTargetSrcE,
                output logic [3:0]  FlagsE,
                // Memory
                input  logic        MemWriteM, 
                output logic [31:0] WriteDataM, ALUResultM,
                input  logic [31:0] ReadDataM,
                input  logic [2:0]  LoadTypeM,
                input  logic [1:0]  StoreTypeM,
                // Writeback
                input  logic        RegWriteW, 
                input  logic [1:0]  ResultSrcW,
                // Hazard
                output logic [4:0]  Rs1D, Rs2D, Rs1E, Rs2E,
                output logic [4:0]  RdE, RdM, RdW,
                // Debug
                input  logic        DebugControl,
                output logic [31:0] RegIn,
                input  logic [31:0] RegOut,
                input  logic [4:0]  RegAddr,
                input  logic        DebugRegWrite,
                // CSR bus (E)
                output logic        csr_weE,
                output logic [11:0] csr_addrE,
                output logic [31:0] csr_wdataE,
                input  logic [31:0] csr_rdata,
                // CSR control (from controller)
                input  logic        CsrEnE,
                input  logic [1:0]  CsrOpE,
                input  logic        CsrImmE,
                // NEW: validity/illegal in Execute
                input  logic        instr_validE,
                input  logic        csr_illegalE,
                // NEW: expose D-stage CSR slices to controller
                output logic [11:0] CSRAddrD,
                output logic [4:0]  ZimmD);

   // Fetch
   logic [31:0] PCNextF, PCPlus4F;

   // Decode
   logic [31:0] InstrD;
   logic [31:0] PCD, PCPlus4D;
   logic [31:0] RD1D, RD2D;
   logic [31:0] ImmExtD;
   logic [4:0]  RdD;

   // Execute
   logic [31:0] RD1E, RD2E;
   logic [31:0] PCE, ImmExtE;
   logic [31:0] SrcAE, SrcBE;
   logic [31:0] SrcAEforward;   
   logic [31:0] ALUResultE;
   logic [31:0] WriteDataE;
   logic [31:0] PCPlus4E;
   logic [31:0] PCTargetE;
   logic [31:0] PCRelativeTargetE;
   logic [31:0] csr_srcE;
   logic [31:0] csr_oldE;
   logic [31:0] csr_newE;
   logic        csr_writeE;
   logic        UseCSRResultE;
   logic [31:0] CSRReadE;
   logic [4:0]  ZimmE;   

   // Memory
   logic [31:0] PCPlus4M;
   logic [31:0] PCTargetM;
   logic [7:0]  byteoutM;
   logic [15:0] halfwordoutM;
   logic [31:0] ZeroExtendByteM;
   logic [31:0] SignExtendByteM;
   logic [31:0] SignExtendWordM;
   logic [31:0] ZeroExtendWordM;   
   logic [31:0] WriteDataPreM;
   logic [31:0] ReadDataMuxM;
   logic        UseCSRResultM;
   logic [31:0] CSRReadM;   

   // Writeback
   logic [31:0] ALUResultW;
   logic [31:0] ReadDataW;
   logic [31:0] PCPlus4W;
   logic [31:0] ResultW2;
   logic [31:0] ResultW;
   logic [31:0] PCTargetW;
   logic        UseCSRResultW;
   logic [31:0] CSRReadW;
   logic [31:0] ResultFinalW2;   

   logic [4:0]  Rs1;

   // ---------------- Fetch ----------------
   mux2    #(32)  pcmux(PCPlus4F, PCTargetE, PCSrcE, PCNextF);
   flopenr #(32)  pcreg(clk, reset, ~StallF, PCNextF, PCF);
   adder          pcadd(PCF, 32'h4, PCPlus4F);

   // ---------------- Decode ----------------
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

   // ---------------- Execute ----------------
   floprc #(192) regE(clk, reset, FlushE, 
                      {RD1D, RD2D, PCD, Rs1D, Rs2D, RdD, ImmExtD, PCPlus4D, CSRAddrD, ZimmD}, 
                      {RD1E, RD2E, PCE, Rs1E, Rs2E, RdE, ImmExtE, PCPlus4E, csr_addrE, ZimmE});

   mux3   #(32)  faemux(RD1E, ResultW, ALUResultM, ForwardAE, SrcAEforward);
   mux3   #(32)  fbemux(RD2E, ResultW, ALUResultM, ForwardBE, WriteDataE);
   mux2   #(32)  srcamux(SrcAEforward, 32'h0, ALUSrcAE, SrcAE);   
   mux2   #(32)  srcbmux(WriteDataE, ImmExtE, ALUSrcBE, SrcBE);
   alu           alu(SrcAE, SrcBE, ALUControlE, ALUResultE, FlagsE);
   adder         branchadd(ImmExtE, PCE, PCRelativeTargetE);
   mux2 #(32)    jalrmux (PCRelativeTargetE, ALUResultE, PCTargetSrcE, PCTargetE);

   // ---- CSR operation (Execute) ----
   // use forwarded Rs1 value for CSR src to honor forwarding
   assign csr_srcE = CsrImmE ? {27'b0, ZimmE} : SrcAEforward;
   assign csr_oldE = csr_rdata;

   // New CSR value per op
   always_comb begin
     unique case (CsrOpE)
       2'b01: csr_newE = csr_srcE;                 // CSRRW/CSRRWI
       2'b10: csr_newE = csr_oldE |  csr_srcE;     // CSRRS/CSRRSI
       2'b11: csr_newE = csr_oldE & ~csr_srcE;     // CSRRC/CSRRCI
       default: csr_newE = csr_oldE;
     endcase
   end

   // Per spec: CSRRS/CSRRC do not write if src==0
   assign csr_writeE = CsrEnE && ( (CsrOpE == 2'b01) || (csr_srcE != 32'b0) );

   // *** Gate write with instr_validE AND not illegal ***
   assign csr_weE    = instr_validE && ~csr_illegalE && csr_writeE;
   assign csr_wdataE = csr_newE;

   // CSR readback
   assign UseCSRResultE = CsrEnE;
   assign CSRReadE      = csr_oldE;

   // CSR pipeline (M/W)
   flopr #(33) csr_pipe_M (clk, reset, {UseCSRResultE, CSRReadE}, {UseCSRResultM, CSRReadM});
   flopr #(33) csr_pipe_W (clk, reset, {UseCSRResultM, CSRReadM}, {UseCSRResultW, CSRReadW});

   // ---------------- Memory ----------------
   flopr  #(133) regM(clk, reset, 
                      {ALUResultE, WriteDataE, RdE, PCPlus4E, PCTargetE},
                      {ALUResultM, WriteDataPreM, RdM, PCPlus4M, PCTargetM});

   mux4 #(8)  bytesel (ReadDataM[7:0], ReadDataM[15:8], ReadDataM[23:16], ReadDataM[31:24],
                       ALUResultM[1:0], byteoutM);
   mux2 #(16) wordsel (ReadDataM[15:0], ReadDataM[31:16], ALUResultM[1], halfwordoutM);   
   zeroextend #(8)  zeb (byteoutM, ZeroExtendByteM);
   signextend #(8)  seb (byteoutM, SignExtendByteM);
   zeroextend #(16) zew (halfwordoutM, ZeroExtendWordM);   
   signextend #(16) sew (halfwordoutM, SignExtendWordM);   
   mux5 #(32) readdatamux (ReadDataM, ZeroExtendByteM, SignExtendByteM, 
                           SignExtendWordM, ZeroExtendWordM, 
                           LoadTypeM, ReadDataMuxM);  
   wdunit wdu (WriteDataPreM, ReadDataM, StoreTypeM, ALUResultM[1:0], WriteDataM); 

   // ---------------- Writeback ----------------
   flopr  #(133) regW(clk, reset, 
                      {ALUResultM, ReadDataMuxM, RdM, PCPlus4M, PCTargetM},
                      {ALUResultW, ReadDataW, RdW, PCPlus4W, PCTargetW});

   mux4 #(32)  resultmux(ALUResultW, ReadDataW, PCPlus4W, PCTargetW, ResultSrcW, ResultW2);
   // CSR instruction returns OLD value
   mux2 #(32) csrsel(ResultW2, CSRReadW, UseCSRResultW, ResultFinalW2);
   // Debug write override
   mux2 #(32) debugwritemux(ResultFinalW2, RegOut, DebugControl, ResultW);   
endmodule

// ============================================================
// Hazard Unit (includes simple CSR read-after-write stall)
// ============================================================
module hazard(input  logic [4:0]  Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
              input  logic        PCSrcE, ResultSrcEb0, 
              input  logic        RegWriteM, RegWriteW,
              output logic [1:0]  ForwardAE, ForwardBE,
              output logic        StallF, StallD, FlushD, FlushE,
              input  logic        UseCSRResultE,
              input  logic        DebugMode);

   logic lwStallD;
   logic csrStallD;   

   // forwarding
   always_comb begin
      ForwardAE = 2'b00;
      ForwardBE = 2'b00;
      if (Rs1E != 5'b0) begin
         if      ((Rs1E == RdM) & RegWriteM) ForwardAE = 2'b10;
         else if ((Rs1E == RdW) & RegWriteW) ForwardAE = 2'b01;
      end
      if (Rs2E != 5'b0) begin
         if      ((Rs2E == RdM) & RegWriteM) ForwardBE = 2'b10;
         else if ((Rs2E == RdW) & RegWriteW) ForwardBE = 2'b01;
      end
   end
   
   // stalls/flushes
   assign lwStallD  = ResultSrcEb0 & ((Rs1D == RdE) | (Rs2D == RdE));
   assign csrStallD = UseCSRResultE & (RdE != 5'd0) &
                      ((Rs1D == RdE) | (Rs2D == RdE));  

   assign StallD = lwStallD | csrStallD | DebugMode;
   assign StallF = lwStallD | csrStallD | DebugMode;

   assign FlushD = PCSrcE;
   assign FlushE = lwStallD | csrStallD | PCSrcE;
endmodule

// ============================================================
// Register File
// ============================================================
module regfile(input  logic        clk, 
               input  logic        we3, 
               input  logic [4:0]  a1, a2, a3, 
               input  logic [31:0] wd3, 
               output logic [31:0] rd1, rd2);

   logic [31:0] rf[31:0];

   // write on falling edge (as in your original)
   always_ff @(negedge clk)
      if (we3) rf[a3] <= wd3;	

   assign rd1 = (a1 != 0) ? rf[a1] : 0;
   assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule

// ============================================================
// Small Utils
// ============================================================
module adder(input  logic [31:0] a, b,
             output logic [31:0] y);
   assign y = a + b;
endmodule

module extend(input  logic [31:7] instr,
              input  logic [2:0]  immsrc,
              output logic [31:0] immext);

   always_comb
     case(immsrc) 
       3'b000: immext = {{20{instr[31]}}, instr[31:20]};                         // I-type 
       3'b001: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};            // S-type
       3'b010: immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
       3'b011: immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type
       3'b100: immext = {instr[31:12], 12'h0};                                   // U-type
       default: immext = 32'bx;
     endcase             
endmodule

module flopr #(parameter WIDTH = 8)
   (input  logic             clk, reset,
    input  logic [WIDTH-1:0] d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset) q <= '0;
     else       q <= d;
endmodule

module flopenr #(parameter WIDTH = 8)
   (input  logic             clk, reset, en,
    input  logic [WIDTH-1:0] d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= '0;
     else if (en) q <= d;
endmodule

module flopenrc #(parameter WIDTH = 8)
   (input  logic             clk, reset, clear, en,
    input  logic [WIDTH-1:0] d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= '0;
     else if (en) begin
       if (clear) q <= '0;
       else       q <= d;
     end
endmodule 

module floprc #(parameter WIDTH = 8)
   (input  logic             clk,
    input  logic             reset,
    input  logic             clear,
    input  logic [WIDTH-1:0] d, 
    output logic [WIDTH-1:0] q);

   always_ff @(posedge clk, posedge reset)
     if (reset) q <= '0;
     else if (clear) q <= '0;
     else           q <= d;
endmodule

module csr_reg_en #(parameter WIDTH = 32, ADDR = 12)
   (input  logic             clk,
    input  logic             reset,
    input  logic [ADDR-1:0]  address,
    input  logic             csr_we,
    input  logic [ADDR-1:0]  csr_addr,
    input  logic [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] q);

   logic en;
   assign en = csr_we & (csr_addr == address);
   flopenr #(WIDTH) u_reg (clk, reset, en, d_in, q);
endmodule

module misa_reg_en #(parameter WIDTH = 32, ADDR = 12)
   (input  logic             clk,
    input  logic             reset,
    input  logic [ADDR-1:0]  address, 
    input  logic             csr_we,
    input  logic [ADDR-1:0]  csr_addr, 
    input  logic [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] q);

   logic en;
   // misa default: RV32I => MXL=01 in [31:30], 'I' bit (bit 8) set, others 0.
   logic [31:0] MISA_RV32I = (32'h1 << 30) | (32'h1 << 8);
   
   assign en = csr_we & (csr_addr == address);
   always_ff @(posedge clk, posedge reset)
     if (reset)   q <= MISA_RV32I;
     else if (en) q <= d_in;
endmodule

module mux2 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, 
    input  logic             s, 
    output logic [WIDTH-1:0] y);
   assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] d0, d1, d2,
    input  logic [1:0]       s, 
    output logic [WIDTH-1:0] y);
   assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

module mux4 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s, 
  output logic [WIDTH-1:0] y);
  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0); 
endmodule

module mux5 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4,
  input  logic [2:0]       s, 
  output logic [WIDTH-1:0] y);
  assign y = s[2] ? d4 : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0)); 
endmodule

// ============================================================
// Instruction/Data memories (toy)
// ============================================================
module imem #(parameter MEM_INIT_FILE)
    (input  logic [31:0] a,
     output logic [31:0] rd);
   
   logic [31:0] RAM[127:0];

   initial begin
      if (MEM_INIT_FILE != "") begin
         $readmemh(MEM_INIT_FILE, RAM);
      end
   end
   
   assign rd = RAM[a[31:2]]; // word aligned
endmodule

module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);
   
   logic [31:0] RAM[8191:0];
   
   assign rd = RAM[a[31:2]]; // word aligned
   always_ff @(posedge clk)
     if (we) RAM[a[31:2]] <= wd;
endmodule

// ============================================================
// ALU 
// ============================================================
module alu(input  logic [31:0] a, b,
           input  logic [3:0]  alucontrol,
           output logic [31:0] result,
           output logic [3:0]  flags);

   logic [31:0] condinvb, sum;
   logic        v, c, n, z;
   logic        Asign, Bsign;
   logic        Neg;   
   logic        LT, LTU; 
   logic        cout;   
   logic        isAddSub;

   assign flags = {v, c, n, z};   
   assign condinvb = alucontrol[0] ? ~b : b;
   assign {cout, sum} = a + condinvb + alucontrol[0];
   assign isAddSub = (~alucontrol[3] & ~alucontrol[2] & ~alucontrol[1]) |
                     (~alucontrol[3] & ~alucontrol[1] &  alucontrol[0]);
   assign Asign = a[31];
   assign Bsign = b[31];
   assign Neg  = sum[31];   
   assign LT  = Asign & ~Bsign | Asign & Neg | ~Bsign & Neg; 
   assign LTU = ~cout;  

   always_comb
     case (alucontrol)
       4'b0000: result = sum;                  // add
       4'b0001: result = sum;                  // subtract
       4'b0010: result = a & b;                // and
       4'b0011: result = a | b;                // or
       4'b0100: result = a ^ b;                // xor
       4'b0101: result = {{31{1'b0}}, LT};     // slt
       4'b1001: result = {{31{1'b0}}, LTU};    // sltu 
       4'b0110: result = a << b[4:0];          // sll
       4'b0111: result = a >> b[4:0];          // srl
       4'b1000: result = $signed(a) >>> b[4:0];// sra        
       default: result = 32'bx;
     endcase

   assign z = (result == 32'b0);
   assign n = result[31];
   assign c = cout & isAddSub;   
   assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
endmodule

module zeroextend #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] a,
    output logic [31:0]      zeroimmext);
   assign zeroimmext = {{{32-WIDTH}{1'b0}}, a};
endmodule

module signextend #(parameter WIDTH = 8)
   (input  logic [WIDTH-1:0] a,
    output logic [31:0]      signext);
   assign signext = {{{32-WIDTH}{a[WIDTH-1]}}, a};
endmodule

module wdunit (input  logic [31:0] rd2, 
               input  logic [31:0] readdata,
               input  logic [1:0]  StoreType,
               input  logic [1:0]  byteoffset,
               output logic [31:0] WriteData);
   
   logic [31:0] storeb0, storeb1, storeb2, storeb3;
   logic [31:0] storeh0, storeh1;
   logic [31:0] sbword,  shword;

   assign storeb0 = {readdata[31:8],  rd2[7:0]};
   assign storeb1 = {readdata[31:16], rd2[7:0], readdata[7:0]};
   assign storeb2 = {readdata[31:24], rd2[7:0], readdata[15:0]};
   assign storeb3 = {rd2[7:0],        readdata[31:8]};

   assign storeh0 = {readdata[31:16], rd2[15:0]};
   assign storeh1 = {rd2[15:0],       readdata[31:16]};

   mux4 #(32) sbmux (storeb0, storeb1, storeb2, storeb3, byteoffset, sbword);
   mux2 #(32) shmux (storeh0, storeh1, byteoffset[1], shword);   
   mux3 #(32) wdmux (rd2, sbword, shword, StoreType, WriteData);     
endmodule

// ============================================================
// CSR block (now protected by csr_illegalE upstream)
// ============================================================
module csr(input  logic        clk,
           input  logic        reset,
           // PC for capturing into dpc on entry to debug
           input  logic [31:0] PC,
           // External debug requests
           input  logic        HaltReq,
           input  logic        ResumeReq,
           output logic        DebugMode,
           // Pipeline CSR access (E)
           input  logic        csr_we,
           input  logic [11:0] csr_addr,
           input  logic [31:0] csr_wdata,
           output logic [31:0] csr_rdata);
   
   typedef enum logic {RUNNING, HALTED} dbg_state_e;
   dbg_state_e state, state_n;
   
   // Debug CSRs
   logic [31:0] dcsr;       // 0x7B0
   logic [31:0] dpc;        // 0x7B1
   logic [31:0] dscratch0;  // 0x7B2
   
   // Machine CSRs (simplified)
   logic [31:0] mstatus;    // 0x300
   logic [31:0] misa;       // 0x301
   logic [31:0] mtvec;      // 0x305
   logic [31:0] mepc;       // 0x341
   logic [31:0] mcause;     // 0x342
   logic [31:0] mtval;      // 0x343

   // Debug cause (3 = halt request)
   logic [2:0] dcause;
   assign dcause = (HaltReq) ? 3'd3 : 3'd0;

   // FSM
   always_ff @(posedge clk) begin
      if (reset) begin
         state <= RUNNING;
      end else if (HaltReq | ResumeReq) begin
         state <= state_n;
      end
   end
   always_comb begin
      unique case (state)
        RUNNING: state_n = HaltReq  ? HALTED  : RUNNING;
        HALTED : state_n = ResumeReq? RUNNING : HALTED;
        default: state_n = RUNNING;
      endcase
   end
   assign DebugMode = (state == HALTED);
   
   // CSR read mux
   always_comb begin
      unique case (csr_addr)
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

   // Regs
   csr_reg_en  #(32, 12) mstatus_reg(clk, reset, 12'h300, csr_we, csr_addr, csr_wdata, mstatus);
   csr_reg_en  #(32, 12) mtvec_reg  (clk, reset, 12'h305, csr_we, csr_addr, csr_wdata, mtvec);
   csr_reg_en  #(32, 12) mepc_reg   (clk, reset, 12'h341, csr_we, csr_addr, csr_wdata, mepc);
   csr_reg_en  #(32, 12) mcause_reg (clk, reset, 12'h342, csr_we, csr_addr, csr_wdata, mcause);
   csr_reg_en  #(32, 12) mtval_reg  (clk, reset, 12'h343, csr_we, csr_addr, csr_wdata, mtval);
   csr_reg_en  #(32, 12) dscratch0_reg(clk, reset, 12'h7b2, csr_we, csr_addr, csr_wdata, dscratch0);
   misa_reg_en #(32, 12) misa_reg   (clk, reset, 12'h301, csr_we, csr_addr, csr_wdata, misa);
   
   // DPC
   always_ff @(posedge clk) begin
      if (reset) begin
         dpc <= '0;
      end else if (state == RUNNING && state_n == HALTED) begin
         dpc <= PC; // capture PC on entry to debug
      end else if (csr_we & (csr_addr == 12'h7B1)) begin
         dpc <= csr_wdata;
      end
   end
   
   // DCSR
   always_ff @(posedge clk) begin
      if (reset) begin
         dcsr <= {4'd4, 1'b0, 3'd0, 4'd0, 1'b0, 1'b0, 1'b0, 1'b0,
                  1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                  3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 2'd3 };
      end else if (state == RUNNING && state_n == HALTED) begin
         dcsr <= { dcsr[31:9], dcause, dcsr[5:0] };
      end else if (csr_we & (csr_addr == 12'h7B0)) begin
         dcsr <= {4'd4, 12'd0, csr_wdata[15], 6'd0, dcause, 3'd0, csr_wdata[2], dcsr[1:0]};
      end 
   end
endmodule // csr

// ============================================================
// CSR Decoder (with csr_en & csr_illegal_o)
// ============================================================
module csrdec(
  input  logic [6:0]  op,        // Instr[6:0]
  input  logic [2:0]  funct3,    // Instr[14:12]
  input  logic [11:0] csr_addr,  // Instr[31:20]
  input  logic        rs1_is_x0, // (rs1 == x0)
  input  logic [4:0]  zimm,      // Instr[19:15] for immediate forms

  output logic        csr_en,         // 1 if CSRR* instruction
  output logic [1:0]  csr_op,         // 01=RW, 10=RS, 11=RC
  output logic        csr_imm,        // 1: immediate form, 0: rs1 form
  output logic        csr_illegal_o   // 1 if illegal CSR access
);
  // SYSTEM opcode?
  logic is_system = (op == 7'b1110011);

  // Base decode
  always_comb begin
    csr_en  = 1'b0;
    csr_op  = 2'b00;
    csr_imm = 1'b0;
    if (is_system && (funct3 != 3'b000)) begin
      csr_en  = 1'b1;
      csr_imm = funct3[2];
      unique case (funct3[1:0])
        2'b01: csr_op = 2'b01; // CSRRW / CSRRWI
        2'b10: csr_op = 2'b10; // CSRRS / CSRRSI
        2'b11: csr_op = 2'b11; // CSRRC / CSRRCI
        default: csr_op = 2'b00;
      endcase
    end
  end

  // Write attempt?
  logic write_attempt;
  logic src_is_zero = csr_imm ? (zimm == 5'd0) : rs1_is_x0;

  always_comb begin
    unique case (csr_op)
      2'b01: write_attempt = 1'b1;              // RW always writes
      2'b10: write_attempt = ~src_is_zero;      // RS writes if src!=0
      2'b11: write_attempt = ~src_is_zero;      // RC writes if src!=0
      default: write_attempt = 1'b0;
    endcase
  end

  // Read-only CSRs: csr_addr[11:10] == 2'b11 per RISC-V
  logic is_readonly = (csr_addr[11:10] == 2'b11);

  // Implemented CSR whitelist (extend as you add more)
  logic implemented;
  always_comb begin
    unique case (csr_addr)
      12'h300, // mstatus
      12'h301, // misa
      12'h305, // mtvec
      12'h341, // mepc
      12'h342, // mcause
      12'h343, // mtval
      12'h7B0, // dcsr
      12'h7B1, // dpc
      12'h7B2: // dscratch0
        implemented = 1'b1;
      default:
        implemented = 1'b0;
    endcase
  end

  // Illegal if writing to read-only OR unimplemented CSR
  assign csr_illegal_o = csr_en & ( (is_readonly & write_attempt) | ~implemented );
endmodule
