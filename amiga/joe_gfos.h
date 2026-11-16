/* Taken into every JOE file on GFOS (after autoconf.h): JOE_GFOS turns on
 * patches/0001's AmigaOS code, and what AmigaOS has none of.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#ifndef JOE_GFOS_H
#define JOE_GFOS_H
#define JOE_GFOS 1

/* amiga/gfcon.h: commands for ^K !, filters and !cmd file names */
int gfcon_run(const char *cmd, const char *in, const char *out);

/* amiga/joe_compat.c's stand-ins, declared where the headers have none */
#include <sys/types.h>
#include <sys/stat.h>
#ifndef HAVE_FCHMOD
int fchmod(int fd, mode_t mode);
#endif
#ifndef HAVE_IOCTL
int ioctl(int fd, unsigned long req, ...);
#endif
#ifndef HAVE_KILL
int kill(pid_t pid, int sig);
#endif
#ifndef HAVE_UMASK
mode_t umask(mode_t mask);
#endif
#ifndef HAVE_RANDOM
long random(void);
#endif
#ifndef HAVE_LSTAT
int lstat(const char *path, struct stat *buf);
#endif
#ifndef HAVE_CREAT
int creat(const char *path, mode_t mode);
#endif

#ifndef HAVE_PWD_H
/* no users: ~name is left as it is, and tab completion offers none */
struct passwd { char *pw_name; char *pw_dir; };
#define getpwnam(n) ((struct passwd *)0)
#define getpwent() ((struct passwd *)0)
#define endpwent() ((void)0)
#endif

#endif
