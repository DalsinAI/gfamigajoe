#!/bin/sh
# PC test: JOE built as for GFOS (tests/host-build.sh) driven through
# amiga/joe_tty.c by keys from a pipe, in a drawer laid out as the part
# installs it (SYS:Utilities/JOE, T:, ENVARC:, with no HOME, TERM or LANG,
# as on AmigaOS). Each case starts clean and checks the files JOE leaves.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${WORK:-"$HERE/build-host"}; mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
WORK="$WORK" sh "$HERE/tests/host-build.sh"
. "$HERE/joe.lock"
. "$HERE/scripts/joe-common.sh"
SRC="$WORK/joe-src"
RUN="$WORK/run"
fail=0; n=0
ok() { n=$((n + 1)); }
bad() { echo "FAIL: $*"; fail=1; }

fresh() {
    rm -rf "$RUN"; mkdir -p "$RUN/SYS:C" "$RUN/T:"
    sh "$HERE/scripts/joe-data.sh" "$SRC" "$RUN/SYS:Utilities/JOE"
    cp "$WORK/joe" "$RUN/SYS:C/joe"
}
# joe ARGS... with keys on stdin: the name it was started by is SYS:C/joe
# (or $AS), the screen goes to screen.out
joe() {
    (cd "$RUN" && timeout 20 env -i PATH=/usr/bin:/bin ${ROWS:+GFCON_ROWS=$ROWS} ${ROWS2:+GFCON_ROWS2=$ROWS2} \
        bash -c 'exec -a "$0" "SYS:C/joe" "$@"' "${AS:-SYS:C/joe}" "$@" > screen.out 2> err.out) || true
}
has() { [ -f "$RUN/$1" ] && [ "$(cat "$RUN/$1")" = "$2" ]; }

# 1. a new file, typed and saved (^K X)
fresh; printf 'hello world\r\013x' | joe new.txt
if has new.txt 'hello world'; then ok; else bad "new file: $(cat "$RUN/new.txt" 2>&1)"; fi
# with no HOME, JOE's state goes to ENVARC:joe
if [ -f "$RUN/ENVARC:joe/joe_state" ]; then ok; else bad "no ENVARC:joe/joe_state"; fi
# no lock left behind
if ls -a "$RUN" | grep -q '^\.#'; then bad "lock file left"; else ok; fi

# 2. the console's cursor keys (CSI C, CSI B, CSI D) through termcap's .kr etc.
fresh; printf 'abc\n' > "$RUN/a.txt"; printf '\233C\233CX\233B\233DY\013x' | joe a.txt
if has a.txt "$(printf 'abXc\nY')"; then ok; else bad "cursor keys: $(cat "$RUN/a.txt")"; fi

# shift+down (CSI S, page down) and shift+left / shift+right (CSI SPACE A /
# CSI SPACE @: start and end of line) through .kN, .kh and .kH
fresh; printf 'abc\n' > "$RUN/h.txt"; printf '\233 @E\233 AS\013x' | joe h.txt
if has h.txt "$(printf 'SabcE')"; then ok; else bad "home/end keys: $(cat "$RUN/h.txt")"; fi

# 3. the window size is the console's answer (30 rows: the status line on row 30)
fresh; printf '\013x' | ROWS=30 joe s.txt
if grep -aq "$(printf '\033\\[29B\033\\[7m Joe')" "$RUN/screen.out"; then ok; else bad "30-row console not used"; fi

# 4. a resize event: asked again, redrawn for 40 rows
fresh; printf 'a\23312;0;0;0;0;0;0;0|b\013x' | ROWS=25 ROWS2=40 joe rz.txt
if grep -aq "$(printf '\033\\[39B')" "$RUN/screen.out" && has rz.txt ab; then ok; else bad "resize"; fi

# 5. a block through a command (^K /): the block in T:, the output back
fresh; printf 'abc\ndef\n' > "$RUN/f.txt"; printf '\013u\013b\013v\013k\013/tr a-z A-Z\r\013x' | joe f.txt
if has f.txt "$(printf 'ABC\nDEF')"; then ok; else bad "filter: $(cat "$RUN/f.txt")"; fi
if [ -z "$(ls "$RUN/T:")" ]; then ok; else bad "T: not cleaned: $(ls "$RUN/T:")"; fi

# 6. !command as a file to read (^K R) and to write (^K D)
fresh; printf '\013r!echo hi\r\013x' | joe r.txt
if has r.txt hi; then ok; else bad "!cmd read: $(cat "$RUN/r.txt" 2>&1)"; fi
fresh; printf 'pipe me\n' > "$RUN/w.txt"; printf '\013d\031!cat >piped.txt\r\003\003' | joe w.txt
if has piped.txt 'pipe me'; then ok; else bad "!cmd write"; fi

# 7. locks are plain files (no symbolic links on AmigaOS): ours, and another's
fresh; printf 'x\n' > "$RUN/l.txt"; printf 'Q\013r!cat .#l.txt\r\013x' | joe l.txt
if grep -q 'me@here' "$RUN/l.txt"; then ok; else bad "own lock: $(cat "$RUN/l.txt")"; fi
fresh; printf 'x\n' > "$RUN/l.txt"; printf 'dale@cradle' > "$RUN/.#l.txt"; printf 'Zq\003' | joe l.txt
if grep -aq 'dale@cradle' "$RUN/screen.out"; then ok; else bad "other's lock not shown"; fi

# 8. started as SYS:C/jmacs: the rc file is jmacsrc (the name after the volume)
fresh; printf 'hi\030\023\030\003' | AS=SYS:C/jmacs joe jm.txt
if has jm.txt hi; then ok; else bad "jmacs: $(cat "$RUN/jm.txt" 2>&1)"; fi

# 9. the console closing with changes: DEADJOE
fresh; printf 'unsaved' | joe d.txt
if grep -q 'unsaved' "$RUN/DEADJOE" 2>/dev/null; then ok; else bad "no DEADJOE"; fi

[ $fail = 0 ] && echo "JOE host: $n checks passed"
exit $fail
