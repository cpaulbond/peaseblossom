#!/bin/sh
# Bug 30: a module or procedure whose name is not an identifier, closed
# by an END that names one, is reported, not a NIL pointer dereference;
# three stray tokens (or a UTF-8 byte order mark) before MODULE parse
# that way
. ../../testenv.sh
for f in unnamed-module unnamed-procedure stray-tokens byte-order-mark; do
  poc -check-syntax $f.mod
  echo "exit $?"
done >result 2>&1
. ../../testresult.sh
