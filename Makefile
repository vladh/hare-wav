.POSIX:
.SUFFIXES:
DESTDIR=
PREFIX=/usr/local
SRCDIR=$(PREFIX)/src
HARESRCDIR=$(SRCDIR)/hare
THIRDPARTYDIR=$(HARESRCDIR)/third-party

install:
	mkdir -p "$(DESTDIR)$(THIRDPARTYDIR)"/audio/wav
	install -m644 audio/wav/*.ha "$(DESTDIR)$(THIRDPARTYDIR)"/audio/wav

uninstall:
	rm -rf $(DESTDIR)$(THIRDPARTYDIR)/audio/wav

test:
	mkdir -p bin
	hare build -o bin/test cmd/test

run:
	hare run cmd/test

.PHONY: all check install uninstall test run
