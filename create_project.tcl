create_project project0 project -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
add_files -norecurse -scan_for_includes {rtl/execute1.vhdl rtl/decode2.vhdl rtl/insn_helpers.vhdl rtl/register_file.vhdl rtl/helpers.vhdl rtl/fpu.vhdl rtl/predecode.vhdl rtl/xilinx-mult.vhdl rtl/plrufn.vhdl rtl/divider.vhdl rtl/soc.vhdl rtl/core_debug.vhdl rtl/icache.vhdl rtl/logical.vhdl rtl/cache_ram.vhdl rtl/dcache.vhdl rtl/fetch1.vhdl rtl/wishbone_types.vhdl rtl/microwatt_wrapper.v rtl/bitsort.vhdl rtl/s_wb_2_m_axi_lite.v rtl/xilinx-mult-32s.vhdl rtl/cr_file.vhdl rtl/mmu.vhdl rtl/decode1.vhdl rtl/pmu.vhdl rtl/loadstore1.vhdl rtl/common.vhdl rtl/countbits.vhdl rtl/wishbone_arbiter.vhdl rtl/ppc_fx_insns.vhdl rtl/nonrandom.vhdl rtl/crhelpers.vhdl rtl/core.vhdl rtl/decode_types.vhdl rtl/xics.vhdl rtl/control.vhdl rtl/microwatt_zynq_top.vhdl rtl/s_axi_lite.v rtl/utils.vhdl rtl/rotator.vhdl rtl/writeback.vhdl}
add_files -fileset sim_1 -norecurse -scan_for_includes {sim/m_wb.v sim/testbench_2.v sim/testbench_1.v sim/s_axi_lite_sim.v}
import_files -force -norecurse
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
create_bd_design "design_1"
update_compile_order -fileset sources_1
set_property file_type {VHDL 2008} [get_files -all *.vhdl]
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list \
  CONFIG.PSU__IRQ_P2F_ENT3__INT {1} \
  CONFIG.PSU__IRQ_P2F_SDIO1__INT {1} \
  CONFIG.PSU__IRQ_P2F_UART0__INT {1} \
  CONFIG.PSU__USE__IRQ0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
] [get_bd_cells zynq_ultra_ps_e_0]
create_bd_cell -type module -reference microwatt_wrapper microwatt_wrapper_0
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave {/microwatt_wrapper_0/s_axi} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins microwatt_wrapper_0/s_axi]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/microwatt_wrapper_0/m_axi} Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
endgroup
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/ps_pl_irq_enet3] [get_bd_pins microwatt_wrapper_0/ext_irq_eth]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/ps_pl_irq_uart0] [get_bd_pins microwatt_wrapper_0/ext_irq_uart0]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/ps_pl_irq_sdio1] [get_bd_pins microwatt_wrapper_0/ext_irq_sdcard]
set_property range 128 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_microwatt_wrapper_0_reg0}]
set_property offset 0x00A0000000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_microwatt_wrapper_0_reg0}]
validate_bd_design
make_wrapper -files [get_files project/project0.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse project/project0.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1
save_bd_design
generate_target all [get_files  project/project0.srcs/sources_1/bd/design_1/design_1.bd]
catch { config_ip_cache -export [get_ips -all design_1_zynq_ultra_ps_e_0_0] }
catch { config_ip_cache -export [get_ips -all design_1_axi_smc_0] }
catch { config_ip_cache -export [get_ips -all design_1_rst_ps8_0_100M_0] }
catch { config_ip_cache -export [get_ips -all design_1_axi_smc_1_0] }
export_ip_user_files -of_objects [get_files project/project0.srcs/sources_1/bd/design_1/design_1.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] project/project0.srcs/sources_1/bd/design_1/design_1.bd]
launch_runs design_1_axi_smc_0_synth_1 design_1_axi_smc_1_0_synth_1 design_1_microwatt_wrapper_0_0_synth_1 design_1_rst_ps8_0_100M_0_synth_1 design_1_zynq_ultra_ps_e_0_0_synth_1
export_simulation -lib_map_path [list {modelsim=project/project0.cache/compile_simlib/modelsim} {questa=project/project0.cache/compile_simlib/questa} {xcelium=project/project0.cache/compile_simlib/xcelium} {vcs=project/project0.cache/compile_simlib/vcs} {riviera=project/project0.cache/compile_simlib/riviera}] -of_objects [get_files project/project0.srcs/sources_1/bd/design_1/design_1.bd] -directory project/project0.ip_user_files/sim_scripts -ip_user_files_dir project/project0.ip_user_files -ipstatic_source_dir project/project0.ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
write_hw_platform -fixed -include_bit -force -file project/design_1_wrapper.xsa
