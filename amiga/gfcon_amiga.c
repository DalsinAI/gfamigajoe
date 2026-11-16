/* amiga/gfcon.h on GFOS: the AmigaDOS console through dos.library, and
 * the program's stack, $VER and Ctrl-C handling.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#include <proto/dos.h>
#include <dos/dos.h>
#include <dos/dostags.h>
#include <utility/tagitem.h>
#include "gfcon.h"

/* JOE's undo, syntax highlighting and regular expressions recurse */
unsigned long __stack = 128 * 1024;
static const char version[] __attribute__((used)) =
	"$VER: joe " JOE_AMIGA_VERSION " (" JOE_AMIGA_DATE ") GFOS";

/* Ctrl-C is a key in JOE (abort the prompt), not a break: libnix's
 * check for it is off */
void __chkabort(void)
{
}

static BPTR con_in, con_out;
static int raw;

static void handles(void)
{
	if (!con_in) {
		con_in = Input();
		con_out = Output();
	}
}

int gfcon_open(void)
{
	handles();
	if (!raw && IsInteractive(con_in)) {
		SetMode(con_in, 1);
		raw = 1;
	}
	return 0;
}

void gfcon_close(void)
{
	if (raw) {
		SetMode(con_in, 0);
		raw = 0;
	}
}

long gfcon_read(char *buf, long n, long timeout_us)
{
	LONG r;

	handles();
	/* a file in place of the console (keys from a script) is read as it is */
	if (timeout_us >= 0 && IsInteractive(con_in) && !WaitForChar(con_in, timeout_us))
		return 0;
	r = Read(con_in, buf, n);
	return r > 0 ? r : -1;
}

long gfcon_write(const char *buf, long n)
{
	handles();
	return Write(con_out, (APTR)buf, n) == n ? n : -1;
}

int gfcon_run(const char *cmd, const char *in, const char *out)
{
	BPTR fi, fo;
	LONG rc;
	struct TagItem tags[4];

	handles();
	fi = in ? Open((CONST_STRPTR)in, MODE_OLDFILE) : con_in;
	fo = out ? Open((CONST_STRPTR)out, MODE_NEWFILE) : con_out;
	if (!fi || !fo) {
		if (in && fi)
			Close(fi);
		if (out && fo)
			Close(fo);
		return -1;
	}
	tags[0].ti_Tag = SYS_Input;
	tags[0].ti_Data = (ULONG)fi;
	tags[1].ti_Tag = SYS_Output;
	tags[1].ti_Data = (ULONG)fo;
	tags[2].ti_Tag = SYS_UserShell;
	tags[2].ti_Data = TRUE;
	tags[3].ti_Tag = TAG_END;
	tags[3].ti_Data = 0;
	/* an empty command with the console as input: an interactive Shell
	   there, until EndShell */
	rc = SystemTagList((CONST_STRPTR)((cmd && *cmd) ? cmd : ""), tags);
	if (in)
		Close(fi);
	if (out)
		Close(fo);
	return (int)rc;
}
