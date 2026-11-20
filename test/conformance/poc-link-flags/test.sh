#!/bin/sh
. ../../testenv.sh
# Phase 12 step 1: -link, -static and -verbose (voc's LDFLAGS/LDLIBS, -M and
# -V). The program calls a C function in libpocfixture.a, built here from triple-source.txt into
# "lib dir" (a space, to show each -link argument reaches clang as one word).
# Without -link the build fails; with it the program runs. -static leaves the
# executable without a program interpreter (readelf's INTERP), the default
# build has one. -verbose prints the clang command, with the host's triple and
# optimization level replaced: a clang -c for each module, then the link
# (-clear-library-path: rtl/llvm compiled too, not taken from poc-rtl).
# NetBSD's -Wl,-z,relro (llvm-relro) is left out, so that every host gives
# the same command. macOS links nothing -static: there -static is refused,
# the -verbose link is the dynamic one, its interpreter is dyld
# (LC_LOAD_DYLINKER), and the result is compared with expected-macos.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
exe=$(basename "$PWD")
rm -rf "lib dir"; mkdir "lib dir"
clang -x c -c triple-source.txt -o "lib dir/triple.o"
ar rc "lib dir/libpocfixture.a" "lib dir/triple.o"
ranlib "lib dir/libpocfixture.a"
: >result
echo "== without -link" >>result
poc -o "$exe" -build linkflags.mod 2>&1 | grep '^poc:' >>result
# the program interpreter's program headers: 1 when it has one, 0 when not
interpreter() {
  if [ "$(uname -s)" = Darwin ]
  then otool -l "$1" | grep -c LC_LOAD_DYLINKER
  else readelf -l "$1" | grep -c INTERP
  fi
}
verbose() {
  grep -v '^semantic OK' | sed -e 's/--target=[^ ]*/--target=<triple>/' -e 's/ -O[0-9sgz]/ -O<level>/' -e 's/ -Wl,-z,relro//'
}
if [ "$(uname -s)" = Darwin ]; then
  expected_file=expected-macos
  echo "== -static" >>result
  poc -clear-library-path -static -link "-Llib dir" -link -lpocfixture -o "$exe" -build linkflags.mod >>result 2>&1
  printf 'exit=%d\n' "$?" >>result
  echo "== -link and -verbose" >>result
  poc -clear-library-path -verbose -link "-Llib dir" -link -lpocfixture -o "$exe" -build linkflags.mod 2>&1 | verbose >>result
else
  echo "== -link, -static and -verbose" >>result
  poc -clear-library-path -verbose -static -link "-Llib dir" -link -lpocfixture -o "$exe" -build linkflags.mod 2>&1 | verbose >>result
fi
"./$exe" >>result 2>&1
printf 'exit=%d\n' "$?" >>result
printf 'INTERP: %s\n' "$(interpreter "$exe")" >>result
echo "== -link, dynamic" >>result
poc -link "-Llib dir" -link -lpocfixture -o "$exe" -build linkflags.mod 2>&1 | grep -v '^semantic OK' >>result
"./$exe" >>result 2>&1
printf 'exit=%d\n' "$?" >>result
printf 'INTERP: %s\n' "$(interpreter "$exe")" >>result
echo "== -link without an argument" >>result
poc -link >>result 2>&1
printf 'exit=%d\n' "$?" >>result
rm -rf "lib dir"
. ../../testresult.sh
