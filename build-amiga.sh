#!/bin/sh
# Builds JOE (Joe's Own Editor) for GFOS (AmigaOS 3.2.3 with GFOpenUp) with
# a stove: 68040, soft float with the FPU taken when there is one
# (fpuauto). JOE runs in the AmigaDOS console: amiga/joe_tty.c in place of
# its Unix terminal code, amiga/gfcon_amiga.c for the console itself.
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
# JOE and fpuauto are fetched at the commits joe.lock gives; nothing
# third-party is kept here. The PC tests (tests/host-joe.sh: the same
# patched sources and terminal code, driven by keys from a pipe) run first
# when there is a PC compiler; HOST_TESTS=0 skips them.
# OUT gets Parts/JOE: a GFOpenUp part (its Part file, C:joe, the rc files,
# syntax, colour schemes and character map in SYS:Utilities/JOE, the
# manual and licence in SYS:Docs/JOE), installed with
#   GFOpenUpTool INSTALL Parts/JOE
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/joe.lock"
. "$HERE/scripts/joe-common.sh"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK="${WORK:-$HOME/.cache/gfamigajoe/build}"; OUT="${OUT:-$WORK/out}"; JOBS=${JOBS:-8}
TC="$STOVE/prefix"; PATH="$TC/bin:$PATH"; export PATH
mkdir -p "$WORK/deps" "$OUT"; OUT=$(cd "$OUT" && pwd)
t0=$(date +%s)

# --- the PC tests first: the same sources, keys through the GFOS terminal code ---
if [ "${HOST_TESTS:-1}" != 0 ] && command -v "${HOST_CC:-cc}" > /dev/null 2>&1; then
    WORK="$WORK/host" sh "$HERE/tests/host-joe.sh" > "$WORK/host-tests.log" 2>&1 || { tail -40 "$WORK/host-tests.log"; exit 1; }
    grep -E "checks passed" "$WORK/host-tests.log"
fi

