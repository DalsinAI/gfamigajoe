#!/bin/sh
# The files for SYS:Utilities/JOE from JOE's tree: the rc files with
# upstream's @JOERC@/@JOEDATA@/@JOEDOC@ filled in (rc/Makefile.am), ftyperc,
# and the syntax, colors and charmaps drawers.
#   joe-data.sh <JOE tree> <drawer>
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
S=$1; D=$2
mkdir -p "$D"
for r in joerc jmacsrc jstarrc jpicorc rjoerc; do
    LC_ALL=C sed 's,@JOERC@,SYS:Utilities/JOE/,; s,@JOEDOC@,SYS:Docs/JOE/,; s,@JOEDATA@,SYS:Utilities/JOE/,; s,@SPELL@,aspell,' \
        "$S/rc/$r.in" > "$D/$r"
done
cp "$S/rc/ftyperc" "$D/ftyperc"
for d in syntax colors; do
    rm -rf "${D:?}/$d"; mkdir -p "$D/$d"
    (cd "$S/$d" && for f in *; do case $f in Makefile*|*.md|*.in) ;; *) [ -f "$f" ] && cp "$f" "$D/$d/$f";; esac; done)
done
# charmaps/klingon (upstream installs it from klingon.in as it is)
rm -rf "${D:?}/charmaps"; mkdir -p "$D/charmaps"
cp "$S/charmaps/klingon.in" "$D/charmaps/klingon"
