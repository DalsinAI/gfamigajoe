#!/bin/sh
# Writes the Part file GFOpenUpTool INSTALL reads (gfopenup src/openuptool.c)
# for the part drawer the build made: C/joe to C:joe, Utilities/JOE/ (rc
# files, syntax, colours, character map) to SYS:Utilities/JOE/, Docs/JOE/
# to SYS:Docs/JOE/.
#   write-part.sh <part drawer> <version>
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
P=$1; V=$2
{
    echo "part JOE $V"
    echo "; JOE, Joe's Own Editor: a text editor for the Shell (C:joe), WordStar and Emacs keys"
    echo "needs 68040"
    (cd "$P" && find C Utilities Docs -type f | LC_ALL=C sort) | while read -r f; do
        echo "copy \"$f\" \"SYS:$f\""
    done
} > "$P/Part"
