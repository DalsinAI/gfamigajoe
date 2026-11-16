/* See gfcsi.h. MIT, Copyright (c) 2026 AmiCradle Team. */
#include <string.h>
#include <stdlib.h>
#include "gfcsi.h"

void gfcsi_init(struct gfcsi *s)
{
	memset(s, 0, sizeof(*s));
}

/* "top;left;bottom;right r" (bottom = rows, right = columns), 1 on success */
static int size_report(struct gfcsi *s)
{
	int v[4], n = 0;
	char *p = s->buf, *e;

	while (n < 4) {
		long x = strtol(p, &e, 10);
		if (e == p)
			return 0;
		v[n++] = (int)x;
		if (*e != ';')
			break;
		p = e + 1;
	}
	if (n != 4 || strcmp(e, " r") != 0 || v[2] < 1 || v[3] < 1)
		return 0;
	s->rows = v[2];
	s->cols = v[3];
	s->size_seen = 1;
	return 1;
}

static int pass_on(struct gfcsi *s, char *out)
{
	out[0] = (char)0x9B;
	memcpy(out + 1, s->buf, (size_t)s->len);
	s->in = 0;
	return s->len + 1;
}

int gfcsi_feed(struct gfcsi *s, unsigned char c, char *out)
{
	if (!s->in) {
		if (c == 0x9B) {
			s->in = 1;
			s->len = 0;
			s->buf[0] = 0;
			return 0;
		}
		out[0] = (char)c;
		return 1;
	}
	s->buf[s->len++] = (char)c;
	s->buf[s->len] = 0;
	if (c >= 0x40 && c <= 0x7E) {
		/* the final byte */
		if (c == 'r' && size_report(s)) {
			s->in = 0;
			return 0;
		}
		if (c == '|' && strncmp(s->buf, "12;", 3) == 0) {
			s->resized = 1;
			s->in = 0;
			return 0;
		}
		return pass_on(s, out);
	}
	if (s->len == GFCSI_MAX)
		return pass_on(s, out);
	return 0;
}
