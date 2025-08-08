`include "debug.vh"
`timescale 10ns/1ns
module debug_tb;
    // Want the period of clk over the period of tck to not be an
    // integer. This will test the synchronizers.
    int tcktime = 52;

    // DTM Signals
    logic clk, rst;
    logic tck, tms, tdi, tdo;
    dmi_t dmi_req;
    dmi_rsp_t dmi_rsp;

    // Dummy Debug Module FSM states
    enum logic {IDLE, WAIT} DMState;
    
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

    // JTAG_DR Class that generalizes the task of reading and writing
    // to the Test Data Regisers. 
    class JTAG_DR #(parameter WIDTH = 32);
        task read(output logic [WIDTH-1:0] result);
            logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
            for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
                #(tcktime) tck = ~tck; 
                tdi = 0;
                tms = tms_seq[i];
                if ((i < WIDTH + 2) && (i >= 2))
                    result[WIDTH - i + 2-1] = tdo;
                #(tcktime) tck = ~tck;
            end
        endtask // read

        task write(input logic [WIDTH-1:0] val, output logic [WIDTH-1:0] result);
            logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
            for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
                #(tcktime) tck = ~tck; 
                tms = tms_seq[i];
                if ((i < WIDTH + 2) && (i >= 2))
                    tdi = val[WIDTH - i + 2-1];
                    result[WIDTH - i + 2-1] = tdo;
                #(tcktime) tck = ~tck;
            end
        endtask
    endclass

    always @(posedge clk) begin
        if (rst) begin
            DMState <= IDLE;
            dmi_rsp.data = 32'h0;
            dmi_rsp.op = 2'b0;
            dmi_rsp.ack = 1'b0;
        end else begin
            case(DMState)
                IDLE: begin
                    if (dmi_req.op == RD | dmi_req.op == WR) begin
                        DMState <= WAIT;
                    end
                end
              
                WAIT: begin
                    #(tcktime * 6)
                    dmi_rsp.data <= 32'hdeadbeef;
                    dmi_rsp.op <= 2'b0;
                    dmi_rsp.ack <= 1'b1;
                    
                    #(tcktime)
                    dmi_rsp.data <= 32'h0;
                    dmi_rsp.ack <= 1'b0;
                    DMState <= IDLE;
                end
              default: DMState <= IDLE;
            endcase
        end
    end
    
    // Want the period of clk over the period of tck to not be an
    // integer. This will test the synchronizers.
    initial begin
        JTAG_DR #(32) idcode = new;
        JTAG_DR #(32) dtmcs = new;
        JTAG_DR #(32 + 2 + 7) dmireg = new;

        logic [31:0] idcode_result;
        logic [31:0] dtmcs_result;
        logic [32+2+7-1:0] dmi_result;
        
        rst = 0;
        tms = 1;
        @(posedge clk) tms = 0; rst = 1;
        @(negedge clk) rst = 0;

        // Read IDCODE
        write_instr(5'b00001);
        idcode.read(idcode_result);
        assert(idcode_result == 32'h1002AC05) $display("Received IDCODE");
        else $display("IDCODE was corrupted.");

        // Reading DTMCS value
        write_instr(5'b10000);
        dtmcs.read(dtmcs_result);
        assert(dtmcs_result == 32'h00100071) $display("DTMCS properly captures default value.");
        else $display("Something is wrong with DTMCS on reset and capture: dtmcs = 0x%0h", dtmcs_result);

        // Reading current DMI value.
        write_instr(5'b10001);
        dmireg.write(32'h1, dmi_result);

        #(tcktime*10)

        dmireg.write(32'h0, dmi_result);

        assert(dmi_result[33:2] == 32'hdeadbeef) $display("DMI seems to be working.");
        else $display("Something went horribly wrong with the DMI: dmi = 0x%0h", dmi_result);
        
        $stop;
    end
    
endmodule
