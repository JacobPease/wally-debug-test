`include "debug.vh"

module top #(parameter IMEM_INIT_FILE="./testing/riscvtest.memfile") (
   // jtag logic
   (* mark_debug = "true" *) input logic  tck,tdi,tms,trst,
   (* mark_debug = "true" *) output logic tdo,
    
   // dut logic
   input logic sysclk,
   (* mark_debug = "true" *) input logic  sys_reset
);
   // DTM Signals
   (* mark_debug = "true" *) dmi_req_t dmi_req;
   (* mark_debug = "true" *) dmi_rsp_t dmi_rsp;

   // DM Signals
   (* mark_debug = "true" *) logic NDMReset;
   (* mark_debug = "true" *) logic HaltReq;
   (* mark_debug = "true" *) logic ResumeReq;
   (* mark_debug = "true" *) logic DebugMode;
   (* mark_debug = "true" *) logic DebugControl;

   // Debug Register Access
   (* mark_debug = "true" *) logic [31:0] RegIn;
   (* mark_debug = "true" *) logic [31:0] RegOut;
   (* mark_debug = "true" *) logic [4:0]  RegAddr;
   (* mark_debug = "true" *) logic        DebugRegWrite;

   // CPU Signals
   (* mark_debug = "true" *) logic [31:0] WriteDataM, DataAdrM;
   (* mark_debug = "true" *) logic        MemWriteM;

   (* mark_debug = "true" *) logic [31:0] 	       PCF, InstrF, ReadDataM;
   
   dtm dtm (sysclk, sys_reset, tck, tms, tdi, tdo,
      dmi_req, dmi_rsp);

   dm debugmodule (sysclk, sys_reset, dmi_req,
      dmi_rsp, NDMReset, HaltReq, ResumeReq, DebugMode, DebugControl,
      RegIn, RegOut, RegAddr, DebugRegWrite
   );
   
   // instantiate processor and memories
   riscv rv32pipe (sysclk, sys_reset, PCF, InstrF, MemWriteM, DataAdrM, 
		   WriteDataM, ReadDataM, HaltReq, ResumeReq, DebugMode, DebugControl,
         RegIn, RegOut, RegAddr, DebugRegWrite
   );
   imem #(IMEM_INIT_FILE) imem (PCF, InstrF);
   dmem dmem (sysclk, MemWriteM, DataAdrM, WriteDataM, ReadDataM);

endmodule
