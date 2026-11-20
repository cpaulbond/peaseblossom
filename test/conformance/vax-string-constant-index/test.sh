#!/bin/sh
. ../../testenv.sh
# doc/developer/language-extensions.md, "Indexing a string constant": a
# string constant indexed with a variable on the VAX. poc -emit-macro32's
# output for StringTables.mod against the reviewed expected-vax.mar,
# assembled on the VAX where the development system can be used
# (../../vaxfixture.sh). Then StringOut, built by the LLVM backend and run
# here, which must print output.expected; the same program built for the
# VAX and run there, under -O2 and -OC, is in test/vax-suite.list.
. ../../vaxfixture.sh
: >result
vax_mar StringTables
rm -f *.sym
poc -o vax-string-constant-index -build StringOut.mod >>result 2>&1
echo "LLVM build exit $?" >>result
./vax-string-constant-index >output 2>&1
echo "exit $?" >>output
cmp -s output output.expected || { echo "the LLVM backend's output:" >>result; diff output.expected output >>result; }
rm -f output
. ../../testresult.sh
