#!/bin/sh
. ../../testenv.sh
# TaskInput at a VAX/VMS terminal (doc/developer/tasks.md, Phase 11,
# proposals 4-6): TaskTerm.mod reads lines by TaskInput.Line with Out's
# prompt while a ticker task writes a line every 700 ms. terminal.exp
# builds it on the guest (guest-build.com), runs it at a telnet terminal,
# types "abc" slowly, "xyz" quickly and Ctrl/Z, and says what the terminal
# showed in words timing does not change: each tick broke through the
# pending read and redrew the prompt with what was typed so far, the lines
# came back whole, Ctrl/Z ended the input. That is compared with
# terminal.expected, and a difference goes to result with the session's
# stamped transcript. Built by poc -build in work/, as MACRO-32 alone: the
# fixture tests the runtime at the terminal (the probe's way), which the
# objects way does not change (vax-tasks-input runs both). The only
# fixture that drives the guest's terminal itself; skipped, as vax_do's
# are, where the guest is not.
. ../../vaxfixture.sh
rtl=../../../../rtl/vax
: >result
rm -rf work
mkdir work
cp TaskTerm.mod work/
(cd work && poc -target vax-dec-vms -vax-macro32 -import-path $rtl \
  -link COROUTINESWITCH.OBJ -link 'SYS$SYSTEM:SYS.STB/SELECTIVE_SEARCH' -build TaskTerm.mod) >>result 2>&1
echo "VAX build exit $?" >>result
if [ "${VAX_GUEST:-}" = skip ]; then
  echo "SKIPPED: running TaskTerm at the VAX's terminal (VAX_GUEST=skip)"
elif ../../../tools/vax-assemble -available; then
  set --
  for f in work/*.mar work/TaskTerm.com ../../../rtl/vax/PocRtl.mar \
      ../../../rtl/vax/CoroutineSwitch.mar guest-build.com; do
    set -- "$@" "$f" "$(basename "$f" | tr a-z A-Z)"
  done
  (
    host=${VAX_HOST:-192.168.2.20}
    VAX_NETRC=${VAX_NETRC:-$HOME/.netrc-poc-vax}; export VAX_NETRC
    . ../../../tools/vax-lock.sh
    vax_lock
    trap vax_unlock EXIT
    expect -f terminal.exp "$host" work/transcript "$@"
  ) >work/terminal.out 2>&1
  echo "terminal.exp exit $?" >>work/terminal.out
  if ! diff terminal.expected work/terminal.out >work/terminal.diff 2>&1; then
    echo "TaskTerm at the VAX's terminal differs from terminal.expected:" >>result
    cat work/terminal.diff >>result
    if [ -f work/transcript ]; then
      echo "the terminal showed (ms from the first prompt):" >>result
      cat work/transcript >>result
    fi
  fi
else
  echo "SKIPPED: running TaskTerm at the VAX's terminal (no VAX development system here)"
fi
rm -rf work
. ../../testresult.sh
