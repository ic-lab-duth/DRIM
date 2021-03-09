quit -sim
file delete -force work

vlib work

vlog -f files_rtl.f -f files_sim.f +incdir+../rtl +incdir+../svas/ +define+INCLUDE_SVAS

#vsim -novopt work.tb -onfinish "stop"
# Option -novopt deprecated in newer versions
vsim -voptargs="+acc" tb -onfinish "stop"

log -r /*
do wave.do
onbreak {wave zoom full}
#run -all
wave zoom full
