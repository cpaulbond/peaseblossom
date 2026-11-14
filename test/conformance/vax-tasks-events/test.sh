#!/bin/sh
. ../../testenv.sh
# Tasks' events on VAX/VMS (doc/developer/tasks.md, Phase 10): Phase
# 7.3's probe made to compare output (TaskEvents.mod), with a mailbox
# TASKWRITER.COM writes from a subprocess, read by $QIOs whose ASTs post,
# and events posted by $SETIMR's and $DCLAST's ASTs. Built by poc -build
# in work/ with -link COROUTINESWITCH.OBJ and run on the guest (vax_do),
# both ways (vax_build).
. ../../vaxfixture.sh
rtl=../../../../rtl/vax
modules="TaskEvents Tasks TaskWaiting Coroutines GarbageCollectedHeap Out LineOutput FormattedOutput FormattedText RealDigits"
written=
for m in $modules; do written="$written work/$m.mar"; done
: >result
builds() {
rm -rf work
mkdir work
cp TaskEvents.mod work/
(cd work && poc -target vax-dec-vms $vax_way_option -import-path $rtl \
  -link COROUTINESWITCH.OBJ -build TaskEvents.mod) >>result 2>&1
echo "VAX build exit $?" >>result
vax_do guest-run.com guest-run.expected work/TaskEvents.com $written \
  TASKWRITER.COM ../../../rtl/vax/PocRtl.mar ../../../rtl/vax/CoroutineSwitch.mar
}
vax_build builds
rm -rf work
. ../../testresult.sh
