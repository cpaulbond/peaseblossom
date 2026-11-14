#!/bin/sh
. ../../testenv.sh
# TaskInput on POSIX (doc/developer/tasks.md, Phase 11): lines fed
# through a pipe every 300 ms while a ticker task runs every 50 ms; the
# same lines from a regular file, and /dev/null; a long line cut short;
# Char across line ends; two reading tasks taking whole lines. Under
# both size models.
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
echo "== -OC" >>../result
rm -f *.sym *.o *.ll
poc -OC -import-path $rtl -o input-oc -build ../input.mod >>../result 2>&1
run input-oc
cd ..
rm -rf work
. ../../testresult.sh
