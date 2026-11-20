#!/bin/sh
. ../../testenv.sh
# doc/developer/language-extensions.md, "Indexing a string constant":
# indexing a string constant, local and imported, by a constant and a
# variable, LEN of one, constant and in a CONST and an array's length,
# and indexes in CASE labels. The run prints the values, then traps on an
# index past the 0X (exit 2). The IR check counts, in each procedure, the
# references to a module's copy of a constant (-const.) and the index
# checks (icmp sge and slt): none in Folded, some in Copied.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
exe=$(basename "$PWD")
poc -o "$exe" -build main.mod >result 2>&1
"./$exe" >>result 2>&1
echo "exit $?" >>result
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
rm -f Words.ll main.ll
. ../../testresult.sh
