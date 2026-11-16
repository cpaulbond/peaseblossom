#!/bin/sh
. ../../testenv.sh
# Tasks' time on VAX/VMS (doc/developer/tasks.md, Phase 10): the program
# of llvm-tasks-time, renamed and its sleeps ten times as long (the
# system clock ticks every 10 ms), and an event posted by the AST of a
# Timers.After (rtl/vax/vmslib) while another task sleeps. Built by poc
# -build in work/ from the runtime's, vmslib's and STARLET's sources, with
# -link COROUTINESWITCH.OBJ and SYS.STB, and run on the guest (vax_do), both ways
# (vax_build).
. ../../vaxfixture.sh
rtl=../../../../rtl/vax
modules="TaskTimes Tasks TaskWaiting Coroutines GarbageCollectedHeap AsynchronousTraps STARLET Timers Platform Out LineOutput FormattedOutput FormattedText RealDigits"
written=
for m in $modules; do written="$written work/$m.mar"; done
: >result
builds() {
rm -rf work
mkdir work
cp TaskTimes.mod work/
(cd work && poc -target vax-dec-vms $vax_way_option -import-path $rtl -import-path $rtl/vmslib \
  -import-path $rtl/vms -link COROUTINESWITCH.OBJ -link 'SYS$SYSTEM:SYS.STB/SELECTIVE_SEARCH' -build TaskTimes.mod) >>result 2>&1
echo "VAX build exit $?" >>result
vax_do guest-run.com guest-run.expected work/TaskTimes.com $written \
  ../../../rtl/vax/PocRtl.mar ../../../rtl/vax/CoroutineSwitch.mar
}
vax_build builds
rm -rf work
. ../../testresult.sh
