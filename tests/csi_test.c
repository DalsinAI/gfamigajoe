/* PC test for amiga/gfcsi.c: the console's answers are kept, keys pass.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#include <stdio.h>
#include <string.h>
#include "gfcsi.h"

static int fails;

/* feeds s (n bytes), returns what JOE gets in got (count in *ng) */
static void feed(struct gfcsi *c, const char *s, int n, char *got, int *ng)
{
	char out[GFCSI_MAX + 1];
	int i, k;
	*ng = 0;
	for (i = 0; i < n; ++i) {
		k = gfcsi_feed(c, (unsigned char)s[i], out);
		memcpy(got + *ng, out, (size_t)k);
		*ng += k;
	}
}

static void expect(const char *what, const char *in, int nin, const char *want, int nwant)
{
	struct gfcsi c;
	char got[256];
	int ng;
	gfcsi_init(&c);
	feed(&c, in, nin, got, &ng);
	if (ng != nwant || memcmp(got, want, (size_t)ng) != 0) {
		printf("FAIL: %s: %d bytes out, want %d\n", what, ng, nwant);
		fails++;
	}
}

#define S(x) x, (int)(sizeof(x) - 1)

int main(void)
{
	struct gfcsi c;
	char got[256];
	int ng;

	expect("plain keys", S("abc\r\033x"), S("abc\r\033x"));
	expect("up arrow", S("\233A"), S("\233A"));
	expect("shift up (page up)", S("\233T"), S("\233T"));
	expect("F1", S("\2330~"), S("\2330~"));
	expect("help", S("\233?~"), S("\233?~"));
	expect("shift left (home)", S("\233 A"), S("\233 A"));
	expect("keys around a key sequence", S("x\233Dy"), S("x\233Dy"));

	/* the size report is ours, keys on either side are JOE's */
	gfcsi_init(&c);
	feed(&c, S("a\2331;1;30;100 rb"), got, &ng);
	if (ng != 2 || memcmp(got, "ab", 2) || !c.size_seen || c.rows != 30 || c.cols != 100) {
		printf("FAIL: size report: %d bytes, seen %d, %d x %d\n", ng, c.size_seen, c.rows, c.cols);
		fails++;
	}
	/* a bad report is passed on, not taken */
	gfcsi_init(&c);
	feed(&c, S("\2331;1;x r"), got, &ng);
	if (c.size_seen || ng != 8) {
		printf("FAIL: bad size report taken (%d bytes)\n", ng);
		fails++;
	}
	gfcsi_init(&c);
	feed(&c, S("\2331;1;0;80 r"), got, &ng);
	if (c.size_seen) {
		printf("FAIL: zero rows taken\n");
		fails++;
	}
	/* the resize event is ours */
	gfcsi_init(&c);
	feed(&c, S("\23312;0;0;0;0;0;0;0|q"), got, &ng);
	if (ng != 1 || got[0] != 'q' || !c.resized) {
		printf("FAIL: resize event: %d bytes, resized %d\n", ng, c.resized);
		fails++;
	}
	/* other raw events (class 2, mouse) pass on */
	expect("other raw event", S("\2332;0;104;0;10;10;0;0|"), S("\2332;0;104;0;10;10;0;0|"));
	/* a sequence that never ends is passed on at GFCSI_MAX bytes */
	{
		char in[GFCSI_MAX + 2], want[GFCSI_MAX + 2];
		in[0] = (char)0x9B;
		memset(in + 1, '1', GFCSI_MAX);
		memcpy(want, in, GFCSI_MAX + 1);
		expect("overlong", in, GFCSI_MAX + 1, want, GFCSI_MAX + 1);
	}
	if (fails == 0)
		printf("Console input: all checks passed\n");
	return fails != 0;
}
