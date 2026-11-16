#!/bin/sh
# PC test for scripts/write-part.sh: the Part file GFOpenUpTool reads.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/C" "$T/Utilities/JOE/syntax" "$T/Docs/JOE"
: > "$T/C/joe"; : > "$T/Utilities/JOE/joerc"; : > "$T/Utilities/JOE/syntax/c.jsf"; : > "$T/Docs/JOE/ReadMe"
sh "$HERE/../scripts/write-part.sh" "$T" 4.8
fail=0
expect() { grep -qxF "$1" "$T/Part" || { echo "FAIL: no line: $1"; fail=1; }; }
expect 'part JOE 4.8'
expect 'needs 68040'
expect 'copy "C/joe" "SYS:C/joe"'
expect 'copy "Utilities/JOE/joerc" "SYS:Utilities/JOE/joerc"'
expect 'copy "Utilities/JOE/syntax/c.jsf" "SYS:Utilities/JOE/syntax/c.jsf"'
expect 'copy "Docs/JOE/ReadMe" "SYS:Docs/JOE/ReadMe"'
[ "$(head -1 "$T/Part")" = 'part JOE 4.8' ] || { echo "FAIL: first line"; fail=1; }
[ "$(grep -c '^copy' "$T/Part")" = 4 ] || { echo "FAIL: file count (the Part file itself must not be listed)"; fail=1; }
sh "$HERE/../scripts/write-part.sh" "$T" 4.8   # a second run: the same file
[ "$(grep -c '^copy' "$T/Part")" = 4 ] || { echo "FAIL: second run lists the Part file"; fail=1; }
[ $fail = 0 ] && echo "Part file: all checks passed"
exit $fail
