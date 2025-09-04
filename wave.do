radix define DMADDR {
	 "7'h04" "DATA0"             
	 "7'h05" "DATA1"            
	 "7'h06" "DATA2"            
	 "7'h07" "DATA3"            
	 "7'h08" "DATA4"            
	 "7'h09" "DATA5"            
	 "7'h0a" "DATA6"            
	 "7'h0b" "DATA7"            
	 "7'h0c" "DATA8"            
	 "7'h0d" "DATA9"            
	 "7'h0e" "DATA10"          
	 "7'h0f" "DATA11"          
	 "7'h10" "DMCONTROL"    
	 "7'h11" "DMSTATUS"      
	 "7'h12" "HARTINFO"      
	 "7'h40" "HALTSUM0"      
	 "7'h13" "HALTSUM1"      
	 "7'h17" "COMMAND"       
	 "7'h16" "ABSTRACTCS"  
	 "7'h18" "ABSTRACTAUTO"
}


onerror {resume}
quietly WaveActivateNextPane {} 0

# Original recursive add
# add wave -hex -r /stimulus/*

add wave -color gold -noupdate /debug_tb/clk
add wave -color gold -noupdate /debug_tb/rst
add wave -noupdate -divider -height 32 "Top"
add wave -noupdate -expand -group Top /debug_tb/*
add wave sim:/@Debugger@1.dmireg.super.result

add wave -noupdate -divider -height 32 "dtm"
add wave -noupdate -expand -group dtm /debug_tb/dtm/*
add wave -noupdate -expand -group dtm -radix DMADDR /debug_tb/dtm/dmi_req.addr

add wave -noupdate -divider -height 32 "dm"
add wave -noupdate -expand -group dm /debug_tb/debugmodule/*

add wave -noupdate -divider -height 32 "CSR"
add wave -hex /debug_tb/rv32pipe/csr0/*
add wave -noupdate -divider -height 32 "CSR Regs"
add wave -hex /debug_tb/rv32pipe/csr0/mstatus
add wave -hex /debug_tb/rv32pipe/csr0/mtvec
add wave -hex /debug_tb/rv32pipe/csr0/mepc
add wave -hex /debug_tb/rv32pipe/csr0/mcause
add wave -hex /debug_tb/rv32pipe/csr0/mtval
add wave -hex /debug_tb/rv32pipe/csr0/dcsr
add wave -hex /debug_tb/rv32pipe/csr0/dpc
add wave -hex /debug_tb/rv32pipe/csr0/dscratch0
add wave -hex /debug_tb/rv32pipe/csr0/misa

add wave -noupdate -divider -height 32 "Instructions"
add wave -noupdate -expand -group Instructions -color Orange /debug_tb/rv32pipe/*

add wave -noupdate -divider -height 32 "Datapath"
add wave -hex /debug_tb/rv32pipe/dp/*

add wave -noupdate -divider -height 32 "Control"
add wave -hex /debug_tb/rv32pipe/c/*

add wave -noupdate -divider -height 32 "Main Decoder"
add wave -hex /debug_tb/rv32pipe/c/md/*

add wave -noupdate -divider -height 32 "ALU Decoder"
add wave -hex /debug_tb/rv32pipe/c/ad/*

add wave -noupdate -divider -height 32 "Data Memory"
add wave -hex /debug_tb/dmem/*

add wave -noupdate -divider -height 32 "Instruction Memory"
add wave -hex /debug_tb/imem/*

add wave -noupdate -divider -height 32 "Register File"
add wave -hex /debug_tb/rv32pipe/dp/rf/*
add wave -hex /debug_tb/rv32pipe/dp/rf/rf


TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2028326 ns} 0} {{Cursor 2} {4831 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 245
configure wave -valuecolwidth 180
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
#WaveRestoreZoom {1979107 ns} {2077545 ns}
