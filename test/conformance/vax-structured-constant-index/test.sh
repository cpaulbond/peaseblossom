#!/bin/sh
. ../../testenv.sh
# PLAN.md, "Ongoing bug fixing", bug 31: a structured constant indexed
# with a variable on the VAX. poc -emit-macro32's output for
# ConstTables.mod against the reviewed expected-vax.mar, assembled on the
# VAX where the development system can be used (../../vaxfixture.sh). Then
# TableOut, built by the LLVM backend and run here, which must print
# output.expected; the same program built for the VAX and run there, under
# -O2 and -OC, is in test/vax-suite.list.
. ../../vaxfixture.sh
: >result
vax_mar ConstTables
rm -f *.sym
poc -o vax-structured-constant-index -build TableOut.mod >>result 2>&1
echo "LLVM build exit $?" >>result
./vax-structured-constant-index >output 2>&1
echo "exit $?" >>output
cmp -s output output.expected || { echo "the LLVM backend's output:" >>result; diff output.expected output >>result; }
rm -f output
. ../../testresult.sh
