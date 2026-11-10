# EDGE ZYNQ hardware for PetaLinux (Vivado 2022.2, batch mode)
# Invent Logics / allaboutfpga.com
#
#   vivado -mode batch -source edge_linux_hw.tcl -tclargs <part> <work dir> <output dir>
#   part: xc7z010clg400-1 (EDGE ZYNQ Z7-10) or xc7z020clg400-1 (EDGE ZYNQ Z7-20)
#
# Processing system with the EDGE ZYNQ settings (ps7_config.tcl, the same as the PYNQ image:
# 33.333 MHz clock, DDR3, UART0, microSD, Ethernet with MDIO, USB0, QSPI), plus AXI GPIO for
# the user LEDs, slide switches and push buttons so they can be used from Linux.
# Output: edge_zynq.xsa (with the bitstream) and edge_zynq.bit.

set part   [lindex $argv 0]
set work   [file normalize [lindex $argv 1]]
set outdir [file normalize [lindex $argv 2]]
set here   [file dirname [file normalize [info script]]]
file mkdir $work $outdir

proc ipv {name {vendor xilinx.com:ip}} {
    set d [lindex [lsort [get_ipdefs -all ${vendor}:${name}:*]] end]
    if {$d eq ""} { error "IP $vendor:$name not found" }
    return $d
}

create_project -force edge_zynq $work -part $part
set_property target_language Verilog [current_project]
add_files -fileset constrs_1 -norecurse $here/edge_linux.xdc
create_bd_design edge_zynq

# ---------------------------------------------------------------- processing system
source $here/ps7_config.tcl
set ps [create_bd_cell -type ip -vlnv [ipv processing_system7] processing_system7_0]
if {[catch {set_property -dict $edge_ps7_config $ps} e]} {
    puts "EDGE_WARN ps7 settings as one set failed ($e), setting them one by one"
    for {set pass 0} {$pass < 3} {incr pass} {
        set nbad 0
        foreach {k v} $edge_ps7_config { if {[catch {set_property $k $v $ps}]} { incr nbad } }
    }
    puts "EDGE_PS7 settings not accepted: $nbad"
}
foreach k {PCW_CRYSTAL_PERIPHERAL_FREQMHZ PCW_UIPARAM_DDR_PARTNO PCW_UIPARAM_DDR_BUS_WIDTH PCW_UIPARAM_DDR_FREQ_MHZ
           PCW_UART0_PERIPHERAL_ENABLE PCW_UART0_UART0_IO PCW_SD0_PERIPHERAL_ENABLE PCW_SD0_GRP_CD_IO
           PCW_ENET0_PERIPHERAL_ENABLE PCW_ENET0_ENET0_IO PCW_ENET0_GRP_MDIO_IO PCW_ENET0_RESET_ENABLE
           PCW_USB0_PERIPHERAL_ENABLE PCW_USB0_RESET_IO PCW_QSPI_PERIPHERAL_ENABLE
           PCW_FPGA0_PERIPHERAL_FREQMHZ PCW_APU_PERIPHERAL_FREQMHZ PCW_USE_M_AXI_GP0 PCW_USE_FABRIC_INTERRUPT PCW_IRQ_F2P_INTR} {
    puts "EDGE_PS7 $k = [get_property CONFIG.$k $ps]"
}
make_bd_intf_pins_external [get_bd_intf_pins $ps/DDR] [get_bd_intf_pins $ps/FIXED_IO]
set_property name DDR [get_bd_intf_ports DDR_0]
set_property name FIXED_IO [get_bd_intf_ports FIXED_IO_0]

set rst [create_bd_cell -type ip -vlnv [ipv proc_sys_reset] rst_ps7_0_100M]
connect_bd_net [get_bd_pins $ps/FCLK_CLK0] [get_bd_pins $rst/slowest_sync_clk]
connect_bd_net [get_bd_pins $ps/FCLK_RESET0_N] [get_bd_pins $rst/ext_reset_in]

