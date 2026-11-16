#!/bin/sh
. ../../testenv.sh
# The User's Guide's task examples on VAX/VMS (doc/developer/tasks.md,
# Phase 12): Primes and Clock, from doc/examples/tasks, unchanged, built
# by poc -build in work/ with -link COROUTINESWITCH.OBJ and SYS.STB (as
# vax-coroutines-examples is) and run on the guest as foreign commands,
# both ways (vax_build): Primes with the guide's counts, Clock with
# commands from a file and from a mailbox ClockFeeder.mod writes at the
# guide's times. What they print is what they print on Unix
# (doc-users-guide checks the guide's runs there).
. ../../vaxfixture.sh
rtl=../../../../rtl/vax
examples=../../../doc/examples/tasks
modules="Primes Clock ClockFeeder Tasks TaskWaiting TaskInput Coroutines GarbageCollectedHeap Platform LineOutput FormattedInput DecimalToReal Modules Args Out FormattedOutput FormattedText RealDigits"
written=
for m in $modules; do written="$written work/$m.mar"; done
: >result
builds() {
rm -rf work
mkdir work
cp $examples/Primes.Mod $examples/Clock.Mod ClockFeeder.mod work/
(cd work &&
  for program in Primes.Mod Clock.Mod; do
    poc -target vax-dec-vms $vax_way_option -import-path $rtl \
      -link COROUTINESWITCH.OBJ -link 'SYS$SYSTEM:SYS.STB/SELECTIVE_SEARCH' -build $program || exit 1
  done &&
  poc -target vax-dec-vms $vax_way_option -import-path $rtl -build ClockFeeder.mod) >>result 2>&1
echo "VAX build exit $?" >>result
vax_do guest-run.com guest-run.expected work/Primes.com work/Clock.com work/ClockFeeder.com \
  commands.txt $written ../../../rtl/vax/PocRtl.mar ../../../rtl/vax/CoroutineSwitch.mar
}
vax_build builds
rm -rf work
. ../../testresult.sh
