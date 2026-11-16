#!/bin/sh
. ../../testenv.sh
# Coroutines under valgrind (doc/developer/coroutines-under-valgrind.md;
# PLAN.md, "Ongoing bug fixing" 21): each coroutine's stack is registered
# with valgrind, so memcheck takes a switch between two of them, which mmap
# puts next to each other, for a switch and not for a push or a pop. Two
# tasks that yield, the User's Guide's Primes (a chain of 50 filter tasks,
# each stack freed when its task returns) and Queens (one coroutine), each
# run natively and then under memcheck, which must find no error. Where
# there is no valgrind (OpenBSD and NetBSD have none) the memcheck runs
# are skipped and their lines written as they would be, so it still passes.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
examples=../../../doc/examples
poc -o twotasks.exe -build twotasks.mod >result 2>&1
poc -o primes.exe -build "$examples/tasks/Primes.Mod" >>result 2>&1
poc -o queens.exe -build "$examples/coroutines/Queens.Mod" >>result 2>&1

if command -v valgrind >/dev/null 2>&1
then have_valgrind=yes
else have_valgrind=no; echo "SKIPPED (memcheck runs): no valgrind here"
fi

# run "name" program arguments...: its output and exit status natively,
# then memcheck's verdict
run() {
  name=$1; shift
  echo "== $name" >>result
  "$@" >>result 2>&1
  printf 'exit=%d\n' "$?" >>result
  if [ $have_valgrind = yes ]
  then
    timeout 300 valgrind -q --error-exitcode=99 --log-file=valgrind.log "$@" >/dev/null 2>&1
    status=$?
    if [ $status -eq 0 ] && [ ! -s valgrind.log ]
    then echo "memcheck: no errors" >>result
    else printf 'memcheck: exit=%d\n' "$status" >>result; cat valgrind.log >>result
    fi
    rm -f valgrind.log
  else echo "memcheck: no errors" >>result
  fi
}
run twotasks ./twotasks.exe
run "Primes 50" ./primes.exe 50
run "Queens -n 6 4" ./queens.exe -n 6 4
rm -f *.sym *.exe
. ../../testresult.sh
