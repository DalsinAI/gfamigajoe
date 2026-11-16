/* What JOE calls that a C library may not have (libnix on GFOS): taken
 * only where scripts/joe-common.sh's probe found none (HAVE_...).
 * AmigaOS keeps its own protection bits, so JOE's Unix modes are not
 * applied; there are no signals to send and no terminal ioctls.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifndef HAVE_FCHMOD
int fchmod(int fd, mode_t mode)
{
	(void)fd; (void)mode;
	return 0;
}
#endif

#ifndef HAVE_IOCTL
int ioctl(int fd, unsigned long req, ...)
{
	(void)fd; (void)req;
	errno = ENOTTY;
	return -1;
}
#endif

#ifndef HAVE_KILL
int kill(pid_t pid, int sig)
{
	(void)pid; (void)sig;
	errno = ESRCH;
	return -1;
}
#endif

#ifndef HAVE_UMASK
mode_t umask(mode_t mask)
{
	(void)mask;
	return 022;
}
#endif

#ifndef HAVE_RANDOM
long random(void)
{
	return (long)rand();
}
#endif

#ifndef HAVE_LSTAT
int lstat(const char *path, struct stat *buf)
{
	return stat(path, buf);
}
#endif

#ifndef HAVE_CREAT
int creat(const char *path, mode_t mode)
{
	return open(path, O_WRONLY | O_CREAT | O_TRUNC, mode);
}
#endif

/* keeps the file from being empty when the C library has everything */
int gfjoe_compat_present;
