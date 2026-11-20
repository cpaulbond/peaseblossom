# OpenBSD's ksh has no ulimit -v; there -d bounds anonymous mmap too. macOS
# refuses both, and runs without a limit: there an impossible stack fails
# anyway, but a leak only takes memory.
  ulimit -v 1000000 2>/dev/null || ulimit -d 1000000 2>/dev/null ||
    [ "$(uname -s)" = Darwin ] || ulimit -d 1000000
#!/bin/sh
. ../../testenv.sh
# Coroutines (doc/developer/coroutines.md, Phase 3): trap 16 (a body
# returns); each case of 17 (a Transfer to a record never given to Init, to
# a freed coroutine, in a finalizer, in a signal handler; a Free of the
# running coroutine, of main's); 18 (Init refused its stack: MAX(LONGINT)
# bytes under a ulimit); and a NIL dereference, HALT and ASSERT on a
# coroutine; each with a finalizer run. With -trap-location too, which
# none of 16-18 carries.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
# OpenBSD's ksh has no ulimit -v; there -d bounds anonymous mmap too. macOS
# refuses both and runs without a limit: there an impossible stack fails
# anyway, but a leak only takes memory.
limit_memory() {
  ulimit -v 1000000 2>/dev/null || ulimit -d 1000000 2>/dev/null ||
    [ "$(uname -s)" = Darwin ] || ulimit -d 1000000
}
poc -o traps.exe -build traps.mod >result 2>&1
for which in 1 2 3 4 5 6 7 9 10 11 12
do
  echo "== $which" >>result
  (limit_memory; ./traps.exe $which) >>result 2>&1
  printf 'exit=%d\n' "$?" >>result
done
# 8, trap 18, needs the limit: under -O2 MAX(LONGINT) bytes are 2 GiB, which
# a system without one gives. macOS refuses to set one, so it is checked
# against expected-8 only where one can be set.
if (ulimit -v 1000000 2>/dev/null || ulimit -d 1000000 2>/dev/null); then
  { echo "== 8"; (limit_memory; ./traps.exe 8) 2>&1; printf 'exit=%d\n' "$?"; } >case-8
  if ! diff expected-8 case-8 >case-8-differences; then
    echo "case 8 differs from expected-8:" >>result
    cat case-8-differences >>result
  fi
  rm -f case-8 case-8-differences
else
  echo "SKIPPED: case 8, trap 18 (this system sets no memory limit)"
fi
echo "== -trap-location" >>result
poc -trap-location -o located.exe -build traps.mod >>result 2>&1
for which in 1 4 9
do
  (limit_memory; ./located.exe $which) >>result 2>&1
  printf 'exit=%d\n' "$?" >>result
done
rm -f *.sym traps.exe located.exe
. ../../testresult.sh
