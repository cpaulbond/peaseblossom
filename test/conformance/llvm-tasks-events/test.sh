#!/bin/sh
. ../../testenv.sh
# Tasks (doc/developer/tasks.md, Phase 10): events posted by a SIGINT
# handler, beside sleeps and a pipe read by AwaitReadable; the signals
# alone; a ready pipe beside a task that only yields; AwaitWritable. The
# child processes are part/ChildProcesses.Mod's, in C. Under both size
# models.
unset POC_IMPORT_PATH
rm -rf work && mkdir work && cd work || exit 1
rtl=../../../../rtl/llvm
poc -import-path $rtl -import-path ../part -o events -build ../events.mod >../result 2>&1
./events >>../result 2>&1
printf 'exit=%d\n' "$?" >>../result
echo "== -OC" >>../result
rm -f *.sym *.o *.ll
poc -OC -import-path $rtl -import-path ../part -o events-oc -build ../events.mod >>../result 2>&1
./events-oc >>../result 2>&1
printf 'exit=%d\n' "$?" >>../result
cd ..
rm -rf work
. ../../testresult.sh
