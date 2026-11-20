#!/bin/sh
. ../../testenv.sh
# PLAN.md, "Ongoing bug fixing", 32: a constant selection from a local,
# an imported and a re-exported structured constant, of each basic type
# and through one and two indexes, is folded to its value. The run prints
# the values; the IR check counts, in each procedure, the references to
# a module's copy of a structured constant (-const.) and the index checks
# (icmp sge and slt): none in Folded, some in Copied.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
exe=$(basename "$PWD")
poc -o "$exe" -build main.mod >result 2>&1
"./$exe" >>result 2>&1
poc -emit-llvm-ir main.mod >/dev/null 2>&1
for proc in Folded Copied
do
  awk -v proc="$proc" '
    $0 ~ "^define .*@main\\." proc "\\(" { inside = 1 }
    inside && /-const\./ { consts++ }
    inside && /icmp s(ge|lt) / { checks++ }
    inside && /^}/ { inside = 0 }
    END { printf "%s: -const. %s, index checks %s\n", proc, (consts > 0 ? "used" : "none"), (checks > 0 ? "made" : "none") }
  ' main.ll >>result
done
rm -f Inner.ll Relay.ll main.ll
. ../../testresult.sh
