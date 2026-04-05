quit -sim
file delete -force work

vlib work

vlog -f files_rtl.f -f files_sim.f +incdir+../rtl +incdir+../svas/ +define+INCLUDE_SVAS

# In case of AXI4_master_cdc.sv use, uncomment the following line.
# vlog -f files_pulp.f +incdir+../rtl/pulp/include +incdir+../rtl

vopt +acc tb -o tbopt
vsim tbopt -onfinish "stop"

log -r /*
do wave.do
onbreak {wave zoom full}
#run -all
wave zoom full
