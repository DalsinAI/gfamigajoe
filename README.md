# GFAmigaJOE

JOE 4.8 (Joe's Own Editor), a full-screen text editor for the Shell, for
GFOS (AmigaOS 3.2.3 with GFOpenUp) on a 68040 or 68060, installed as a
GFOpenUp part: `C:joe`. WordStar-style keys (Ctrl-K H for help), syntax
highlighting for about 90 languages, multiple windows, undo, regular
expression search, block filters, macros.

    joe S:Startup-Sequence
    joe Work:src/main.c Work:src/main.h

Status: built for the PC from the same patched sources with the GFOS
terminal code and passing the tests below; the Amiga build is made by the
stove, not yet run in a lab.

## What you need

- GFOS: AmigaOS 3.2 with GFOpenUp, a 68040 or 68060. Soft float: the FPU
  is used when there is one (fpuauto), so an LC040 runs it too.
- Nothing else.

Install with `GFOpenUpTool INSTALL Parts/JOE`. The manual is
`SYS:Docs/JOE/man.md` (and `joe.1`); Ctrl-K H shows the key help.

## On AmigaOS

- JOE runs in the Shell's console window: raw keys, the window's own size
  (asked of the console, and again when the window is resized), the
  cursor keys, Shift+up and down for page up and down, Shift+left and
  right for start and end of line.
- Its files: `SYS:Utilities/JOE` (joerc, jmacsrc, jstarrc, jpicorc,
  rjoerc, ftyperc, syntax/, colors/), your own settings and JOE's state
  (history, positions) in `ENVARC:joe/` (or under `HOME` when it is set).
- Text is ISO-8859-1, the Amiga's own character set, when no `LANG` says
  otherwise (`LANG=en_US.UTF-8` for UTF-8 files).
- Paths are AmigaDOS paths: `Work:` and `Work:dir/file`, `T:` for
  temporary files.
- Ctrl-K / (filter a block through a command), `!command` as a file name
  to read (Ctrl-K R) or write (Ctrl-K D): the command runs as an
  AmigaDOS command line with its input and output in `T:`.
- Locks (`.#file`, shown when someone else edits the file) are small
  plain files: AmigaOS 3 has no symbolic links.
- Ctrl-K Z opens a Shell in the same window (`EndShell` to return).
- Not offered: shell windows (Ctrl-K ', the `run` and `build` commands);
  they need ptys, which AmigaOS does not have.
- Only `C:joe` is installed; the jmacs, jstar, jpico and rjoe
  personalities are chosen by the name JOE is started by, so a copy of
  `C:joe` named `C:jmacs` gives the Emacs keys.
- 128 KB of stack is set in the program, so the Shell's 4 KB is enough.

## Building

    STOVE=~/AmiCradle/stoves/os32-gcc16-open6 OUT=out sh build-amiga.sh

or in Cradle, stove_build with the os32-gcc16-open6 stove, target `.`.
JOE and fpuauto are fetched at the commits `joe.lock` pins. `OUT` gets
`Parts/JOE`.

## Tests

`make -C tests test` on a PC: the Part file, the console input parser
(`amiga/gfcsi.c`: keys pass, the size report and resize event are
taken), then `tests/host-joe.sh`, which builds JOE for the PC as for GFOS
(`JOE_GFOS`, the same probe, `amiga/joe_tty.c`, with `tests/gfcon_host.c`
as the console) and drives it with keys from a pipe, with no `HOME`,
`TERM` or `LANG`, in a drawer laid out as the part installs it:

1. a new file typed and saved; state in `ENVARC:joe`; no lock left,
2. the console's cursor keys (CSI C, B, D), and Shift+cursor for start
   and end of line,
3. the screen drawn for the size the console reports,
4. a resize event: the size asked again and the screen redrawn,
5. a block filtered through a command, `T:` left clean,
6. `!command` read and written,
7. our lock file and another user's,
8. started as `SYS:C/jmacs`: the Emacs keys from jmacsrc,
9. the console closing with changes: `DEADJOE`.

## What was changed

- `amiga/joe_tty.c` in place of `joe/tty.c`: the terminal on
  `amiga/gfcon.h` (raw mode, reads with a timeout for the status line
  clock, the window size, commands); no ptys.
- `amiga/gfcsi.c`: console input; `amiga/gfcon_amiga.c`: the console on
  dos.library (SetMode, WaitForChar, SystemTagList), stack, `$VER`,
  Ctrl-C as a key.
- `amiga/joe_compat.c`: what libnix may not have (fchmod, ioctl, kill,
  umask, random, lstat, creat), taken only where the probe finds none.
- `patches/0001` (all under `JOE_GFOS`): AmigaDOS volume names in path
  handling, `T:` and `ENVARC:joe/`, the console's termcap entry when
  there is no `TERM`, commands through files in `T:` in place of fork and
  pipes, plain-file locks, ISO-8859-1 by default, termcap keys with the
  top bit set matching what is typed, no crash with no `TERM`.
- `scripts/joe-common.sh`: the sources, fetching and the probe writing
  `autoconf.h`; `scripts/joe-data.sh`: the rc files and data.

JOE is GPL-2.0 (`SYS:Docs/JOE/COPYING-JOE`); `amiga/joe_tty.c` is based
on its `tty.c`; the other files here are MIT.

Designed, tested and delivered by The AmiCradle Team.
