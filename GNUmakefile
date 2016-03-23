########################################
# Find which compilers are installed.
#
DMD ?= $(shell which dmd)
RDMD ?= $(shell which rdmd)
CXX ?= $(shell which g++)
VOLT ?= ./$(TARGET)
HOST_UNAME := $(strip $(shell uname))
HOST_MACHINE := $(strip $(shell uname -m))
UNAME ?= $(HOST_UNAME)
MACHINE ?= $(strip $(shell uname -m))
LLVM_CONFIG ?= llvm-config
LLVM_CXXFLAGS = $(shell $(LLVM_CONFIG) --cxxflags)
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --libs core analysis bitwriter bitreader linker target x86codegen)
LLVM_LDFLAGS := $(LLVM_LDFLAGS) $(shell $(LLVM_CONFIG) --ldflags) -lstdc++
ifeq ($(shell echo "$(LLVM_CONFIG) --system-libs &> /dev/null && echo OK" | bash -t), OK)
  LLVM_LDFLAGS := $(LLVM_LDFLAGS) $(shell $(LLVM_CONFIG) --system-libs)
endif

ifeq ($(strip $(DMD)),)
  DMD := $(shell which gdmd)
  ifeq ($(strip $(DMD)),)
    DMD = gdmd
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
CXXFLAGS ?= -g
DFLAGS ?= $(DEBUG_DFLAGS)
LDFLAGS ?= $(DEBUG_DFLAGS)

DDEFINES_ = $(DDEFINES)
LDFLAGS_ = $(DFLAGS) $(LDFLAGS)
TARGET = volt
VIV_TARGET = viv
VIVIV_TARGET = viviv
DCOMP_FLAGS = -w -Isrc $(DDEFINES_) $(DFLAGS)
CXXCOMP_FLAGS = $(CARCH) $(LLVM_CXXFLAGS) $(CXXFLAGS)
LINK_FLAGS = $(LDFLAGS_) $(patsubst -%, -L-%, $(LLVM_LDFLAGS)) -L-ldl

RUN_SRC = test/test.volt
RUN_FLAGS = --internal-dbg --no-stdlib -I rt/src $(RT_HOST) -l gc
RUN_TARGET = a.out

ifeq ($(UseDIBuilder),y)
  EXTRA_OBJ = $(CXXOBJ)
  DDEFINES_ = -version=UseDIBuilder $(DDEFINES)
endif

ifeq ($(UNAME),Linux)
  PLATFORM = linux
  OBJ_TYPE := o
else
  ifeq ($(UNAME),Darwin)
    OBJ_TYPE := o
    PLATFORM = mac
  else
    OBJ_TYPE := obj
    ifeq ($(UNAME),WindowsCross)
      # Not tested
      PLATFORM = windows
      TARGET = volt.exe
      VIV_TARGET = viv.exe
      VIVIV_TARGET = viv.exe
      RUN_TARGET = a.out.exe
    else
      # Not tested
      PLATFORM=windows
      TARGET = volt.exe
      VIV_TARGET = viv.exe
      VIVIV_TARGET = viv.exe
      RUN_TARGET = a.out.exe
    endif
  endif
endif

include sources.mk
DSRC = $(shell find src -name "*.d")
CXXSRC = $(shell find src -name "*.cpp")
VIV_ALL_SRC = $(DSRC)

OBJ_DIR = .obj/$(PLATFORM)-$(MACHINE)
DOBJ = $(patsubst src/%.d, $(OBJ_DIR)/%.$(OBJ_TYPE), $(DSRC))
CXXOBJ = $(patsubst src/%.cpp, $(OBJ_DIR)/%.$(OBJ_TYPE), $(CXXSRC))
OBJ = $(DOBJ) $(EXTRA_OBJ)

RT_HOST = rt/libvrt-host.bc
RT_TARGETS = \
	rt/libvrt-le32-emscripten.bc \
	rt/libvrt-x86_64-msvc.bc \
	rt/libvrt-x86-metal.bc \
	rt/libvrt-x86_64-metal.bc \
	rt/libvrt-x86-mingw.bc \
	rt/libvrt-x86_64-mingw.bc \
	rt/libvrt-x86-linux.bc \
	rt/libvrt-x86_64-linux.bc \
	rt/libvrt-x86-osx.bc \
	rt/libvrt-x86_64-osx.bc
RT_BIN_TARGETS = \
	rt/libvrt-x86_64-msvc.o \
	rt/libvrt-x86-metal.o \
	rt/libvrt-x86_64-metal.o \
	rt/libvrt-x86-mingw.o \
	rt/libvrt-x86_64-mingw.o \
	rt/libvrt-x86-linux.o \
	rt/libvrt-x86_64-linux.o \
	rt/libvrt-x86-osx.o \
	rt/libvrt-x86_64-osx.o


all: $(RT_HOST) $(RT_TARGETS) $(RT_BIN_TARGETS)

$(OBJ_DIR)/%.$(OBJ_TYPE) : src/%.cpp Makefile
	@echo "  CXX    src/$*.cpp"
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXCOMP_FLAGS) -c -o $@ src/$*.cpp

