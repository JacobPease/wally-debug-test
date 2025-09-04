`include "debug.vh"
`timescale 10ns/1ns
module debug_tb;
   // Want the period of clk over the period of tck to not be an
   // integer. This will test the synchronizer.
   int tcktime = 52;

   // DTM Signals
   logic clk, rst;
   logic tck, tms, tdi, tdo;
   dmi_req_t dmi_req;
   dmi_rsp_t dmi_rsp;

   // DM Signals
   logic NDMReset;
   logic HaltReq;
   logic ResumeReq;
   logic DebugMode;
   logic DebugControl;
   logic CSRDebugEnable;

   // Debug Register Access
   logic [31:0] RegIn;
   logic [31:0] RegOut;
   logic [11:0] RegAddr;
   logic        DebugRegWrite;

   // CPU Signals
   logic [31:0] WriteDataM, DataAdrM;
   logic        MemWriteM;
   logic [31:0] PCF, InstrF, ReadDataM;

   // ----------------------------------------------------------------
   // DUT
   // ----------------------------------------------------------------
   // Debug Transport Module
   dtm dtm (clk, rst, tck, tms, tdi, tdo,
      dmi_req, dmi_rsp);

   // The Debug Module
   dm debugmodule (clk, rst, dmi_req,
      dmi_rsp, NDMReset, HaltReq, ResumeReq, DebugMode, DebugControl, CSRDebugEnable,
      RegIn, RegOut, RegAddr, DebugRegWrite
   );
   
   // instantiate processor and memories
   riscv rv32pipe (clk, rst, PCF, InstrF, MemWriteM, DataAdrM, 
		   WriteDataM, ReadDataM, HaltReq, ResumeReq, DebugMode, DebugControl, CSRDebugEnable,
         RegIn, RegOut, RegAddr, DebugRegWrite
   );
   imem #("testing/riscvtestCSR.memfile") imem (PCF, InstrF);
   dmem dmem (clk, MemWriteM, DataAdrM, WriteDataM, ReadDataM);

   // ----------------------------------------------------------------
   // System clock
   // ----------------------------------------------------------------
   initial begin
      tck = 1'b1;
      clk = 1'b1;
      forever #10 clk = ~clk; 
   end

   // ----------------------------------------------------------------
   //  Write instruction task.
   // ----------------------------------------------------------------

   // Changing the instructions happens so infrequently that we need
   // only make a single task for this. The only time we may need to
   // revisit this after initializing is if we need to set DMIReset if
   // we encounter the sticky error in the DMI.

   // Task for writing instructions to the DTM
   task write_instr(input logic [4:0] INST);
      logic [11:0] tms_seq;
      logic [11:0] tdi_seq;
      begin
         tms_seq = {4'b0110, 5'b0, 3'b110};
         // Reverse instruction so LSB is first
         tdi_seq = {5'b0, {<<{INST}}, 2'b0};

         // Clock should be idling high, TMS should be low keeping
         // us in the Run-test/Idle state and the input should not
         // be driven.
         tck = 1;
         tms = 0;
         tdi = 0;
            
         // SelectIR -> CaptureIR -> ShiftIR
         for (int i = 11; i >= 0; i--) begin
            #(tcktime) tck = ~tck; // low
            tms = tms_seq[i];
            tdi = tdi_seq[i];
            #(tcktime) tck = ~tck; // high
         end
      end   
   endtask // instr

   // ----------------------------------------------------------------
   // Classes
   // ----------------------------------------------------------------
   
   // JTAG_DR Class that generalizes the task of reading and writing
   // to the Test Data Regisers. 
   class JTAG_DR #(parameter WIDTH = 32);
      logic [WIDTH-1:0] result;
      
      task read();
         logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
         for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
            #(tcktime) tck = ~tck; 
            tdi = 0;
            tms = tms_seq[i];
            if ((i < WIDTH + 2) && (i >= 2)) begin               
               this.result[WIDTH - i + 2-1] = tdo;
            end
            #(tcktime) tck = ~tck;
         end
      endtask // read

      task write(input logic [WIDTH-1:0] val);
         logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
         for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
            #(tcktime) tck = ~tck; 
            tms = tms_seq[i];
            if ((i < WIDTH + 2) && (i >= 2)) begin
               tdi = val[WIDTH - i + 2-1];
            end
            this.result[WIDTH - i + 2-1] = tdo;
            #(tcktime) tck = ~tck;
         end
      endtask
   endclass
   
   // Debug Module Interface Abstraction.
   // TODO: Can probably be further abstracted with a Debugger class
   class DMI extends JTAG_DR #(41);
      //logic [40:0] result;
      // DMControl = 0x10
      task read_dmcontrol();
         this.write({7'h10, 32'h0000_0000, 2'b01});
         this.write({7'h10, 32'h0000_0000, 2'b00});
      endtask

      task write_dmcontrol(input logic [31:0] data);
         this.write({7'h10, data, 2'b10});
      endtask

      // DMStatus = 0x11
      task read_dmstatus();
         this.write({7'h11, 32'h0000_0000, 2'b01});
         this.write({7'h11, 32'h0000_0000, 2'b00});
      endtask

      // Command = 0x17
      task read_command();
         this.write({7'h17, 32'h0000_0000, 2'b01});
      endtask

      task write_command(input logic [31:0] data);
         this.write({7'h17, data, 2'b10});
      endtask

      // AbstractCS = 0x16
      task read_abstractcs();
         this.write({7'h16, 32'h0000_0000, 2'b01});
         this.write({7'h16, 32'h0000_0000, 2'b00});
      endtask

      task write_abstractcs(input logic [31:0] data);
         this.write({7'h16, data, 2'b10});
      endtask

      // DATA0 = 0x04
      task read_data0();
         this.write({7'h04, 32'h0000_0000, 2'b01});
         this.write({7'h04, 32'h0000_0000, 2'b00});
      endtask

      task write_data0(input logic [31:0] data);
         this.write({7'h04, data, 2'b10});
      endtask
      
   endclass


   // Debugger Class
   
   /* This class is special. It simulates what the debugger is
    * supposed to do as outlined in the RISC-V Debug Specification.
    *
    * - Debugger.initialize():
    *   This initializes the Debug Module by setting DMActive high
    *   then polling for the the setting to take effect.
    *
    * - Debugger.halt():
    *   This sets haltreq high and polls for the halting to have taken
    *   effect in DMStatus before deasserting haltreq.
    *
    * - Debugger.resume():
    *   Sets resumereq high and polls DMStatus for when the processor
    *   resumes.
    *   
    * - Debugger.readreg(regno):
    *   Reads a GPR of the user's choice
    * 
    * - Debugger.readcsr():
    *   
    */
   
   class Debugger;
      // Primary JTAG Registers
      JTAG_DR #(32) idcode;
      JTAG_DR #(32) dtmcs;
      DMI dmireg;

      // For running testvectors instead of the encapsulated tests.
      logic [40:0] testvectors[$];
      logic [40:0] expected_outputs[$];
      
      function new();
         idcode = new();
         dtmcs = new();
         dmireg = new();
      endfunction
      
      // Confirm the DTM is working 
      task initialize();
         write_instr(5'b00001);
         this.idcode.read();
         assert(this.idcode.result == 32'h1002AC05) $display("Received IDCODE");
         else $display("IDCODE was corrupted.");

         // Reading DTMCS value
         write_instr(5'b10000);
         this.dtmcs.read();
         assert(this.dtmcs.result == 32'h00100071) $display("DTMCS properly captures default value. dtmcs = 0x%8h", this.dtmcs.result);
         else $display("Something is wrong with DTMCS on reset and capture: dtmcs = 0x%0h", this.dtmcs.result);

         // Set instruction DMI
         write_instr(5'b10001);
      endtask

      task init_dm();
         // Set DMActive
         this.dmireg.write_dmcontrol(32'h0000_0001);
         this.dmireg.read_dmcontrol();
         assert(this.dmireg.result[33:2] == 32'h0000_0001) $display("DMActive was set");
         else $display("Failed to write to DMActive");

         // Read DMControl
         this.dmireg.read_dmcontrol();
         assert(this.dmireg.result[33:2] == 32'h0000_0001) $display("DMControl: 0x%8h, CORRECT", this.dmireg.result[33:2]);
         else $display("DMControl = 0x%8h, FAILED", this.dmireg.result[33:2]);

         // Read AbstractCS
         this.dmireg.read_abstractcs();
         assert(this.dmireg.result[33:2] == 32'h0000_0001) $display("AbstractCS: 0x%8h, CORRECT", this.dmireg.result[33:2]);
         else $display("AbstractCS: 0x%8h, FAILED", this.dmireg.result[33:2]);
      endtask
      
      // Halt the processor, and confirm halted
      task halt();
         this.dmireg.read_dmcontrol();
         this.dmireg.write_dmcontrol(32'h8000_0000 | this.dmireg.result);
         this.dmireg.read_dmstatus();
         // 0000_0000_0000_0000_0000_0011_0000_0000
         // 00000300
         assert(|(this.dmireg.result[33:2] & 32'h0000_0300)) $display("Hart Halted. DMStatus = 0x%8h, CORRECT", this.dmireg.result[33:2]);
         else $display("Hart not halted. DMStatus = 0x%8h, FAILED", this.dmireg.result[33:2]);

         this.dmireg.read_dmcontrol();
         this.dmireg.write_dmcontrol(32'h7fff_ffff & this.dmireg.result);
         this.dmireg.read_dmcontrol();

         assert(|(this.dmireg.result[33:2] & 32'h8000_0000) == 0) $display("Haltreq de-asserted. DMControl = 0x%8h, CORRECT", this.dmireg.result[33:2]);
         else $display("Haltreq NOT de-asserted. DMControl = 0x%8h, FAILED", this.dmireg.result[33:2]);
      endtask

      // Resume the processor, and confirm resume
      task resume();
         this.dmireg.read_dmcontrol();
         this.dmireg.write_dmcontrol(32'h4000_0000 | this.dmireg.result);

         this.dmireg.read_dmstatus();
         assert(|(this.dmireg.result[33:2] & 32'h0000_0c00)) $display("Hart resumed! DMStatus = 0x%8h, CORRECT", this.dmireg.result[33:2]);
         else $display("Hart not resumed. DMStatus = 0x%8h, FAILED", this.dmireg.result[33:2]);

         this.dmireg.read_dmcontrol();
         this.dmireg.write_dmcontrol(32'hbfff_ffff & this.dmireg.result);
         this.dmireg.read_dmcontrol();
         
         assert(|(this.dmireg.result[33:2] & 32'h4000_0000) == 0) $display("Resumereq de-asserted. DMControl = 0x%8h, CORRECT", this.dmireg.result[33:2]);
         else $display("Resumereq NOT de-asserted. DMControl = 0x%8h, FAILED", this.dmireg.result[33:2]);
      endtask

      task command(input logic [31:0] cmd);
         this.dmireg.write_command(cmd);
         this.dmireg.read_data0();
         $display("COMMAND: Data0:\n  op: 0b%2b,\n  data: 0x%8h,\n  addr: 0x%2h", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
      endtask

      task read_abstractcs();
         this.dmireg.read_abstractcs();
         $display("AbstractCS: op: 0b%2b, data: 0x%8h, addr: 0x%2h", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
      endtask

      task readreg(input logic [4:0] regno);
         // 32'h0020_0301
         this.dmireg.write_command({16'h0022, 11'b0001_0000_000, regno});
         this.dmireg.read_data0();
         $display("GPR: Data0:\n  op: 0b%2b,\n  data: 0x%8h,\n  addr: 0x%2h", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
      endtask

      task readcsr(input logic [11:0] regno);
         this.dmireg.write_command({16'h0022, 4'b0, regno});
         this.read_abstractcs();
         this.dmireg.read_data0();
         $display("CSR: Data0 =\n  op: 0b%2b,\n  data: 0x%8h,\n  addr: 0x%2h\n", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
      endtask

      // TESTVECTOR READING. Reading testvectors grabbed from openocd.log
      function void get_testvectors(string filename);
         string line;
         string items[$];
         int    file = $fopen(filename, "r");
         
         while (!$feof(file)) begin
            if ($fgets(line, file)) begin
               items = split(line, " "); 
               this.testvectors.push_back({items[2].substr(1, 2).atohex(), items[1].atohex(), op_decode(items[0], 0)});
               this.expected_outputs.push_back({items[6].substr(1, 2).atohex(), items[5].atohex(), op_decode(items[4], 1)});
            end
         end

         // foreach (this.testvectors[i]) begin
         //    $display("testvector[%0d]:\n  addr: %2h, data: %8h, op: %2b", i, this.testvectors[i][40:34], this.testvectors[i][33:2], this.testvectors[i][1:0]);
         // end
         
      endfunction

      task run_testvectors();
         foreach (testvectors[i]) begin
            this.dmireg.write(testvectors[i]);
            assert(this.dmireg.result == expected_outputs[i]) begin 
               $display("Simulation matches FPGA.");
            end else begin 
               $display("FAILED: Simulation does not match FPGA.");
               $display("  Expected[%0d] = addr: %2h, data: %8h, op: %2b", i, this.testvectors[i][40:34], this.testvectors[i][33:2], this.testvectors[i][1:0]);
               $display("  Actual[%0d] =  addr: %2h, data: %8h, op: %2b", i, this.dmireg.result[40:34], this.dmireg.result[33:2], this.dmireg.result[1:0]);
            end
         end
      endtask
      
   endclass

   // ----------------------------------------------------------------
   // Load CPU RAM with test
   // ----------------------------------------------------------------
   
   // Initialize CPU
   initial begin
	   string memfilename;
	   string dmemfilename;
      memfilename = {"./testing/riscvtest.memfile"};
      $readmemh(memfilename, imem.RAM);
      $readmemh(memfilename, dmem.RAM);	
   end

   // ----------------------------------------------------------------
   // THE TESTS
   // ----------------------------------------------------------------

   // Debug Commands
   initial begin
      JTAG_DR #(32) idcode = new();
      JTAG_DR #(32) dtmcs = new();
      DMI dmireg = new();
      Debugger debugger = new();
  
      rst = 0;
      tms = 1;
      @(negedge clk) tms = 0; rst = 1;
      @(negedge clk) rst = 0;

      debugger.initialize();
      // debugger.init_dm();
      // debugger.halt();
      // debugger.readreg(5'b00101);
      // debugger.resume();
      // debugger.halt();
      // debugger.command(32'h0032_1008);
      // debugger.read_abstractcs();
      // debugger.readcsr(12'h301);
      // debugger.read_abstractcs();

      debugger.get_testvectors("./testvectors1.tv");
      debugger.run_testvectors();
      
      #(tcktime*100) $stop;
   end
    
endmodule

typedef string stringarr[];
   
// No native split function in System Verilog. Coming up with a way
// of doing this natively for better testvector parsing.
function automatic stringarr split(string str, string delimiter);
   string result[$];
   int    strlen = str.len();
   string temp = "";
   for (int i = 0; i <= strlen; i++) begin
      if (str[i] == delimiter[0] || (i == strlen && temp.len() != 0) || str[i] == "\n") begin
         result.push_back(temp);
         temp = "";
      end else begin
         temp = {temp, str[i]};
      end
   end
   return result;
endfunction

function automatic logic [1:0] op_decode(string op_str, logic response);
   if (response) begin
      if (op_str == "+") begin
         return 2'b00;
      end else if (op_str == "b") begin
         return 2'b11;
      end else begin
         return 2'b01; // reserved
      end
   end else begin
      if (op_str == "r") begin
         return 2'b01;
      end else if (op_str == "w") begin
         return 2'b10;
      end else if (op_str == "-") begin
         return 2'b00;
      end else begin
         return 2'b11;
      end
   end
   return 2'b00;
endfunction
