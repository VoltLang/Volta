########################################
# Find which compilers are installed.
#
DMD ?= $(shell which dmd)
HOST_UNAME := $(strip $(shell uname))
HOST_MACHINE := $(strip $(shell uname -m))
UNAME ?= $(HOST_UNAME)
MACHINE ?= $(strip $(shell uname -m))
LLVM_CONFIG ?= llvm-config
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --libs core analysis scalaropts bitwriter ipo) $(shell $(LLVM_CONFIG) --ldflags)

ifeq ($(strip $(DMD)),)
  DMD := $(shell which gdmd)
  ifeq ($(strip $(DMD)),)
    DMD = gdmd
  endif
endif

########################################
# The find which platform rules to use.
#
ifeq ($(HOST_UNAME),Linux)
  OBJ_TYPE := o
else
  ifeq ($(HOST_UNAME),Darwin)
    OBJ_TYPE := o
  else
    OBJ_TYPE := obj
  endif
endif


# gdmd's -g exports native D debugging info use
# that instead of emulated c ones that -gc gives us.
ifeq ($(notdir $(DMD)),gdmd)
  DEBUG_DFLAGS = -g -debug
else
  DEBUG_DFLAGS = -gc -debug
endif


CFLAGS ?= -g
DFLAGS ?= $(DEBUG_DFLAGS)
LDFLAGS ?= $(DEBUG_DFLAGS)

DDEFINES_ = $(DDEFINES)
LDFLAGS_ = $(LDFLAGS)
TARGET = volt
CCOMP_FLAGS = $(CARCH) -c -o $@ $(CFLAGS)
MCOMP_FLAGS = $(CARCH) -c -o $@ $(CFLAGS)
DCOMP_FLAGS = -c -w -Isrc $(DDEFINES_) -of$@ $(DFLAGS)
LINK_FLAGS = -of$(TARGET) $(OBJ) $(LDFLAGS_) $(patsubst -%, -L-%, $(LLVM_LDFLAGS)) -L-ldl -L-lstdc++
RUN_FLAGS = --internal-dbg --no-stdlib -I rt/src $(RT_HOST) -l gc
RUN_TARGET = a.out.exe


ifeq ($(UNAME),Linux)
  PLATFORM=linux
else
  ifeq ($(UNAME),Darwin)
    PLATFORM=mac
  else
    ifeq ($(UNAME),WindowsCross)
      # Not tested
      PLATFORM=windows
      TARGET = volt.exe
    else
      # Not tested
      PLATFORM=windows
      TARGET = volt.exe
    endif
  endif
endif

OBJ_DIR=.obj/$(PLATFORM)-$(MACHINE)
DSRC = $(shell find src -name "*.d")
DOBJ = $(patsubst src/%.d, $(OBJ_DIR)/%.$(OBJ_TYPE), $(DSRC))
OBJ := $(DOBJ) $(EXTRA_OBJ)

RT_HOST = rt/libvrt-host.bc
RT_SRC = $(shell find rt/src -name "*.volt")
RT_TARGETS = \
	rt/libvrt-le32-emscripten.bc \
	rt/libvrt-x86-mingw.bc \
	rt/libvrt-x86-linux.bc \
	rt/libvrt-x86_64-linux.bc \
	rt/libvrt-x86-osx.bc \
	rt/libvrt-x86_64-osx.bc


all: $(RT_TARGETS) $(RT_HOST)

$(OBJ_DIR)/%.$(OBJ_TYPE) : src/%.d Makefile
	@echo "  DMD    src/$*.d"
	@mkdir -p $(dir $@)
	@$(DMD) $(DCOMP_FLAGS) src/$*.d

$(RT_HOST): $(TARGET) $(RT_SRC)
	@echo "  VOLT   $@"
	@./$(TARGET) --no-stdlib --emit-bitcode -I rt/src -o $@ $(RT_SRC)

$(RT_TARGETS): $(TARGET) $(RT_SRC)
	@echo "  VOLT   $@"
	@./$(TARGET) --no-stdlib --emit-bitcode -I rt/src -o $@ $(RT_SRC) \
		--arch $(shell echo $@ | sed "s,rt/libvrt-\([^-]*\)-[^.]*.bc,\1,") \
		--platform $(shell echo $@ | sed "s,rt/libvrt-[^-]*-\([^.]*\).bc,\1,")

$(TARGET): $(OBJ) Makefile
	@echo "  LD     $@"
	@$(DMD) $(LINK_FLAGS)

clean:
	@rm -rf $(TARGET) .obj
	@rm -f rt/libvrt-host.bc
	@rm -f $(RT_TARGETS) $(RT_HOST)
	@rm -rf .pkg
	@rm -rf volt.tar.gz

$(RUN_TARGET): $(TARGET) $(RT_HOST) test/simple.volt
	@echo "  VOLT   $(RUN_TARGET)"
	@./$(TARGET) $(RUN_FLAGS) -o a.out.exe test/simple.volt

sanity: $(RUN_TARGET)
	@echo "  SANITY a.out.exe"
	@./a.out.exe; test $$? -eq 42

run: $(RUN_TARGET)
	@echo "  RUN    a.out.exe"
	@-./a.out.exe

debug: $(TARGET) $(RT_HOST)
	@gdb --args ./$(TARGET) $(RUN_FLAGS) -o a.out.exe test/simple.volt

license: $(TARGET)
	@./$(TARGET) --license

package: all
	@mkdir -p .pkg/rt
	@cp volt .pkg/
	@cp $(RT_TARGETS) .pkg/
	@cp -r ./rt/src/* .pkg/rt/
	@tar -czf volt.tar.gz .pkg/*

.PHONY: all clean run debug license