$(OBJ_DIR)/%.$(OBJ_TYPE) : src/%.d Makefile
	@echo "  DMD    src/$*.d"
	@mkdir -p $(dir $@)
	@$(DMD) $(DCOMP_FLAGS) -c -of$@ src/$*.d

$(RT_HOST): $(TARGET) $(RT_SRC)
	@echo "  VOLT   $@"
	@./$(TARGET) --no-stdlib --emit-bitcode -I rt/src -o $@ $(RT_SRC)

$(RT_TARGETS): $(TARGET) $(RT_SRC)
	@echo "  VOLT   $@"
	@./$(TARGET) --no-stdlib --emit-bitcode -I rt/src -o $@ $(RT_SRC) \
		--arch $(shell echo $@ | sed "s,rt/libvrt-\([^-]*\)-[^.]*.bc,\1,") \
		--platform $(shell echo $@ | sed "s,rt/libvrt-[^-]*-\([^.]*\).bc,\1,")

rt/%.o : rt/%.bc
	@echo "  VOLT   $@"
	@./$(TARGET) --no-stdlib -o $@ -c -I rt/src $? \
		--arch $(shell echo $@ | sed "s,rt/libvrt-\([^-]*\)-[^.]*.*,\1,") \
		--platform $(shell echo $@ | sed "s,rt/libvrt-[^-]*-\([^.]*\).*,\1,")

old.$(TARGET): $(OBJ)
	@echo "  DMD    $@"
	@$(DMD) $(LINK_FLAGS) -of$@ $(OBJ)

$(TARGET): $(DSRC) $(EXTRA_OBJ)
	@echo "  RDMD   $(TARGET)"
	@$(RDMD) --build-only --compiler=$(DMD) $(DCOMP_FLAGS) $(LINK_FLAGS) $(EXTRA_OBJ) -of$(TARGET) src/main.d

clean:
	@rm -rf $(TARGET) $(RUN_TARGET) .obj
	@rm -f $(RT_TARGETS) $(RT_HOST)
	@rm -f $(VIV_TARGET)
	@rm -f $(VIVIV_TARGET)
	@rm -rf .pkg
	@rm -rf volt.tar.gz

$(RUN_TARGET): $(TARGET) $(RT_HOST) $(RUN_SRC)
	@echo "  VOLT   $(RUN_TARGET)"
	@./$(TARGET) $(RUN_FLAGS) -o $(RUN_TARGET) $(RUN_SRC)

sanity: $(RUN_TARGET)
	@echo "  SANITY $(RUN_TARGET)"
	@./$(RUN_TARGET); test $$? -eq 42

run: $(RUN_TARGET)
	@echo "  RUN    $(RUN_TARGET)"
	@-./$(RUN_TARGET)

debug: $(TARGET)
	@gdb --args ./$(TARGET) --no-stdlib --emit-bitcode -I rt/src -o $(RT_HOST) $(RT_SRC)
	@gdb --args ./$(TARGET) $(RUN_FLAGS) -o $(RUN_TARGET) $(RUN_SRC)

license: $(TARGET)
	@./$(TARGET) --license

package: all
	@mkdir -p .pkg/rt
	@cp volt .pkg/
	@cp $(RT_TARGETS) $(RT_BIN_TARGETS) .pkg/
	@cp -r ./rt/src/* .pkg/rt/
	@tar -czf volt.tar.gz .pkg/*

$(VIV_TARGET): $(TARGET) $(VIV_SRC)
	@echo "  VOLTA  $(VIV_TARGET)"
	@$(VOLT) --internal-perf --internal-d -o $(VIV_TARGET) $(VIV_SRC) $(LLVM_LDFLAGS)

$(VIVIV_TARGET): $(VIV_TARGET) $(VIV_SRC)
	@echo "  VOLTA  $(VIVIV_TARGET)"
	@$(VIV_TARGET) --internal-perf --internal-d -o $(VIVIV_TARGET) $(VIV_SRC) $(LLVM_LDFLAGS)


# Note these should not depend on target
voltaic-syntax:
	@echo "  VOLTA  <source>"
	@$(VOLT) --internal-perf -E $(VIV_SRC)

voltaic-viv:
	@echo "  VOLTA  $(VIV_TARGET)"
	@$(VOLT) --internal-perf --internal-d -o $(VIV_TARGET) $(VIV_SRC) $(LLVM_LDFLAGS)

voltaic-viviv:
	@echo "  VIV    $(VIVIV_TARGET)"
	@./viv --internal-perf --internal-d -o $(VIVIV_TARGET) $(VIV_SRC) $(LLVM_LDFLAGS)

voltaic-viv-sanity:
	@echo "  VIV    $(RUN_TARGET)"
	@./viv -o $(RUN_TARGET) $(RUN_SRC)

voltaic-viv-syntax:
	@echo "  VIV    <source>"
	@./viv -E $(VIV_SRC)


.PHONY: all clean rdmd run debug license voltaic-syntax voltaic-viv voltaic-viv-syntax
