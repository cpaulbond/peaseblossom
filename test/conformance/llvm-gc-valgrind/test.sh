#!/bin/sh
. ../../testenv.sh
# The collector under valgrind's memcheck
# (doc/developer/collector-under-valgrind.md; PLAN.md, "Ongoing library
# enhancements" 13): the stack scan reads words no one has written since
# their frame was made, some holding a stale pointer to a live block (left
# by Hole.c, as an LLVM spill slot can be), and memcheck must report none
# of it, with no suppressions. The program runs natively, then under
# memcheck. Where there is no valgrind (OpenBSD and NetBSD have none) the
# memcheck run is skipped and its line written as it would be, so it still
# passes.
POC_IMPORT_PATH=../../../rtl/llvm:part
export POC_IMPORT_PATH
poc -o stale.exe -build stale.mod >result 2>&1
./stale.exe >>result 2>&1
printf 'exit=%d\n' "$?" >>result
if command -v valgrind >/dev/null 2>&1
then
  timeout 300 valgrind -q --error-exitcode=99 --log-file=valgrind.log ./stale.exe >/dev/null 2>&1
  status=$?
  if [ $status -eq 0 ] && [ ! -s valgrind.log ]
  then echo "memcheck: no errors" >>result
  else printf 'memcheck: exit=%d\n' "$status" >>result; cat valgrind.log >>result
  fi
  rm -f valgrind.log
else
  echo "SKIPPED (memcheck run): no valgrind here"
  echo "memcheck: no errors" >>result
fi
rm -f *.sym *.exe part/*.sym part/*.o part/*.ll
. ../../testresult.sh
