#!/bin/sh
. ../../testenv.sh
# TaskInput on VAX/VMS (doc/developer/tasks.md, Phase 11): TaskReadIn.mod
# reads SYS$INPUT by TaskInput from disk files and NL: (read by RMS) and
# from a mailbox TaskFeeder.mod makes, spawning TaskReadIn with the
# mailbox as its input and writing it slowly (read by $QIO, a ticker task
# running meanwhile), with an empty message and one longer than
# TaskInput's buffer. Built by poc -build in work/ and run on the guest
# (vax_do), both ways (vax_build). The terminal is vax-tasks-terminal's.
. ../../vaxfixture.sh
rtl=../../../../rtl/vax
modules="TaskReadIn TaskFeeder TaskInput Tasks TaskWaiting Coroutines GarbageCollectedHeap Platform LineOutput FormattedInput DecimalToReal Out FormattedOutput FormattedText RealDigits"
written=
for m in $modules; do written="$written work/$m.mar"; done
: >result
builds() {
rm -rf work
mkdir work
cp TaskReadIn.mod TaskFeeder.mod work/
(cd work && poc -target vax-dec-vms $vax_way_option -import-path $rtl \
  -link COROUTINESWITCH.OBJ -link 'SYS$SYSTEM:SYS.STB/SELECTIVE_SEARCH' -build TaskReadIn.mod &&
  poc -target vax-dec-vms $vax_way_option -import-path $rtl -build TaskFeeder.mod) >>result 2>&1
echo "VAX build exit $?" >>result
vax_do guest-run.com guest-run.expected work/TaskReadIn.com work/TaskFeeder.com $written \
  ../../../rtl/vax/PocRtl.mar ../../../rtl/vax/CoroutineSwitch.mar
}
vax_build builds
rm -rf work
. ../../testresult.sh
