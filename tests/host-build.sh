#!/bin/sh
# Builds JOE for the PC as it is built for GFOS: JOE_GFOS on (patches/0001),
# autoconf.h from the same probe, amiga/joe_tty.c in place of tty.c, and
# tests/gfcon_host.c as the console. Writes $WORK/joe and $WORK/joe-src.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/joe.lock"
. "$HERE/scripts/joe-common.sh"
CC=${HOST_CC:-cc}
WORK=${WORK:-"$HERE/build-host"}; mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
SRC="$WORK/joe-src"; joe_source "$SRC"
PROBE_CC="$CC" joe_probe "$SRC" "$WORK/autoconf.h"
CF="-O1 -g -w -Werror=implicit-function-declaration -Werror=int-conversion -Werror=incompatible-pointer-types -I$WORK -I$HERE/amiga -I$SRC/joe -include $WORK/autoconf.h -include $HERE/amiga/joe_gfos.h \
 -DJOERC=\"SYS:Utilities/JOE/\" -DJOEDATA=\"SYS:Utilities/JOE/\""
O="$WORK/obj"; mkdir -p "$O"
for f in $JOE_SRCS; do
    o="$O/${f%.c}.o"
    if [ ! -f "$o" ] || [ "$SRC/joe/$f" -nt "$o" ] || [ "$WORK/autoconf.h" -nt "$o" ]; then
        # shellcheck disable=SC2086
        $CC $CF -c "$SRC/joe/$f" -o "$o"
    fi
done
# shellcheck disable=SC2086
$CC $CF -o "$WORK/joe" $(for f in $JOE_SRCS; do echo "$O/${f%.c}.o"; done) \
    "$HERE/amiga/joe_tty.c" "$HERE/amiga/gfcsi.c" "$HERE/amiga/joe_compat.c" "$HERE/tests/gfcon_host.c" -lm
echo "host joe: $WORK/joe"
