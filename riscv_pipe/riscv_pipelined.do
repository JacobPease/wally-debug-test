# Copyright 1991-2007 Mentor Graphics Corporation
# 
# Modification by Oklahoma State University
# Use with Testbench 
# James Stine, 2008
# Go Cowboys!!!!!!
#
# All Rights Reserved.
#
# THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION
# WHICH IS THE PROPERTY OF MENTOR GRAPHICS CORPORATION
# OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.

# Use this run.do file to run this example.
# Either bring up ModelSim and type the following at the "ModelSim>" prompt:
#     do run.do
# or, to run from a shell, type the following at the shell prompt:
#     vsim -do run.do -c
# (omit the "-c" to see the GUI while running from the shell)

onbreak {resume}

# create library
if [file exists work] {
    vdel -all
}
vlib work

# compile source files
vlog riscv_pipelined2.sv

# start and run simulation
vsim -debugdb -voptargs=+acc work.testbench

# view list
# view wave

# Load Decoding
do wave.do

set all_signals [find signals /testbench/dut/rv32pipe/dp/*]
# echo $all_signals

set signal_groups {}
foreach sig $all_signals {
    # Extract the base name by removing the stage suffix (F, D, E, M, W)
    set base_name [regsub {([FDEMW])$} [file tail $sig] ""]
    if {$base_name != ""} {
        # Add the signal to the group for this base name
        dict lappend signal_groups $base_name $sig
    }
}

set singletons {}
foreach key [dict keys $signal_groups] {
	 set value [dict get $signal_groups $key]
	 if {[llength $value] == 1} {
		  lappend singletons $value
		  dict unset signal_groups $key
	 }
}

foreach group $signal_groups {
	 echo $group
}

-- display input and output signals as hexidecimal values
# Diplays All Signals recursively
# add wave -hex -r /stimulus/*
add wave -noupdate -divider -height 32 "Top"
add wave -hex /testbench/dut/*
add wave -noupdate -divider -height 32 "Instructions"
add wave -noupdate -expand -group Instructions /testbench/dut/rv32pipe/reset
add wave -noupdate -expand -group Instructions -color {Orange Red} /testbench/dut/rv32pipe/PCF
add wave -noupdate -expand -group Instructions -color Orange /testbench/dut/rv32pipe/InstrF
add wave -noupdate -expand -group Instructions -color Orange -radix Instructions /testbench/dut/rv32pipe/InstrF
add wave -noupdate -expand -group Instructions -color Orange /testbench/dut/rv32pipe/dp/InstrF
add wave -noupdate -expand -group Instructions -color Orange -radix Instructions /testbench/dut/rv32pipe/dp/InstrF
add wave -noupdate -divider -height 32 "CSR"
add wave -hex /testbench/dut/rv32pipe/csr0/*
add wave -noupdate -divider -height 32 "Datapath"
# add wave -hex /testbench/dut/rv32pipe/dp/*F
# add wave -hex /testbench/dut/rv32pipe/dp/*D
# add wave -hex /testbench/dut/rv32pipe/dp/*E
# add wave -hex /testbench/dut/rv32pipe/dp/*M
# add wave -hex /testbench/dut/rv32pipe/dp/*W
foreach sig $singletons {
	 add wave $sig
}
foreach key [dict keys $signal_groups] {
	 foreach sig [dict get $signal_groups $key] {
		  add wave -noupdate -expand -group $key $sig
	 }
}

add wave -noupdate -divider -height 32 "ALU"
add wave -hex /testbench/dut/rv32pipe/dp/alu/*
add wave -noupdate -divider -height 32 "Hazard Detection Unit"
add wave -hex /testbench/dut/rv32pipe/hu/*
add wave -noupdate -divider -height 32 "Branch Unit"
add wave -hex /testbench/dut/rv32pipe/c/branchunit/*
add wave -noupdate -divider -height 32 "Control"
add wave -hex /testbench/dut/rv32pipe/c/*
add wave -noupdate -divider -height 32 "Main Decoder"
add wave -hex /testbench/dut/rv32pipe/c/md/*
add wave -noupdate -divider -height 32 "ALU Decoder"
add wave -hex /testbench/dut/rv32pipe/c/ad/*
add wave -noupdate -divider -height 32 "Data Memory"
add wave -hex /testbench/dut/dmem/*
add wave -noupdate -divider -height 32 "Instruction Memory"
add wave -hex /testbench/dut/imem/*
add wave -noupdate -divider -height 32 "Register File"
add wave -hex /testbench/dut/rv32pipe/dp/rf/*
add wave -hex /testbench/dut/rv32pipe/dp/rf/rf

# wave sort
# wave sort ascending

-- Set Wave Output Items 
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ps} {200 ns}
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

-- Run the Simulation
run 18000 ns

-- Add schematic
add schematic -full sim:/testbench/dut/rv32pipe

-- Save memory for checking (if needed)
# mem save -outfile dmemory.dat -wordsperline 1 /testbench/dut/dmem/RAM
# mem save -outfile imemory.dat -wordsperline 1 /testbench/dut/imem/RAM
quit
