#!/bin/sh
. ../../testenv.sh
# PLAN.md, "Ongoing library enhancements", 7: StopRequests, under both
# size models; the last SIGINT ends the program, so its status is 130.
unset POC_IMPORT_PATH
rm -rf work && mkdir work && cd work || exit 1
rtl=../../../../rtl/llvm
: >../result
for model in -O2 -OC; do
  echo "== $model" >>../result
  poc $model -import-path $rtl -o stop -build ../stop.mod >>../result 2>&1
  ./stop >>../result 2>&1
  printf 'exit=%d\n' "$?" >>../result
done
cd ..
rm -rf work
. ../../testresult.sh
