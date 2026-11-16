# PC tests: make test (host-joe.sh fetches JOE at joe.lock's commit)
CC ?= cc
test:
	sh test-part.sh
	mkdir -p ../build-host
	$(CC) -Wall -Wextra -I../amiga -o ../build-host/csi_test csi_test.c ../amiga/gfcsi.c && ../build-host/csi_test
	sh host-joe.sh
.PHONY: test
