/*
 *	JOE's terminal interface on GFOS (in place of joe/tty.c)
 *
 *	The AmigaDOS console in raw mode through amiga/gfcon.h: keys are read
 *	with a timeout (the status line clock and the auto-scroller take the
 *	place of SIGALRM), the window size comes from the console's own
 *	report and is asked again only after a resize event (amiga/gfcsi.c
 *	keeps those answers; CSI key sequences reach JOE as they came, which
 *	joerc binds as "^# ...").  There are no ptys:
 *	shell windows are not offered; commands (^K !, filters, !cmd file
 *	names) run through gfcon_run.
 *
 *	Based on joe/tty.c, Copyright (C) 1992 Joseph H. Allen (GPL-2.0).
 *	Changes MIT, Copyright (c) 2026 AmiCradle Team.
 */
#include "types.h"
#include "gfcon.h"
#include "gfcsi.h"

int idleout = 1;
int noxon = 0;			/* Set if ^S/^Q processing should be disabled */
int Baud = 0;			/* Baud rate from joerc, cmd line or environment */

FILE *termin = NULL;
FILE *termout = NULL;

char *obuf = NULL;
ptrdiff_t obufp = 0;
ptrdiff_t obufsiz;

long tty_baud;
long upc;

int have = 0;			/* Set if we have pending input */
char havec;			/* Character read in during pending input check */
int leave = 0;			/* When set, typeahead checking is disabled */

static int ttymode = 0;

MPX asyncs[NPROC];

int ticked = 0;
time_t last_time;
static int winched = 0;

/* bytes from the console after gfcsi, waiting for JOE */
static struct gfcsi csi;
static char inq[512];
static int inq_head, inq_tail;
static int at_end;

/* the window size: asked once, then again after each resize event */
static ptrdiff_t con_cols, con_rows;
static int size_valid;

static int inq_empty(void)
{
	return inq_head == inq_tail;
}

static char inq_pop(void)
{
	char c = inq[inq_head];
	inq_head = (inq_head + 1) % (int)SIZEOF(inq);
	return c;
}

static void inq_push(const char *s, int n)
{
	while (n--) {
		int next = (inq_tail + 1) % (int)SIZEOF(inq);
		if (next == inq_head)
			return;		/* full: the rest is dropped */
		inq[inq_tail] = *s++;
		inq_tail = next;
	}
}

/* Read what the console has, waiting up to timeout_us; -1 at its end */
static int fill(long timeout_us)
{
	char raw[64], out[GFCSI_MAX + 1];
	long n, i;

	if (at_end)
		return -1;
	n = gfcon_read(raw, SIZEOF(raw), timeout_us);
	if (n < 0) {
		at_end = 1;
		return -1;
	}
	for (i = 0; i < n; ++i) {
		int k = gfcsi_feed(&csi, (unsigned char)raw[i], out);
		if (k)
			inq_push(out, k);
	}
	if (csi.resized) {
		csi.resized = 0;
		size_valid = 0;
		++winched;
	}
	return (int)n;
}

void sigjoe(void)
{
}

void signrm(void)
{
}

void ttopen(void)
{
	sigjoe();
	ttopnn();
}

void ttclose(void)
{
	ttclsn();
	signrm();
}

void tickoff(void)
{
}

void tickon(void)
{
	ticked = 0;
}

void ttopnn(void)
{
	if (!termin) {
		termin = stdin;
		termout = stdout;
		gfcsi_init(&csi);
	}
	if (ttymode)
		return;
	ttymode = 1;
	fflush(termout);
	gfcon_open();
	gfcon_write(GFCSI_RESIZE_ON, sizeof(GFCSI_RESIZE_ON) - 1);
	size_valid = 0;

	/* a console is never slower than the screen updates */
	tty_baud = Baud ? Baud : 38400;
	upc = 0;
	if (obuf)
		joe_free(obuf);
	obufsiz = 4096;
	obuf = (char *)joe_malloc(obufsiz);
}

void ttclsn(void)
{
	int oleave;

	if (!ttymode)
		return;
	ttymode = 0;
	oleave = leave;
	leave = 1;
	ttflsh();
	gfcon_write(GFCSI_RESIZE_OFF, sizeof(GFCSI_RESIZE_OFF) - 1);
	gfcon_close();
	leave = oleave;
}

int ttcheck(void)
{
	if (!have && !leave) {
		if (inq_empty())
			fill(0);
		if (!inq_empty()) {
			havec = inq_pop();
			have = 1;
		}
	}
	return have;
}

