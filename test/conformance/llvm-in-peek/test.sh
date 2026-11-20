#!/bin/sh
. ../../testenv.sh
# PLAN.md "Ongoing library enhancements", item 8: In.Peek. peek.mod peeks
# and reads standard input: Peek then Char on the same byte, Peek twice,
# Peek at a line end and before Line and Int, a 0X byte (Done TRUE), and
# Peek at the end of the input (Done FALSE). The input is made here, since
# it holds a 0X byte; it has no line end after its last line.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
printf 'ab\n  second line\n\000z\n  42\nlast' >input.txt
poc -o llvm-in-peek -build peek.mod >result 2>&1
./llvm-in-peek <input.txt >>result
rm -f input.txt
. ../../testresult.sh
