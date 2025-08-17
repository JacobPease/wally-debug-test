onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate /debug_tb/clk

add wave -noupdate -divider -height 32 "Top"
add wave -hex /testbench/dut/*
add wave -noupdate -divider -height 32 "bsr"
add wave -noupdate -expand -group bsr /debug_tb/dut/clk
add wave -noupdate -expand -group bsr /debug_tb/dut/rst
add wave -noupdate -expand -group bsr /debug_tb/dut/tck
add wave -noupdate -expand -group bsr /debug_tb/dut/tms
add wave -noupdate -expand -group bsr /debug_tb/dut/tdi
add wave -noupdate -expand -group bsr /debug_tb/dut/tdo
add wave -noupdate -expand -group bsr /debug_tb/dut/dmi_req
add wave -noupdate -expand -group bsr /debug_tb/dut/dmi_rsp
add wave -noupdate -divider -height 32 "Instructions"
add wave -noupdate -expand -group Instructions /testbench/dut/rv32single/reset
add wave -noupdate -expand -group Instructions -color {Orange Red} /testbench/dut/rv32single/PC
add wave -noupdate -expand -group Instructions -color Orange /testbench/dut/rv32single/Instr
add wave -noupdate -expand -group Instructions -color Orange -radix Instructions /testbench/dut/rv32single/Instr
add wave -noupdate -expand -group Instructions -color Orange /testbench/dut/rv32single/dp/Instr
add wave -noupdate -expand -group Instructions -color Orange -radix Instructions /testbench/dut/rv32single/dp/Instr
add wave -noupdate -divider -height 32 "Datapath"
add wave -hex /testbench/dut/rv32single/dp/*
add wave -noupdate -divider -height 32 "Control"
add wave -hex /testbench/dut/rv32single/c/*
add wave -noupdate -divider -height 32 "Main Decoder"
add wave -hex /testbench/dut/rv32single/c/md/*
add wave -noupdate -divider -height 32 "ALU Decoder"
add wave -hex /testbench/dut/rv32single/c/ad/*
add wave -noupdate -divider -height 32 "Data Memory"
add wave -hex /testbench/dut/dmem/*
add wave -noupdate -divider -height 32 "Instruction Memory"
add wave -hex /testbench/dut/imem/*
add wave -noupdate -divider -height 32 "Register File"
add wave -hex /testbench/dut/rv32single/dp/rf/*
add wave -hex /testbench/dut/rv32single/dp/rf/rf


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
