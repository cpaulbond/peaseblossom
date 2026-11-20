#!/bin/sh
# '.' this file from individual test.sh scripts, after producing "result".
# A fixture whose output on some system cannot be the same sets
# expected_file to the file it is compared with there (poc-link-flags:
# expected-macos, since macOS links nothing -static).

if diff -b "${expected_file:-expected}" result
then printf 'PASSED: %s\n\n' "$PWD"
else printf 'FAILED: %s\n\n' "$PWD"; exit 1
fi
