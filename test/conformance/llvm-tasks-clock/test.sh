#!/bin/sh
. ../../testenv.sh
# PLAN.md, "Ongoing bug fixing", 24: Platform.GetClock's first call, in a
# 16 KiB task, under the local zone and under TZ set to another; it
# overran the task's stack on NetBSD amd64 and OpenBSD i386.
unset POC_IMPORT_PATH
rm -rf work && mkdir work && cd work || exit 1
rtl=../../../../rtl/llvm
poc -import-path $rtl -o clock -build ../clock.mod >../result 2>&1
./clock >>../result 2>&1
printf 'exit=%d\n' "$?" >>../result
TZ=Europe/London ./clock >>../result 2>&1
printf 'exit=%d\n' "$?" >>../result
cd ..
rm -rf work
. ../../testresult.sh
