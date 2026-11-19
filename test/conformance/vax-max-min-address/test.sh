#!/bin/sh
. ../../testenv.sh
# Bug 27: MAX(SYSTEM.ADDRESS) and MIN(SYSTEM.ADDRESS) were refused ("MAX/MIN
# requires a basic type or SET"). On the VAX they are the bounds of a
# longword: the MOVLs that store them in poc's MACRO-32. A fixture of its
# own because make check-opt2 runs llvm-max-min-address with -opt 2, which
# -target vax-dec-vms refuses.
rm -rf work
mkdir work
: >result
cp AddressBounds.mod work/
(cd work && poc -target vax-dec-vms -vax-macro32 AddressBounds.mod) >>result 2>&1
echo "exit $?" >>result
grep -E 'MOVL' work/AddressBounds.mar >>result
rm -rf work
. ../../testresult.sh
