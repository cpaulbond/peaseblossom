#!/bin/sh
. ../../testenv.sh
# Tasks (doc/developer/tasks.md, Phase 10): sleeps end in the order of
# their lengths and last at least as long as asked; a sleeper wakes while
# another task only yields; Sleep(0); After in a Select, After(0), and a
# closed After. Under both size models.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
poc_build_run time.mod
echo "== -OC" >>result
poc -OC -o llvm-tasks-time-oc -build time.mod >>result 2>&1
./llvm-tasks-time-oc >>result 2>&1
printf 'exit=%d\n' "$?" >>result
rm -f *.sym llvm-tasks-time-oc
. ../../testresult.sh