# ---------------------------------------------------------------- board I/O
set leds [create_bd_cell -type ip -vlnv [ipv axi_gpio] leds_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 4 CONFIG.C_ALL_OUTPUTS 1] $leds
set sws [create_bd_cell -type ip -vlnv [ipv axi_gpio] switches_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 4 CONFIG.C_ALL_INPUTS 1 CONFIG.C_INTERRUPT_PRESENT 1] $sws
set btns [create_bd_cell -type ip -vlnv [ipv axi_gpio] btns_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 2 CONFIG.C_ALL_INPUTS 1 CONFIG.C_INTERRUPT_PRESENT 1] $btns
foreach {cell port} {leds_gpio leds switches_gpio sws btns_gpio btns} {
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 $port
    connect_bd_intf_net [get_bd_intf_pins $cell/GPIO] [get_bd_intf_ports $port]
}

# ---------------------------------------------------------------- AXI
set slaves [list $leds $sws $btns]
set ic [create_bd_cell -type ip -vlnv [ipv axi_interconnect] ps7_0_axi_periph]
set_property -dict [list CONFIG.NUM_MI [llength $slaves] CONFIG.NUM_SI 1] $ic
connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_GP0] [get_bd_intf_pins $ic/S00_AXI]
set clk [get_bd_pins $ps/FCLK_CLK0]
set arstn [get_bd_pins $rst/peripheral_aresetn]
connect_bd_net $clk [get_bd_pins $ps/M_AXI_GP0_ACLK] [get_bd_pins $ic/ACLK] [get_bd_pins $ic/S00_ACLK]
connect_bd_net [get_bd_pins $rst/interconnect_aresetn] [get_bd_pins $ic/ARESETN]
connect_bd_net $arstn [get_bd_pins $ic/S00_ARESETN]
set i 0
foreach s $slaves {
    set m [format %02d $i]
    connect_bd_intf_net [get_bd_intf_pins $ic/M${m}_AXI] [get_bd_intf_pins $s/S_AXI]
    connect_bd_net $clk [get_bd_pins $ic/M${m}_ACLK] [get_bd_pins $s/s_axi_aclk]
    connect_bd_net $arstn [get_bd_pins $ic/M${m}_ARESETN] [get_bd_pins $s/s_axi_aresetn]
    incr i
}

# ---------------------------------------------------------------- interrupts (straight to the PS, IRQ_F2P 0 and 1)
set cat [create_bd_cell -type ip -vlnv [ipv xlconcat] irq_concat]
set_property CONFIG.NUM_PORTS 2 $cat
connect_bd_net [get_bd_pins $sws/ip2intc_irpt] [get_bd_pins $cat/In0]
connect_bd_net [get_bd_pins $btns/ip2intc_irpt] [get_bd_pins $cat/In1]
connect_bd_net [get_bd_pins $cat/dout] [get_bd_pins $ps/IRQ_F2P]

# ---------------------------------------------------------------- addresses (the same as the PYNQ base overlay)
set space [get_bd_addr_spaces processing_system7_0/Data]
foreach {cell base} {leds_gpio 0x41200000 switches_gpio 0x41210000 btns_gpio 0x41220000} {
    assign_bd_address -offset $base -range 0x00010000 -target_address_space $space \
        [get_bd_addr_segs -of_objects [get_bd_cells $cell]] -force
}
foreach s [get_bd_addr_segs -quiet processing_system7_0/Data/*] { puts "EDGE_ADDR $s [get_property offset $s] [get_property range $s]" }

validate_bd_design
save_bd_design
set wrapper [make_wrapper -files [get_files edge_zynq.bd] -top]
add_files -norecurse $wrapper
set_property top edge_zynq_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ---------------------------------------------------------------- build
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { puts "EDGE_RESULT FAIL implementation"; exit 1 }
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "EDGE_WNS $wns"
report_utilization -file $outdir/utilization.txt
file copy -force [glob $work/edge_zynq.runs/impl_1/*.bit] $outdir/edge_zynq.bit
write_hw_platform -fixed -include_bit -force -file $outdir/edge_zynq.xsa
puts "EDGE_RESULT OK $part wns=$wns"
exit 0