# --- fpuauto: libfpuauto.a and its link specs ---------------------------------
FPD="$WORK/deps/fpuauto"
if [ "$(git -C "$FPD" rev-parse HEAD 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FPD"; mkdir -p "$FPD"; git -C "$FPD" init -q
    git -C "$FPD" config core.sparseCheckout true
    echo "/common/fpuauto/" > "$FPD/.git/info/sparse-checkout"
    git -C "$FPD" fetch -q --depth 1 --filter=blob:none "$FPA_REPO" "$FPA_COMMIT"
    git -C "$FPD" checkout -q FETCH_HEAD
fi
FA="$FPD/common/fpuauto"; FAL="$WORK/fpuauto"
if [ ! -f "$FAL/libfpuauto.a" ] || [ "$(cat "$FAL/.rev" 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FAL"; mkdir -p "$FAL/obj"
    m68k-amigaos-gcc -m68040 -DFPUAUTO_COMMON -c "$FA/fpuauto.S" -o "$FAL/obj/fa_common.o"
    for n in $(sed 's/^--wrap=//' "$FA/fpuauto.wraps"); do
        m68k-amigaos-gcc -m68040 -DR_$n -c "$FA/fpuauto.S" -o "$FAL/obj/fa_$n.o"
    done
    m68k-amigaos-ar rcs "$FAL/libfpuauto.a" "$FAL"/obj/fa_*.o
    echo "$FPA_COMMIT" > "$FAL/.rev"
fi

# --- JOE at its pinned commit, patches/, the probe -----------------------------
SRC="$WORK/joe"
joe_source "$SRC"
LINK="m68k-amigaos-gcc -noixemul -m68040 -specs=$HERE/scripts/m68k-soft-m68040.specs -specs=$FA/fpuauto.specs -L$FAL"
PROBE_CC="$LINK" joe_probe "$SRC" "$WORK/autoconf.h"
echo "probe: $(grep -c '^#define HAVE_' "$WORK/autoconf.h") found"

# --- compile -------------------------------------------------------------------
LATE=""
if m68k-amigaos-gcc -fno-late-combine-instructions -S -o /dev/null -x c /dev/null 2>/dev/null; then LATE="-fno-late-combine-instructions"; fi
# no loops turned into memset/memcpy calls (GCC 16), address 0 is memory
CF="-noixemul -m68040 -O2 -fno-tree-loop-distribute-patterns -fno-delete-null-pointer-checks $LATE \
 -Werror=implicit-function-declaration -w \
 -I$WORK -I$HERE/amiga -I$SRC/joe -include $WORK/autoconf.h -include $HERE/amiga/joe_gfos.h \
 -DJOERC=\\\"SYS:Utilities/JOE/\\\" -DJOEDATA=\\\"SYS:Utilities/JOE/\\\" \
 -DJOE_AMIGA_VERSION=\\\"$JOE_VERSION\\\" -DJOE_AMIGA_DATE=\\\"$(date -u +%d.%m.%Y)\\\""
O="$WORK/obj"
# objects made against another JOE, patch set or probe go
STAMP="$(cat "$SRC/.patched") $(sha256sum "$WORK/autoconf.h" | cut -c1-16)"
[ "$(cat "$O/.src" 2>/dev/null)" = "$STAMP" ] || { rm -rf "$O"; mkdir -p "$O"; echo "$STAMP" > "$O/.src"; }
M="$O/Makefile"
{
    echo "CF = $CF"
    A=""
    for f in $JOE_SRCS; do
        o="${f%.c}.o"; A="$A $o"
        printf '%s: %s\n\tm68k-amigaos-gcc $(CF) -MMD -c $< -o $@\n' "$o" "$SRC/joe/$f"
    done
    for f in joe_tty gfcsi joe_compat gfcon_amiga; do
        A="$A amiga_$f.o"
        printf 'amiga_%s.o: %s\n\tm68k-amigaos-gcc $(CF) -MMD -c $< -o $@\n' "$f" "$HERE/amiga/$f.c"
    done
    echo "OBJS =$A"
    echo "all: \$(OBJS)"
    echo "-include *.d"
} > "$M"
(cd "$O" && nice -n 19 make -k -j"$JOBS" all > make.log 2>&1) || { grep -E 'error' "$O/make.log" | head -40; tail -20 "$O/make.log"; exit 1; }
echo "compile: $(( $(date +%s) - t0 )) s"

# --- link: soft-float specs, then fpuauto's -------------------------------------
# shellcheck disable=SC2046
$LINK -o "$O/joe.debug" $(cd "$O" && for f in $(sed -n 's/^OBJS =//p' Makefile); do echo "$O/$f"; done) \
    -lm > "$O/link.log" 2>&1 || { head -60 "$O/link.log"; exit 1; }

# --- the GFOpenUp part: Parts/JOE -----------------------------------------------
P="$OUT/Parts/JOE"; rm -rf "$P"; mkdir -p "$P/C" "$P/Docs/JOE"
m68k-amigaos-strip -o "$P/C/joe" "$O/joe.debug"
sh "$HERE/scripts/joe-data.sh" "$SRC" "$P/Utilities/JOE"
cp "$HERE/README.md" "$P/Docs/JOE/ReadMe"
cp "$SRC/COPYING" "$P/Docs/JOE/COPYING-JOE"
LC_ALL=C sed 's,@JOERC@,SYS:Utilities/JOE/,g; s,@JOEDATA@,SYS:Utilities/JOE/,g; s,@JOEDOC@,SYS:Docs/JOE/,g' "$SRC/man/joe.1.in" > "$P/Docs/JOE/joe.1"
cp "$SRC/docs/man.md" "$P/Docs/JOE/man.md"
sh "$HERE/scripts/write-part.sh" "$P" "$JOE_VERSION"
ls -l "$P/C/joe"
echo "part: $(grep -c '^copy' "$P/Part") files, $(du -sk "$P" | cut -f1) KB"
echo "fpuauto: $(m68k-amigaos-nm "$O/joe.debug" | grep -c ' T ___wrap_') wrapped routines"
echo "total: $(( $(date +%s) - t0 )) s"
