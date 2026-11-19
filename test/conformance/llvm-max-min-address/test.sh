#!/bin/sh
. ../../testenv.sh
# Bug 27: MAX(SYSTEM.ADDRESS) and MIN(SYSTEM.ADDRESS) were refused ("MAX/MIN
# requires a basic type or SET"). They are the bounds of a signed integer as
# wide as a pointer on the target. On this host: against the bounds reached
# by doubling, and as constants exported through a .sym file. Then the
# values each target gets: the constants in the .sym files for a 32-bit
# and a 64-bit target. vax-max-min-address has the VAX's.
: >result
rm -f *.sym
poc -o llvm-max-min-address -build MaxMinAddress.mod >>result 2>&1
echo "build exit $?" >>result
./llvm-max-min-address >>result 2>&1
echo "exit $?" >>result
for target in i686-unknown-linux-gnu x86_64-unknown-linux-gnu
do
  echo "### $target" >>result
  poc -target $target -emit-llvm-ir AddressBounds.mod >/dev/null 2>&1
  grep -E '^ *(max|min)\*' AddressBounds.sym >>result
done
rm -f *.sym *.ll *.o
. ../../testresult.sh
