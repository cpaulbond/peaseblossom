#!/bin/sh
. ../../testenv.sh
# texttest uses only what poc's Texts shares with voc's, so both compilers
# must print the same thing and write the same files. voc runs first and its
# symbol files go before poc starts (see llvm-files). The program is not
# texts, whose files would be Texts' where the file system ignores case
# (macOS).
written="elements.Text plain.Text plain.Text.Bak lines.txt"
rm -rf voc-files $written
voc texttest.mod -m >/dev/null
./texttest >voc-output
mkdir voc-files && mv $written voc-files
rm -rf *.c *.h *.o *.sym texttest texttest.dSYM

# Texts, Files and the rest are rtl modules: poc finds them through the
# import path
POC_IMPORT_PATH=../../../rtl/llvm
export POC_IMPORT_PATH
poc_build_run texttest.mod
cat result >poc-output
cmp -s poc-output voc-output || echo "poc and voc disagree on texttest" >>result
for f in $written
do cmp -s $f voc-files/$f || echo "poc and voc wrote different $f" >>result
done
rm -rf poc-output voc-output voc-files $written work
. ../../testresult.sh
