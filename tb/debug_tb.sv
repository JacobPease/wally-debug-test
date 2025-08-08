`include "debug.vh"
`timescale 10ns/1ns
module debug_tb;
    int tcktime = 52;
    
    logic clk, rst;
    logic tck, tms, tdi, tdo;
    dmi_t dmi_req;
    dmi_rsp_t dmi_rsp;

    dtm dut(
        clk, rst,
        tck, tms, tdi, tdo,
        dmi_req,
        dmi_rsp
    );

    initial begin
        tck = 1'b1;
        clk = 1'b1;
        forever #10 clk = ~clk; 
    end

    // Set of tasks to automate communicating over JTAG.
    task write_instr(input logic [4:0] INST);
        // logic [] tms_seq;
        logic [4:0] tms_begin_seq; 
        logic [2:0] tms_end_seq;
        logic [11:0] tms_seq;
        logic [11:0] tdi_seq;
        begin
            tms_seq = {4'b0110, 5'b0, 3'b110};
            // Reverse instruction so LSB is first
            tdi_seq = {5'b0, {<<{INST}}, 2'b0};
            //tms_begin_seq = 5'b01100;
            //tms_end_seq = 3'b110;

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
                
            // tms = 0;
            // // Instruction Shifting 
            // for (int i = 4; i >= 0; i--) begin
            //     #(tcktime) tck = ~tck; 
            //     tdi = INST[i];
            //     #(tcktime) tck = ~tck;
            // end
                
            // tdi = 0;
            // for (int i = 2; i >= 0; i--) begin
            //     #(tcktime) tck = ~tck;
            //     tms = tms_end_seq[i];
            //     #(tcktime) tck = ~tck;
            // end          
            // tms = 0;
        end   
    endtask // instr

    task read_datareg(output logic [32:0] result);
        logic [3:0] tms_begin_seq; 
        logic [2:0] tms_end_seq;
        begin
            tms_begin_seq = 4'b0100;
            tms_end_seq = 3'b110;

            // SelectDR -> CaptureDR -> ShiftDR
            for (int i = 3; i >= 0; i--) begin
                #(tcktime) tck = ~tck; // low
                tms = tms_begin_seq[i];
                #(tcktime) tck = ~tck; // high
            end

            for (int i = 0; i < 32; i++) begin
                #(tcktime) tck = ~tck; 
                tdi = 0;
                result[i] = tdo;
                #(tcktime) tck = ~tck;
            end

            // SelectDR -> CaptureDR -> ShiftDR
            for (int i = 2; i >= 0; i--) begin
                #(tcktime) tck = ~tck; // low
                tms = tms_end_seq[i];
                #(tcktime) tck = ~tck; // high
            end 
        end
    endtask

     
    
    // Want the period of clk over the period of tck to not be an
    // integer. This will test the synchronizers.
    // initial begin
    //     tck = 1'b1;
    //     forever #52 tck = ~tck;
    // end

    // Main test block
    initial begin
        logic [31:0] data;
        rst = 0;
        tms = 1;
        @(posedge clk) tms = 0; rst = 1;
        @(negedge clk) rst = 0;

        // Read IDCODE
        write_instr(5'b00001);
        read_datareg(data);
        assert(data == 32'h1002AC05);
        $finish;
    end
    
endmodule

