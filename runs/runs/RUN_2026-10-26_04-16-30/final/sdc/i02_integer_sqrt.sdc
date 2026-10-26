###############################################################################
# Created by write_sdc
###############################################################################
current_design i02_integer_sqrt
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 10.0000 [get_ports {clk}]
set_propagated_clock [get_clocks {clk}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rst_n}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {start}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[0]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[1]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[2]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[3]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[4]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[5]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[6]}]
set_input_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {x[7]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {busy}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {done}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {root[0]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {root[1]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {root[2]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -add_delay [get_ports {root[3]}]
###############################################################################
# Environment
###############################################################################
###############################################################################
# Design Rules
###############################################################################
