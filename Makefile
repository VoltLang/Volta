# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.
# If using the latter, make sure to specify -fMakefile.

include sources.mk

RDMD=rdmd
DMD=dmd
VOLT=volt.exe
VIV=viv.exe
VIVIV=viviv.exe
VRT=rt/rt.bc
DFLAGS=--build-only --compiler=$(DMD) -of$(VOLT) -gc -wi -debug LLVM.lib $(FLAGS)
LLVM_DLL_DIR= # Insert path to LLVM DLLs for viv.
LLVM_VIV_LDFLAGS=-Xlinker $(LLVM_DLL_DIR)\LLVMAnalysis.dll -Xlinker $(LLVM_DLL_DIR)\LLVMAsmParser.dll -Xlinker $(LLVM_DLL_DIR)\LLVMAsmPrinter.dll -Xlinker $(LLVM_DLL_DIR)\LLVMBitReader.dll -Xlinker $(LLVM_DLL_DIR)\LLVMBitWriter.dll -Xlinker $(LLVM_DLL_DIR)\LLVMCodeGen.dll -Xlinker $(LLVM_DLL_DIR)\LLVMCore.dll -Xlinker $(LLVM_DLL_DIR)\LLVMDebugInfo.dll -Xlinker $(LLVM_DLL_DIR)\LLVMExecutionEngine.dll -Xlinker $(LLVM_DLL_DIR)\LLVMInstCombine.dll -Xlinker $(LLVM_DLL_DIR)\LLVMInstrumentation.dll -Xlinker $(LLVM_DLL_DIR)\LLVMInterpreter.dll -Xlinker $(LLVM_DLL_DIR)\LLVMipa.dll -Xlinker $(LLVM_DLL_DIR)\LLVMipo.dll -Xlinker $(LLVM_DLL_DIR)\LLVMIRReader.dll -Xlinker $(LLVM_DLL_DIR)\LLVMJIT.dll -Xlinker $(LLVM_DLL_DIR)\LLVMLineEditor.dll -Xlinker $(LLVM_DLL_DIR)\LLVMLinker.dll -Xlinker $(LLVM_DLL_DIR)\LLVMLTO.dll -Xlinker $(LLVM_DLL_DIR)\LLVMMC.dll -Xlinker $(LLVM_DLL_DIR)\LLVMMCDisassembler.dll -Xlinker $(LLVM_DLL_DIR)\LLVMMCJIT.dll -Xlinker $(LLVM_DLL_DIR)\LLVMMCParser.dll -Xlinker $(LLVM_DLL_DIR)\LLVMObjCARCOpts.dll -Xlinker $(LLVM_DLL_DIR)\LLVMObject.dll -Xlinker $(LLVM_DLL_DIR)\LLVMOption.dll -Xlinker $(LLVM_DLL_DIR)\LLVMProfileData.dll -Xlinker $(LLVM_DLL_DIR)\LLVMRuntimeDyld.dll -Xlinker $(LLVM_DLL_DIR)\LLVMScalarOpts.dll -Xlinker $(LLVM_DLL_DIR)\LLVMSelectionDAG.dll -Xlinker $(LLVM_DLL_DIR)\LLVMSupport.dll -Xlinker $(LLVM_DLL_DIR)\LLVMTableGen.dll -Xlinker $(LLVM_DLL_DIR)\LLVMTarget.dll -Xlinker $(LLVM_DLL_DIR)\LLVMTransformUtils.dll -Xlinker $(LLVM_DLL_DIR)\LLVMVectorize.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86AsmParser.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86AsmPrinter.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86CodeGen.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86Desc.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86Disassembler.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86Info.dll -Xlinker $(LLVM_DLL_DIR)\LLVMX86Utils.dll

# rules
all:
	$(RDMD) $(DFLAGS) src\main.d
	$(VOLT) --no-stdlib --emit-bitcode -I rt/src -o rt/rt.bc $(RT_SRC) $(VFLAGS)
	$(VOLT) --no-stdlib -c -I rt/src -o rt/rt.o rt/rt.bc

viv:
	$(VOLT) --internal-d -o $(VIV) $(VIV_SRC) $(VFLAGS) $(LLVM_VIV_LDFLAGS)

viviv:
	$(VIV) --internal-d -o $(VIVIV) $(VIV_SRC) $(VFLAGS) $(LLVM_VIV_LDFLAGS)

.PHONY: all viv viviv

