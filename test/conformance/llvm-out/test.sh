#!/bin/sh
. ../../testenv.sh
# outtest uses only what poc's Out shares with voc's, so both compilers must
# print the same thing (llvm-out-extra has the rest). voc runs first and its
# symbol files go before poc starts: poc leaves Out.sym and Console.sym in
# the working directory, which voc would find and reject as not its own.
# Another voc's Out may differ (5.3.0's Hex takes no digit count): then
# poc's output is checked against expected alone.
if voc_is_reference; then
  voc outtest.mod -m >/dev/null
  ./outtest >voc-output
  rm -f *.c *.h *.o *.sym outtest
else
  echo "SKIPPED: comparing outtest with voc's (voc is not 2.1.0)"
fi

# Out and Console are rtl modules: poc finds them through the import path
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
poc_build_run outtest.mod
cat result >poc-output
if voc_is_reference; then
  cmp -s poc-output voc-output || echo "poc and voc disagree on outtest" >>result
fi
rm -f poc-output voc-output
. ../../testresult.sh
