onbreak {resume}

# Variables 
source settings.tcl
source compile.tcl

# If this is the first time initializing this project
# Set this variable
if {![file exists $last_compiled_file]} {
    set last_compiled 0
} else {
    set fd [open $last_compiled_file r]
    gets $fd last_compiled
    close $fd
}

echo $library_file_list

# Initial compiling. If there are no changes since last project start
# this will do nothing but update the last_compiled variable
set fd [open $last_compiled_file w]
set last_compiled [recompile_project $library_file_list $last_compiled $include_dir_list]
puts $fd $last_compiled
close $fd

vopt {*}[get_libraries $library_file_list] +acc $top_module -o testbenchopt
vsim testbenchopt

if [file exists wave.do] {
    do wave.do
} else {
    add wave -r /*
}

run -all

# Functions for recompiling after project is loaded
proc r {} {
    global last_compiled_file include_dir_list library_file_list top_module

    # Get last_compiled time
    set fd [open $last_compiled_file r]
    gets $fd last_compiled
    close $fd

    # Recompile
    set last_compiled [recompile_project $library_file_list $last_compiled $include_dir_list]

    # Write last_compiled time to file
    set fd [open $last_compiled_file w]
    puts $fd $last_compiled
    close $fd

    # Resimulate
    vopt {*}[get_libraries $library_file_list] +acc $top_module -o testbenchopt
    vsim testbenchopt

    noview wave
    if [file exists wave.do] {
        do wave.do
    } else {
        add wave -r /*
    }
    
    run -all
}

proc q {} {
    quit -force
}
