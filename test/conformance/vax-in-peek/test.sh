#!/bin/sh
. ../../testenv.sh
# PLAN.md "Ongoing library enhancements", item 8: In.Peek on VAX/VMS, with
# llvm-in-peek's peek.mod, built for the VAX under -O2 and run there
# (vax_do, guest-run.com) with SYS$INPUT llvm-in-peek's input but for its
# 0X byte, which is a y here, since a VMS text record sent by FTP in ASCII
# mode cannot be counted on to keep it. It must print guest-run.expected:
# llvm-in-peek's expected, but for that byte's two lines.
. ../../vaxfixture.sh
rtl=../../../rtl/vax
written="peek.mar In.mar FormattedInput.mar DecimalToReal.mar Platform.mar Out.mar LineOutput.mar FormattedOutput.mar FormattedText.mar RealDigits.mar"
cp ../llvm-in-peek/peek.mod .
printf 'ab\n  second line\nyz\n  42\nlast\n' >input.txt
rm -f peek.com
: >result
# Built and run both ways, from MACRO-32 and from poc's objects (vax_build).
builds() {
rm -f *.sym $written
poc -target vax-dec-vms $vax_way_option -import-path $rtl -build peek.mod >>result 2>&1
echo "VAX build peek exit $?" >>result
vax_do guest-run.com guest-run.expected peek.com input.txt $written $rtl/PocRtl.mar
}
vax_build builds
rm -f *.sym $written peek.com peek.mod input.txt *.obj
. ../../testresult.sh
