########################################
# Find which compilers are installed.
#
DMD ?= $(shell which dmd)
HOST_UNAME := $(strip $(shell uname))
HOST_MACHINE := $(strip $(shell uname -m))
UNAME ?= $(HOST_UNAME)
MACHINE ?= $(strip $(shell uname -m))
LLVM_CONFIG ?= llvm-config
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --ldflags --libs core analysis scalaropts bitwriter ipo)

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
LINK_FLAGS = -quiet -of$(TARGET) $(OBJ) $(LDFLAGS_) $(patsubst -%, -L-%, $(LLVM_LDFLAGS)) -L-ldl -L-lstdc++


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


all: rt/rt.bc

$(OBJ_DIR)/%.$(OBJ_TYPE) : src/%.d Makefile
	@echo "  DMD    src/$*.d"
	@mkdir -p $(dir $@)
	@$(DMD) $(DCOMP_FLAGS) src/$*.d

rt/rt.bc: $(TARGET) rt/src/object.v rt/src/vrt/vmain.v rt/src/vrt/gc.v
	@echo "  VOLT   rt/rt.bc"
	@./$(TARGET) --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc rt/src/object.v rt/src/vrt/vmain.v rt/src/vrt/gc.v

$(TARGET): $(OBJ) Makefile
	@echo "  LD     $@"
	@$(DMD) $(LINK_FLAGS)

clean:
	@rm -rf $(TARGET) .obj
	@rm -f rt/rt.bc

run: $(TARGET)
	@./$(TARGET) --internal-dbg -o a.out.exe test/simple/test_001.d
	@./a.out.exe

debug: $(TARGET)
	@gdb --args ./$(TARGET) test/simple/test_001.d

test: all
	@make -C test run

license: $(TARGET)
	@./$(TARGET) --license

.PHONY: all test clean run debug license
