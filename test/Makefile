# Common Makefile, pardon the .exe ending.

RDMD=rdmd
DMD=dmd
EXE=runner.exe
DFLAGS=--build-only --compiler=$(DMD) -of$(EXE) -gc -w -debug $(FLAGS)

# rules
all:
	@$(RDMD) $(DFLAGS) runner.d

run: all
	@./$(EXE)

.PHONY: all run
