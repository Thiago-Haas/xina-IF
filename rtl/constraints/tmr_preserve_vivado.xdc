# Vivado TMR preservation constraints
# Add this file to your Vivado project constraints set.

# Preserve TMR wrapper hierarchy/cells.
set tmr_cells [get_cells -hier -filter {NAME =~ *tmr* || REF_NAME =~ *_tmr*}]
if {[llength $tmr_cells] > 0} {
  set_property DONT_TOUCH true $tmr_cells
  set_property KEEP_HIERARCHY true $tmr_cells
}

# Preserve generated replica instances commonly used across this project.
set tmr_replica_cells [get_cells -hier -regexp {.*\/(u_CTRL|u_ctrl|u_obs_ctrl|u_PACKETIZER_CONTROL|u_DEPACKETIZER_CONTROL|u_SEND_CONTROL|u_RECEIVE_CONTROL)$}]
if {[llength $tmr_replica_cells] > 0} {
  set_property DONT_TOUCH true $tmr_replica_cells
  set_property KEEP_HIERARCHY true $tmr_replica_cells
}

# Keep TMR inter-replica/voter nets from being collapsed.
# Scope only nets inside paths that include "tmr".
set tmr_nets [get_nets -hier -filter {NAME =~ *tmr*/*_w*}]
if {[llength $tmr_nets] > 0} {
  # KEEP helps preserve net structure; DONT_TOUCH prevents optimization away.
  set_property KEEP true $tmr_nets
  set_property DONT_TOUCH true $tmr_nets
}
