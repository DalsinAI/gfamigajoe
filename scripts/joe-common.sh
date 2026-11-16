# What build-amiga.sh (the stove) and tests/host-joe.sh (the PC) share:
# JOE's sources, fetching them with patches/ applied, and the probe that
# writes autoconf.h. Sourced; needs HERE (the repo) and joe.lock's settings.
# MIT, Copyright (c) 2026 AmiCradle Team.

# joe_SOURCES from upstream's joe/Makefile.am (Unicode 17), less tty.c:
# amiga/joe_tty.c takes its place
JOE_SRCS="b.c blocks.c bw.c cmd.c hash.c help.c kbd.c macro.c main.c menu.c
 path.c poshist.c pw.c queue.c qw.c rc.c regex.c scrn.c tab.c termcap.c
 tw.c ublock.c uedit.c uerror.c ufile.c uformat.c uisrch.c umath.c
 undo.c usearch.c ushell.c utag.c va.c vfile.c vs.c w.c utils.c syntax.c
 utf8.c selinux.c charmap.c mouse.c lattr.c gettext.c builtin.c
 builtins.c vt.c mmenu.c state.c options.c unicode.c
 cclass.c frag.c colors.c unicat-17.0.0.c"

# a repository at one commit, fetched once: fetch_at DIR URL COMMIT
fetch_at() {
    if [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "${1:?}"; mkdir -p "$1"
        git -C "$1" init -q
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q FETCH_HEAD
        [ "$(git -C "$1" rev-parse HEAD)" = "$3" ] || { echo "$1: commit mismatch"; exit 1; }
    fi
}

# JOE at JOE_COMMIT with patches/ applied, into $1 (redone when either changes)
joe_source() {
    PSUM=$(cat "$HERE"/patches/*.patch | sha256sum | cut -c1-16)
    if [ "$(cat "$1/.patched" 2>/dev/null)" != "$JOE_COMMIT-$PSUM" ]; then
        rm -rf "$1"
        fetch_at "$1" "$JOE_GIT" "$JOE_COMMIT"
        for p in "$HERE"/patches/*.patch; do
            patch -s -d "$1" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
        done
        echo "$JOE_COMMIT-$PSUM" > "$1/.patched"
    fi
}

# autoconf.h into $2 for JOE's tree $1: configure's answers, each header
# compiled and each function linked as autoconf does ($PROBE_CC: the
# compile and link command). GFOS has no terminal ioctls, ptys, fork,
# users, curses or SELinux: those are never probed (the same on the PC,
# so the PC tests run the GFOS code).
joe_probe() {
    t=$(mktemp -d)
    {
        echo "/* autoconf.h: written by scripts/joe-common.sh joe_probe */"
        echo "#define PACKAGE \"joe\""
        echo "#define PACKAGE_NAME \"joe\""
        echo "#define PACKAGE_TARNAME \"joe\""
        echo "#define PACKAGE_STRING \"joe $JOE_VERSION\""
        echo "#define PACKAGE_VERSION \"$JOE_VERSION\""
        echo "#define PACKAGE_BUGREPORT \"\""
        echo "#define PACKAGE_URL \"\""
        echo "#define VERSION \"$JOE_VERSION\""
        echo "#define PROTOTYPES 1"
        echo "#define __PROTOTYPES 1"
        echo "#define HAVE_LONG_LONG 1"
        echo "#define RETSIGTYPE void"
        echo "#ifndef PARAMS"
        echo "#define PARAMS(protos) protos"
        echo "#endif"
        for h in errno.h fcntl.h locale.h stdlib.h string.h sys/param.h sys/time.h \
                 unistd.h utime.h sys/utime.h sys/types.h sys/stat.h limits.h signal.h \
                 stddef.h time.h dirent.h; do
            printf '#include <%s>\nint main(void) { return 0; }\n' "$h" > "$t/p.c"
            # shellcheck disable=SC2086
            if $PROBE_CC -c -o "$t/p.o" "$t/p.c" > /dev/null 2>&1; then
                echo "#define HAVE_$(echo "$h" | tr '[:lower:]/.' '[:upper:]__') 1"
            fi
        done
        for f in getcwd getwd isblank mkdir putenv setlocale strchr strdup utime snprintf fseeko \
                 $(sed -n 's/^AC_SEARCH_LIBS(\([a-z0-9]*\), *m,.*/\1/p' "$1/configure.ac"); do
            printf '%s\n' '#include <math.h>' '#include <stdlib.h>' '#include <string.h>' \
                '#include <stdio.h>' '#include <ctype.h>' '#include <time.h>' '#include <unistd.h>' \
                '#include <locale.h>' '#include <sys/types.h>' '#include <sys/stat.h>' > "$t/p.c"
            case $f in utime) echo '#include <utime.h>' >> "$t/p.c";; esac
            printf 'int main(void) { void (*volatile p)(void) = (void (*)(void))%s; return p != 0; }\n' "$f" >> "$t/p.c"
            # shellcheck disable=SC2086
            if $PROBE_CC -o "$t/p" "$t/p.c" -lm > /dev/null 2>&1; then
                echo "#define HAVE_$(echo "$f" | tr '[:lower:]' '[:upper:]') 1"
            fi
        done
        # what amiga/joe_compat.c stands in for when the C library has none
        for f in fchmod ioctl kill umask random lstat creat fdopen access; do
            printf '%s\n' '#include <stdlib.h>' '#include <stdio.h>' '#include <unistd.h>' \
                '#include <fcntl.h>' '#include <signal.h>' '#include <sys/types.h>' '#include <sys/stat.h>' > "$t/p.c"
            printf 'int main(void) { void (*volatile p)(void) = (void (*)(void))%s; return p != 0; }\n' "$f" >> "$t/p.c"
            # shellcheck disable=SC2086
            if $PROBE_CC -o "$t/p" "$t/p.c" > /dev/null 2>&1; then
                echo "#define HAVE_$(echo "$f" | tr '[:lower:]' '[:upper:]') 1"
            fi
        done
        echo "#ifdef HAVE_ISBLANK"
        echo "#define HAVE_WORKING_ISBLANK 1"
        echo "#endif"
        for pair in "char:CHAR" "short:SHORT" "int:INT" "long:LONG" "long long:LONG_LONG" \
                    "void *:VOID_P" "off_t:OFF_T"; do
            ty=${pair%%:*}; n=""
            for s in 1 2 4 8; do
                printf '#include <sys/types.h>\ntypedef char c[(sizeof(%s) == %s) ? 1 : -1];\n' "$ty" "$s" > "$t/p.c"
                # shellcheck disable=SC2086
                if $PROBE_CC -c -o "$t/p.o" "$t/p.c" > /dev/null 2>&1; then n=$s; break; fi
            done
            [ -n "$n" ] && echo "#define SIZEOF_${pair#*:} $n"
        done
    } > "$2"
    rm -rf "$t"
}

# the data files the part puts in SYS:Utilities/JOE: the rc files (joerc,
# jmacsrc, jstarrc, jpicorc, rjoerc), syntax/, colors/ and charmaps/
joe_data_dirs="syntax colors charmaps"
