#!/bin/sh
. ../../testenv.sh
# The CPU a 32-bit x86 target is compiled for
# (doc/developer/32-bit-x86-cpu.md): poc gives clang -march=i686 for
# 32-bit x86 Linux, whose default CPU (pentium4) uses SSE2, which a
# Pentium II lacks, and leaves every other triple at clang's default. For
# each triple, the CPU option in poc's clang command, and whether the
# assembly clang writes with that command uses an SSE register. x86-64,
# whose every CPU has SSE2, shows that the probe makes clang use it. Only
# clang -S runs, no linker or C library, so every host checks every
# triple.
POC_IMPORT_PATH=$PWD/../../../rtl/llvm
export POC_IMPORT_PATH
rm -rf work && mkdir work
cp probe.mod work/
cd work || exit 1
: >../result
for triple in i686-pc-linux-gnu i386-unknown-linux-gnu i486-unknown-netbsdelf \
              i386-unknown-openbsd i686-unknown-freebsd x86_64-unknown-linux-gnu
do
  rm -f probe.ll probe.o probe.s
  poc -clear-library-path -verbose -target "$triple" -compile probe.mod >/dev/null 2>poc.err
  command=$(grep '^clang -c' poc.err | tail -1)
  if [ -z "$command" ]; then
    echo "$triple: no clang command" >>../result; cat poc.err >>../result; continue
  fi
  cpu=$(echo "$command" | grep -oE -- '-march=[^ ]+')
  # the same command, writing assembly
  assembly=$(echo "$command" | sed -e 's/^clang -c/clang -S/' -e 's/ -o .*$/ -o probe.s/')
  if ! eval "$assembly" 2>clang.err; then
    echo "$triple: clang -S failed" >>../result; cat clang.err >>../result; continue
  fi
  if grep -q '%xmm' probe.s; then sse="uses SSE"; else sse="no SSE"; fi
  echo "$triple: ${cpu:-clang's default CPU}, $sse" >>../result
done
cd ..
rm -rf work
. ../../testresult.sh
