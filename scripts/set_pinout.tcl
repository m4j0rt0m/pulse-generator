#============================================================
# OPEN PROJECT
#============================================================
# Set the project name
set project_name "[lindex $argv 0]"
# Open the Project. If it does not already exist, create it
if [catch {project_open $project_name}] {project_new $project_name}

#============================================================
# CLOCK AND RESET
#============================================================
set_location_assignment PIN_R8 -to clk_i
set_location_assignment PIN_M1 -to arstn_i
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_i
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to arstn_i

#============================================================
# FREQ STEP CONTROL
#============================================================
set_location_assignment PIN_J15 -to freq_up_i
set_location_assignment PIN_E1 -to freq_dwn_i
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to freq_up_i
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to freq_dwn_i

#============================================================
# LED
#============================================================
set_location_assignment PIN_A15 -to led_o
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led_o

#============================================================
# UNUSED PINS TO TRI-STATE
#============================================================
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

#============================================================
# CLOSE PROJECT
#============================================================
project_close
qexit -success

