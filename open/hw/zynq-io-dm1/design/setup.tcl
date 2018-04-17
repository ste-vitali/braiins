####################################################################################################
# Copyright (c) 2018 Braiins Systems s.r.o.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
####################################################################################################

####################################################################################################
# Procedure for printing state of script run with timestamp
proc timestamp {arg} {
    puts ""
    puts [string repeat "-" 80]
    puts "[clock format [clock seconds] -format %H:%M:%S:] $arg"
    puts [string repeat "-" 80]
}

####################################################################################################
# CHECK INPUT ARGUMENTS
####################################################################################################
# check number of arguments
if {$argc == 1} {
    set board [lindex $argv 0]
} else {
    puts "ERROR: Wrong number of TCL arguments! Expected 1 argument, get $argc"
    puts "List of arguments: $argv"
    exit 1
}

# check name of the board
if {$board == "G9"} {
    set vid_width 1
} elseif {($board == "G19") || ($board == "G29")} {
    set vid_width 6
} else {
    puts "ERROR: Unknown board: $board"
    puts "List of supported boards: G9, G19, G29"
    exit 1
}

####################################################################################################
# Preset global variables and attributes
####################################################################################################
# Project name
set project "Zynq IO"

# Design name
set design "system"

# Device name
set partname "xc7z010clg400-1"

# Define number of parallel jobs
set jobs 8

# Project directory
set projdir "./build_$board"

# Paths to all IP blocks to use in Vivado "system.bd"
set ip_repos [ list \
    "$projdir" \
]

# Set source files
set hdl_files [ \
]

# Set synthesis and implementation constraints files
set constraints_files [list \
    "src/constrs/pin_assignment.tcl" \
]

####################################################################################################
# Set name of top module
set top_module "system_wrapper"

####################################################################################################
# Generate build ID information
####################################################################################################
# get timestamp
set build_id [clock seconds]
set date_time [clock format $build_id -format "%d.%m.%Y %H:%M:%S"]

puts [string repeat "-" 80]
puts "Project:  $project"
puts "Board:    $board"
puts "Build ID: ${build_id} (${date_time})"

####################################################################################################
# Run synthesis, P&R and bitstream generation
####################################################################################################
# Create new project and generate block design of system
source "system_init.tcl"

# Run synthesis, implementation and bitstream generation
source "system_build.tcl"

####################################################################################################
# Exit Vivado
####################################################################################################
# Generate build history file, backup of build directory, print statistics
source "system_final.tcl"