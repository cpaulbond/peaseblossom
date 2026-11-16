#!/bin/sh
. ../../testenv.sh
# TaskInput on POSIX (doc/developer/tasks.md, Phase 11): lines fed
# through a pipe every 300 ms while a ticker task runs every 50 ms; the
# same lines from a regular file, and /dev/null; a long line cut short;
# Char across line ends; two reading tasks taking whole lines. Under
# both size models. Where strace can inject faults (Linux), the first
# read of standard input is made to fail with EINTR, which TaskInput
# must retry, not take for the end (PLAN.md, "Ongoing bug fixing", 23):
# a difference goes to result, and elsewhere the check is skipped,
# saying so on the output only, so that result is the same on every host.
unset POC_IMPORT_PATH
rm -rf work && mkdir work && cd work || exit 1
rtl=../../../../rtl/llvm
printf 'alpha\nbeta\ngamma\n' >lines.txt
slowly() {
  for line in one two three four; do echo "$line"; sleep 0.3; done
}
run() {
  echo "-- ticks, from a slow pipe" >>../result
  slowly | ./$1 ticks >>../result 2>&1
  echo "-- lines, from a file" >>../result
  ./$1 lines <lines.txt >>../result 2>&1
  echo "-- lines, from /dev/null" >>../result
  ./$1 lines </dev/null >>../result 2>&1
  echo "-- short" >>../result
  printf 'abcdefghijklmnop\nxy\n\nlast, with no line end' | ./$1 short >>../result 2>&1
  echo "-- chars" >>../result
  printf 'ab\r\ncd\n\ne' | ./$1 chars >>../result 2>&1
  echo "-- two" >>../result
  printf 'one\ntwo\nthree\nfour\nfive\nsix\n' | ./$1 two >>../result 2>&1
  printf 'exit=%d\n' "$?" >>../result
}
poc -import-path $rtl -o input -build ../input.mod >../result 2>&1
run input
if strace -o /dev/null -e inject=read:error=EINTR:when=1 --trace-fds=0 true </dev/null 2>/dev/null; then
  strace -o /dev/null -e inject=read:error=EINTR:when=1 --trace-fds=0 ./input lines <lines.txt >interrupted 2>&1
  printf 'line: alpha\nline: beta\nline: gamma\nend\n' >interrupted.expected
  if ! diff interrupted.expected interrupted >interrupted.diff 2>&1; then
    echo "-- lines, the first read interrupted (EINTR): differs" >>../result
    cat interrupted.diff >>../result
  fi
else
  echo "SKIPPED: the EINTR check (no strace that injects faults)"
fi
echo "== -OC" >>../result
rm -f *.sym *.o *.ll
poc -OC -import-path $rtl -o input-oc -build ../input.mod >>../result 2>&1
run input-oc
cd ..
rm -rf work
. ../../testresult.sh
