.POSIX:
.SUFFIXES:

test:
	mkdir -p bin
	hare build -o bin/test cmd/test

run:
	hare run cmd/test

.PHONY: test run
