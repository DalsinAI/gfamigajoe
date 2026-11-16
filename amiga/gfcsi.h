/* Console input on GFOS: the Amiga console sends CSI (0x9B) sequences for
 * cursor and function keys, its window size report and its resize event.
 * gfcsi_feed takes the bytes one by one: key sequences go on to JOE as
 * they came (joerc binds them: "^# A" is CSI A, the up arrow), the size
 * report and the resize event, which are answers to us, are kept here.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#ifndef GFCSI_H
#define GFCSI_H

#define GFCSI_MAX 40

struct gfcsi {
	int in;			/* inside a CSI sequence */
	int len;
	char buf[GFCSI_MAX + 1];
	int rows, cols;		/* from the last window size report */
	int size_seen;		/* set when a report came */
	int resized;		/* set when the window was resized */
};

void gfcsi_init(struct gfcsi *s);
/* feed one byte; what JOE should read goes to out (at most GFCSI_MAX + 1
 * bytes), the count is returned */
int gfcsi_feed(struct gfcsi *s, unsigned char c, char *out);

/* asks the console for the window size: CSI 0 SPACE q */
#define GFCSI_SIZE_REQUEST "\2330 q"
/* resize events on/off: CSI 12 { and CSI 12 } */
#define GFCSI_RESIZE_ON "\23312{"
#define GFCSI_RESIZE_OFF "\23312}"

#endif
