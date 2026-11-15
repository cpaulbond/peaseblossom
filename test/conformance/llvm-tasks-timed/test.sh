#!/bin/sh
. ../../testenv.sh
# Tasks (doc/developer/tasks.md, decision 15): AwaitReadableFor and
# AwaitWritableFor time out, no sooner than asked, or end when the pipe
# is ready, taking the task out of the timers or the descriptors; waits
# of several lengths on one pipe; a time that is not positive. The pipes
# are part/Pipes.Mod's, in C. Under both size models.
unset POC_IMPORT_PATH
rm -rf work && mkdir work && cd work || exit 1
rtl=../../../../rtl/llvm
poc -import-path $rtl -import-path ../part -o timed -build ../timed.mod >../result 2>&1
./timed >>../result 2>&1
printf 'exit=%d\n' "$?" >>../result
echo "== -OC" >>../result
rm -f *.sym *.o *.ll
poc -OC -import-path $rtl -import-path ../part -o timed-oc -build ../timed.mod >>../result 2>&1
./timed-oc >>../result 2>&1
printf 'exit=%d\n' "$?" >>../result
cd ..
rm -rf work
. ../../testresult.sh
