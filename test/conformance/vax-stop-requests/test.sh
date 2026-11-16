#!/bin/sh
. ../../testenv.sh
# StopRequests on VAX/VMS (PLAN.md, "Ongoing library enhancements", 7),
# over Platform's CTRL/C AST. Built by poc -build in work/ from the
# runtime's sources and run on the guest (vax_do), both ways (vax_build).
. ../../vaxfixture.sh
rtl=../../../../rtl/vax
modules="StopVax StopRequests Platform Out LineOutput FormattedOutput FormattedText RealDigits"
written=
for m in $modules; do written="$written work/$m.mar"; done
: >result
builds() {
rm -rf work
mkdir work
cp StopVax.mod work/
(cd work && poc -target vax-dec-vms $vax_way_option -import-path $rtl -build StopVax.mod) >>result 2>&1
echo "VAX build exit $?" >>result
vax_do guest-run.com guest-run.expected work/StopVax.com $written ../../../rtl/vax/PocRtl.mar
}
vax_build builds
rm -rf work
. ../../testresult.sh
