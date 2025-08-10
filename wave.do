onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /debug_tb/clk
add wave -noupdate -divider -height 32 "bsr"
add wave -noupdate -expand -group bsr /debug_tb/dut/clk
add wave -noupdate -expand -group bsr /debug_tb/dut/rst
add wave -noupdate -expand -group bsr /debug_tb/dut/tck
add wave -noupdate -expand -group bsr /debug_tb/dut/tms
add wave -noupdate -expand -group bsr /debug_tb/dut/tdi
add wave -noupdate -expand -group bsr /debug_tb/dut/tdo
add wave -noupdate -expand -group bsr /debug_tb/dut/dmi_req
add wave -noupdate -expand -group bsr /debug_tb/dut/dmi_rsp


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
