/* amiga/gfcon.h on a PC, for the tests: keys come from stdin (a pipe the
 * test fills), the screen goes to stdout, and the console's answer to the
 * size request is made here: GFCON_ROWS x GFCON_COLS (25 x 80), then
 * GFCON_ROWS2 x GFCON_COLS2 after the first answer when those are set
 * (a resize). Commands run through /bin/sh, "NIL:" being /dev/null.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#define _GNU_SOURCE 1
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>
#include <sys/wait.h>
#include "gfcon.h"
#include "gfcsi.h"

static char pending[64];
static int npend, answers;

static int envnum(const char *a, const char *b, int def)
{
	const char *s = NULL;
	if (b && answers > 0)
		s = getenv(b);
	if (!s)
		s = getenv(a);
	return s ? atoi(s) : def;
}

int gfcon_open(void)
{
	return 0;
}

void gfcon_close(void)
{
}

long gfcon_read(char *buf, long n, long timeout_us)
{
	long r;
	if (npend) {
		long k = npend < n ? npend : n;
		memcpy(buf, pending, (size_t)k);
		memmove(pending, pending + k, (size_t)(npend - k));
		npend -= (int)k;
		return k;
	}
	if (timeout_us >= 0) {
		fd_set set;
		struct timeval tv;
		FD_ZERO(&set);
		FD_SET(0, &set);
		tv.tv_sec = timeout_us / 1000000;
		tv.tv_usec = timeout_us % 1000000;
		if (select(1, &set, NULL, NULL, &tv) <= 0)
			return 0;
	}
	r = read(0, buf, (size_t)n);
	return r > 0 ? r : -1;
}

long gfcon_write(const char *buf, long n)
{
	long done = 0;
	if (memmem(buf, (size_t)n, GFCSI_SIZE_REQUEST, sizeof(GFCSI_SIZE_REQUEST) - 1)) {
		int rows = envnum("GFCON_ROWS", "GFCON_ROWS2", 25);
		int cols = envnum("GFCON_COLS", "GFCON_COLS2", 80);
		npend = snprintf(pending, sizeof(pending), "\2331;1;%d;%d r", rows, cols);
		++answers;
	}
	while (done < n) {
		ssize_t w = write(1, buf + done, (size_t)(n - done));
		if (w <= 0)
			return -1;
		done += w;
	}
	return n;
}

static const char *host_name(const char *f)
{
	return strcmp(f, "NIL:") == 0 ? "/dev/null" : f;
}

int gfcon_run(const char *cmd, const char *in, const char *out)
{
	pid_t pid;
	int st = 0;
	fflush(stdout);
	pid = fork();
	if (pid == 0) {
		int fd;
		if (in && (fd = open(host_name(in), O_RDONLY)) >= 0) { dup2(fd, 0); close(fd); }
		if (out && (fd = open(host_name(out), O_WRONLY | O_CREAT | O_TRUNC, 0600)) >= 0) { dup2(fd, 1); close(fd); }
		execl("/bin/sh", "sh", "-c", (cmd && *cmd) ? cmd : "exit 0", (char *)NULL);
		_exit(127);
	}
	if (pid < 0)
		return -1;
	waitpid(pid, &st, 0);
	return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}

/* The tests' stdin is a pipe standing in for the console: JOE must take
 * it as the terminal, not as a file to edit (main.c asks isatty(0)) */
int isatty(int fd)
{
	return fd == 0 || fd == 1;
}
