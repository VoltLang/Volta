########################################
# Find which compilers are installed.
#
DMD ?= $(shell which dmd)
RDMD ?= $(shell which rdmd)
CXX ?= $(shell which g++)
NASM ?= $(shell which nasm)
VOLT ?= ./$(TARGET)
HOST_UNAME := $(strip $(shell uname))
HOST_MACHINE := $(strip $(shell uname -m))
UNAME ?= $(HOST_UNAME)
MACHINE ?= $(strip $(shell uname -m))
LLVM_CONFIG ?= llvm-config
LLVM_CXXFLAGS = $(shell $(LLVM_CONFIG) --cxxflags)
LLVM_LDFLAGS = $(shell $(LLVM_CONFIG) --libs core analysis bitwriter bitreader linker target engine x86codegen aarch64codegen armcodegen)
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

CFLAGS ?= -g
CXXFLAGS ?= -g
DFLAGS ?= -g -debug
LDFLAGS ?=

DDEFINES_ = $(DDEFINES)
LDFLAGS_ = $(LDFLAGS)
TARGET = volt
DCOMP_FLAGS = -w -Isrc -Ilib/src -Idsupport/src $(DDEFINES_) $(DFLAGS)
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
  ifeq ($(MACHINE),x86_64)
    NASM_FORMAT = elf64
  else
    NASM_FORMAT = elf32
  endif
else
  ifeq ($(UNAME),Darwin)
    OBJ_TYPE := o
    PLATFORM = mac
    NASM_FORMAT = macho64
  else
    OBJ_TYPE := obj
    ifeq ($(UNAME),WindowsCross)
      # Not tested
      PLATFORM = windows
      TARGET = volt.exe
      RUN_TARGET = a.out.exe
      NASM_FORMAT = win
    else
      # Not tested
      PLATFORM = windows
      TARGET = volt.exe
      RUN_TARGET = a.out.exe
      NASM_FORMAT = win
    endif
  endif
endif

include sources.mk
DSRC = $(shell find src -name "*.d") \
	$(shell find lib/src -name "*.d") \
	$(shell find dsupport/src -name "*.d")
CXXSRC = $(shell find src -name "*.cpp")

OBJ_DIR = .obj/$(PLATFORM)-$(MACHINE)
DOBJ = $(patsubst src/%.d, $(OBJ_DIR)/%.$(OBJ_TYPE), $(DSRC))
CXXOBJ = $(patsubst src/%.cpp, $(OBJ_DIR)/%.$(OBJ_TYPE), $(CXXSRC))
OBJ = $(DOBJ) $(EXTRA_OBJ)

SAVE_REGS_SRC = rt/src/vrt/gc/save_regs.asm
SAVE_REGS_TARGET = rt/save-regs-host.o
RT_HOST = rt/libvrt-host.bc
RT_TARGETS = \
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


all: $(RT_HOST) $(RT_TARGETS) $(RT_BIN_TARGETS) $(SAVE_REGS_TARGET)

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
	@$(DMD) $(DCOMP_FLAGS) $(LINK_FLAGS) -of$@ $(OBJ)

$(TARGET): $(DSRC) $(EXTRA_OBJ)
	@echo "  RDMD   $(TARGET)"
	@$(RDMD) --build-only --compiler=$(DMD) $(DCOMP_FLAGS) $(LINK_FLAGS) $(EXTRA_OBJ) -of$(TARGET) src/main.d

$(SAVE_REGS_TARGET): $(SAVE_REGS_SRC) Makefile
	@echo "  NASM   $(SAVE_REGS_TARGET)"
	@$(NASM) -f $(NASM_FORMAT) -o $(SAVE_REGS_TARGET) $(SAVE_REGS_SRC)

clean:
	@rm -rf $(TARGET) $(RUN_TARGET) .obj
	@rm -f $(RT_TARGETS) $(RT_HOST)
	@rm -f $(SAVE_REGS_TARGET)
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


.PHONY: all clean rdmd run debug license
