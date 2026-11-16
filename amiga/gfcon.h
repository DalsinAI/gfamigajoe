/* The console under JOE on GFOS: what amiga/joe_tty.c needs from it.
 * amiga/gfcon_amiga.c is the AmigaDOS console (dos.library: raw mode,
 * WaitForChar, SystemTags); tests/gfcon_host.c is a PC stand-in the tests
 * drive through pipes.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#ifndef GFCON_H
#define GFCON_H

/* raw mode on (keys one by one, no echo); 0 when done */
int gfcon_open(void);
/* back to the Shell's line mode */
void gfcon_close(void);
/* up to n bytes; waits up to timeout_us (-1: until there is one, 0: only
 * what is there); returns the count, 0 when none came, -1 at the end */
long gfcon_read(char *buf, long n, long timeout_us);
/* all n bytes; -1 on error */
long gfcon_write(const char *buf, long n);
/* runs an AmigaDOS command line; in/out are file names, NULL for the
 * console (and cmd NULL or "" for an interactive Shell there); its rc */
int gfcon_run(const char *cmd, const char *in, const char *out);

#endif
