#!/bin/sh
. ../../testenv.sh
# Tasks (doc/developer/tasks.md, Phase 10): a replaced idle step gets the
# time to the nearest timer, -1 when there is none, and is not called while
# a task is ready; a Post from the step wakes the awaiting task; NIL
# restores Tasks' own wait. Under both size models.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
poc_build_run idle.mod
echo "== -OC" >>result
poc -OC -o llvm-tasks-idle-oc -build idle.mod >>result 2>&1
./llvm-tasks-idle-oc >>result 2>&1
printf 'exit=%d\n' "$?" >>result
rm -f *.sym llvm-tasks-idle-oc
. ../../testresult.sh
