#!/bin/sh
. ../../testenv.sh
# Phase 13 step 8: an executable poc links and a shared library it builds
# each have a GNU_RELRO segment, on every system: Linux's and the other
# BSDs' linkers give one unasked, on NetBSD poc passes -Wl,-z,relro (plain
# clang and gcc there do not; pkgsrc's checks found it). The program is
# linked with the shared library, so it runs only if that works too.
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
# macOS's counterpart is the segment __DATA_CONST marked SG_READ_ONLY (flags
# 10H), which dyld makes read-only once it has relocated it; ld64 gives it.
exe=$(basename "$PWD")
relro() {
  if [ "$(uname -s)" = Darwin ]
  then otool -l "$1" | awk '$1 == "cmd" { segment = ($2 == "LC_SEGMENT_64" || $2 == "LC_SEGMENT") }
                          segment && $1 == "segname" { constant = ($2 == "__DATA_CONST") }
                          segment && constant && $1 == "flags" { n += ($2 == "0x10"); constant = 0 }
                          END { print n + 0 }'
  else readelf -lW "$1" | grep -c GNU_RELRO
  fi
}
rm -rf lib
: >result
poc -output-dir lib -library greeting Greeting.mod >>result 2>&1
so=$(ls lib/*/*/libgreeting.so* lib/*/*/libgreeting.dylib 2>/dev/null | head -1)
printf 'library: %s\n' "$(relro "$so")" >>result
poc -library-path lib -shared-libraries -o "$exe" -build relro.mod >>result 2>&1
printf 'program: %s\n' "$(relro "$exe")" >>result
"./$exe" >>result 2>&1
rm -rf lib
. ../../testresult.sh
