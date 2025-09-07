# ==== USER CONFIGURABLE VARIABLES ====
set project_name      "debugfpga"
set project_dir       "./$project_name"
set top_module_name   "top"                              ;# Must match module name inside the top .sv file
set part_name         "xc7a100tcsg324-1"                 ;# target FPGA part
set source_dirs       [list "./fpga" "./src"]  ;# HDL files
set xdc_file          "./fpga/Arty_Master.xdc"                ;# XDC constraint file

# ==== MMCM CONFIGURATION VARIABLES ====
set mmcm_ip_name      "mmcm0"                        ;# Name of the MMCM IP
set mmcm_input_freq   100.0                              ;# Input clock frequency (MHz)
set mmcm_output_freq  40.0                               ;# Desired output clock frequency (MHz)

# ==== CALCULATE MMCM PARAMETERS ====
# Ensure VCO frequency is within 600–1600 MHz
# f_VCO = f_CLKIN * M / D, f_OUT = f_VCO / O
# Set D = 1 for simplicity
set min_vco_freq 600.0
set mmcm_d 1.0
set mmcm_o [expr {ceil($min_vco_freq / $mmcm_output_freq)}]
set mmcm_m [expr {$mmcm_o * $mmcm_output_freq / $mmcm_input_freq}]
set vco_freq [expr {$mmcm_input_freq * $mmcm_m / $mmcm_d}]

# Validate MMCM parameters
if {$vco_freq < 600.0 || $vco_freq > 1600.0} {
    puts "ERROR: Calculated VCO frequency ($vco_freq MHz) is outside valid range (600–1600 MHz)."
    exit 1
}
if {$mmcm_m < 2.0 || $mmcm_m > 64.0} {
    puts "ERROR: Calculated multiplier M ($mmcm_m) is outside valid range (2–64)."
    exit 1
}
if {$mmcm_o < 1.0 || $mmcm_o > 128.0} {
    puts "ERROR: Calculated output divider O ($mmcm_o) is outside valid range (1–128)."
    exit 1
}

puts "MMCM Configuration: M=$mmcm_m, D=$mmcm_d, O=$mmcm_o, VCO=$vco_freq MHz"

# ==== CREATE PROJECT ====
if {[file exists "$project_dir/$project_name.xpr"]} {
    puts "ERROR: Project already exists at $project_dir/$project_name.xpr"
    exit 1
} else {
    file mkdir $project_dir
    create_project $project_name $project_dir -part $part_name -force
}

# ==== IMPORT SYSTEMVERILOG FILES FROM MULTIPLE DIRECTORIES ====
puts "Importing SystemVerilog files using managed flow..."
set added_files 0
foreach dir $source_dirs {
    puts "  Processing directory: $dir"
    set sv_files [glob -nocomplain "$dir/*.sv"]

    if {[llength $sv_files] == 0} {
        puts "    No .sv files found in $dir"
    } else {
        foreach f $sv_files {
            import_files -fileset sources_1 $f
            puts "    Imported: $f"
            incr added_files
        }
    }
}

import_files -fileset sources_1 "./riscv_pipe/riscv_pipelined2.sv"
import_files -fileset sources_1 "./src/include/debug.vh"
import_files -fileset sources_1 "./testing/riscvtest.mem"

if {$added_files == 0} {
    puts "ERROR: No SystemVerilog files found in specified directories."
    exit 1
}

# ==== IMPORT XDC CONSTRAINT FILE ====
if {[file exists $xdc_file]} {
    import_files -fileset constrs_1 $xdc_file
    puts "XDC file imported: $xdc_file"
} else {
    puts "WARNING: XDC file not found at $xdc_file. Skipping constraint file."
}

# ==== SET TOP MODULE ====
puts "Setting top module to: $top_module_name"
set_property top $top_module_name [current_fileset]

# ==== SET FILE TYPES TO SYSTEMVERILOG ====
foreach f [get_files -of_objects [get_filesets sources_1]] {
    if {[string match "*.sv" $f]} {
        set_property file_type SystemVerilog $f
    }
}

# ==== CREATE AND CONFIGURE MMCM USING CLOCKING WIZARD ====
puts "Creating MMCM IP ($mmcm_ip_name) for $mmcm_output_freq MHz output from $mmcm_input_freq MHz input..."
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $mmcm_ip_name
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ $mmcm_input_freq \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $mmcm_output_freq \
    CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
    CONFIG.MMCM_CLKFBOUT_MULT_F $mmcm_m \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F $mmcm_o \
    CONFIG.CLKOUT1_JITTER {130.0} \
    CONFIG.CLKOUT1_PHASE_ERROR {98.0} \
] [get_ips $mmcm_ip_name]

# Generate IP output products
generate_target all [get_ips $mmcm_ip_name]
puts "MMCM IP ($mmcm_ip_name) generated successfully."

# Import generated IP files into the project
import_files -fileset sources_1 [get_files -of_objects [get_ips $mmcm_ip_name] *.v]
puts "MMCM IP files imported into sources_1."

# ==== UPDATE COMPILE ORDER ====
update_compile_order -fileset sources_1

# ==== (OPTIONAL) RUN SYNTHESIS AND IMPLEMENTATION ====
launch_runs synth_1 -jobs 16
wait_on_run synth_1
launch_runs impl_1 - jobs 16
wait_on_run impl_1

launch_runs impl_1 -to_step write_bitstream -jobs 16

puts "Vivado project setup complete! Files are managed inside top.srcs"
