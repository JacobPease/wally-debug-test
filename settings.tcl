set last_compiled_file last_compiled.txt

set include_dir_list {
    ./src/include
}

set library_file_list [list \
	 design_library [glob -nocomplain ./src/*.sv ./riscv_pipe/riscv_pipelined2.sv] \
    test_library   [glob -nocomplain ./tb/*.sv]
]

set top_module test_library.debug_tb
