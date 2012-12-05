# Makefile for windows.

RDMD=rdmd
DMD=dmd
EXE=volt.exe
DFLAGS=--build-only --compiler=$(DMD) -of$(EXE) -gc -w -debug $(FLAGS)

# rules
all:
	$(RDMD) $(DFLAGS) src\main.d

.PHONY: all
