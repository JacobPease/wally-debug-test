# Dynamically recompile only the files that have changed
proc recompile_project {library_file_list last_compiled inc_list} {
    set inc_dirs [pre_append_elements $inc_list {+incdir+}]
    foreach {library file_list} $library_file_list {
        vlib $library
        vmap work $library
        foreach f $file_list {
            if {$last_compiled < [file mtime $f]} {
                vlog {*}${inc_dirs} -lint $f
            }
        }
    }
    return [clock seconds]
}

proc pre_append_elements {inlist appendstring} {
    set result {}
    foreach el $inlist {
        lappend result [join [list $appendstring $el] ""]
    }
    return $result
}

proc post_append_elements {inlist appendstring} {
    set result {}
    foreach el $inlist {
        lappend result [join [list $el $appendstring] ""]
    }
    return $result
}

# Get vopt library arguments
proc get_libraries {library_file_list} {
    set libs {}
    foreach {library file_list} $library_file_list {
        lappend libs -Lf $library
    }
    return $libs
}