int ttflsh(void)
{
	if (obufp) {
		gfcon_write(obuf, obufp);
		obufp = 0;
	}
	ttcheck();
	return 0;
}

char ttgetc(void)
{
	MACRO *m;
	time_t new_time;
	int flg;

      loop:
	flg = 0;
	/* Status line clock */
	new_time = time(NULL);
	if (new_time != last_time) {
		last_time = new_time;
		dostaupd = 1;
		ticked = 1;
	}
	/* Autoscroller */
	if (auto_scroll && mnow() >= auto_trig_time) {
		do_auto_scroll();
		ticked = 1;
		flg = 1;
	}
	ttflsh();
	m = timer_play();
	if (m) {
		exemac(m, NO_MORE_DATA);
		edupd(1);
		ttflsh();
	}
	while (winched) {
		winched = 0;
		dostaupd = 1;
		edupd(1);
		ttflsh();
	}
	if (ticked) {
		edupd(flg);
		ttflsh();
		ticked = 0;
	}
	if (have) {
		have = 0;
		return havec;
	}
	if (inq_empty()) {
		long timeout = 1000000;	/* the clock: once a second */
		if (auto_scroll) {
			long ms = auto_trig_time - mnow();
			timeout = ms < 1 ? 1000 : ms * 1000;
		}
		if (fill(timeout) < 0)
			ttsig(0);	/* the console has gone: DEADJOE and out */
		goto loop;
	}
	return inq_pop();
}

static struct utf8_sm main_utf8_sm;

int ttgetch(void)
{
	if (locale_map->type) {
		int utf8_char;
		do {
			char c = ttgetc();
			utf8_char = utf8_decode(&main_utf8_sm, c);
		} while (utf8_char < 0);
		return utf8_char;
	} else {
		char c = ttgetc();
		int utf8_char = to_uni(locale_map, c);
		if (utf8_char == -1)
			utf8_char = '?';
		return utf8_char;
	}
}

void ttputs(const char *s)
{
	while (*s) {
		obuf[obufp++] = *s++;
		if (obufp == obufsiz)
			ttflsh();
	}
}

/* The console's size: the window status report (CSI 0 SPACE q), keys typed
 * meanwhile kept for JOE; 0 x 0 when there is no answer (JOE then takes
 * the termcap entry's co# and li#) */
void ttgtsz(ptrdiff_t *x, ptrdiff_t *y)
{
	if (!size_valid) {
		int tries;
		if (obufp) {
			gfcon_write(obuf, obufp);
			obufp = 0;
		}
		csi.size_seen = 0;
		gfcon_write(GFCSI_SIZE_REQUEST, sizeof(GFCSI_SIZE_REQUEST) - 1);
		for (tries = 0; tries < 5 && !csi.size_seen; ++tries)
			if (fill(100000) < 0)
				break;
		if (csi.size_seen) {
			con_cols = csi.cols;
			con_rows = csi.rows;
		} else {
			con_cols = con_rows = 0;
		}
		size_valid = 1;
	}
	*x = con_cols;
	*y = con_rows;
}

void ttstsz(int fd, ptrdiff_t w, ptrdiff_t h)
{
	(void)fd; (void)w; (void)h;
}

/* A command (or with none, an interactive Shell) in the console */
int ttshell(char *cmd)
{
	int omode = ttymode;
	int rc;

	ttclsn();
	if (!cmd || !*cmd)
		fputs(joe_gettext(_("You are at the command shell.  Type 'endshell' to return\n")), stderr);
	rc = gfcon_run(cmd, NULL, NULL);
	if (omode)
		ttopnn();
	return rc;
}

void ttsusp(void)
{
	ttshell(NULL);
}

/* No ptys and no background tasks on GFOS: shell windows are not offered */
MPX *mpxmk(int *ptyfd, const char *cmd, char **args, void (*func)(void *object, char *data, ptrdiff_t len), void *object, void (*die) (void *object), void *dieobj, int copy_in, ptrdiff_t w, ptrdiff_t h, int use_pipe)
{
	(void)ptyfd; (void)cmd; (void)args; (void)func; (void)object;
	(void)die; (void)dieobj; (void)copy_in; (void)w; (void)h; (void)use_pipe;
	return NULL;
}

void mpxdied(MPX *m);
void mpxdied(MPX *m)
{
	(void)m;
}
