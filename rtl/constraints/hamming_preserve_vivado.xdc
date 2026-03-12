# Vivado ECC/Hamming preservation constraints
# Add this file to your Vivado project constraints set.

# Preserve every hamming register instance and hierarchy.
set ham_regs [get_cells -hier -filter {REF_NAME =~ hamming_register*}]
if {[llength $ham_regs] > 0} {
  set_property DONT_TOUCH true $ham_regs
  set_property KEEP_HIERARCHY true $ham_regs
}

# Preserve encoder/decoder cells used by hamming_register.
set ham_codec [get_cells -hier -filter {REF_NAME =~ hamming_encoder* || REF_NAME =~ hamming_decoder*}]
if {[llength $ham_codec] > 0} {
  set_property DONT_TOUCH true $ham_codec
  set_property KEEP_HIERARCHY true $ham_codec
}

# Keep key ECC nets from being collapsed.
set ham_nets [get_nets -hier -filter {NAME =~ *hamming*/*}]
if {[llength $ham_nets] > 0} {
  set_property KEEP true $ham_nets
  set_property DONT_TOUCH true $ham_nets
}
