/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.TargetMachine;

public import lib.llvm.c.Types;
import lib.llvm.c.Target;


struct LLVMTargetMachine {} alias  LLVMTargetMachineRef = LLVMTargetMachine*;
struct LLVMTarget {} alias LLVMTargetRef = LLVMTarget*;
version (LLVMVersion18AndAbove) {
	struct LLVMTargetMachineOptions {} alias LLVMTargetMachineOptionsRef = LLVMTargetMachineOptions*;
}


extern(C):

//#--- Auto generated below ---#
enum LLVMCodeGenFileType {
	Assembly = 0,
	Object = 1,
}
enum LLVMCodeGenOptLevel {
	None = 0,
	Less = 1,
	Default = 2,
	Aggressive = 3,
}
enum LLVMCodeModel {
	Default = 0,
	JITDefault = 1,
	Tiny = 2,
	Small = 3,
	Kernel = 4,
	Medium = 5,
	Large = 6,
}
enum LLVMRelocMode {
	Default = 0,
	Static = 1,
	PIC = 2,
	DynamicNoPic = 3,
	ROPI = 4,
	RWPI = 5,
	ROPI_RWPI = 6,
}
version(LLVMVersion18AndAbove) {
	enum LLVMGlobalISelAbortMode {
		Enable = 0,
		Disable = 1,
		DisableWithDiag = 2,
	}
}
void LLVMAddAnalysisPasses(LLVMTargetMachineRef T, LLVMPassManagerRef PM);
LLVMTargetDataRef LLVMCreateTargetDataLayout(LLVMTargetMachineRef T);
LLVMTargetMachineRef LLVMCreateTargetMachine(LLVMTargetRef T, const(char)* Triple, const(char)* CPU, const(char)* Features, LLVMCodeGenOptLevel Level, LLVMRelocMode Reloc, LLVMCodeModel CodeModel);
void LLVMDisposeTargetMachine(LLVMTargetMachineRef T);
char* LLVMGetDefaultTargetTriple();
LLVMTargetRef LLVMGetFirstTarget();
char* LLVMGetHostCPUFeatures();
char* LLVMGetHostCPUName();
LLVMTargetRef LLVMGetNextTarget(LLVMTargetRef T);
const(char)* LLVMGetTargetDescription(LLVMTargetRef T);
LLVMTargetRef LLVMGetTargetFromName(const(char)* Name);
LLVMBool LLVMGetTargetFromTriple(const(char)* Triple, LLVMTargetRef* T, char** ErrorMessage);
char* LLVMGetTargetMachineCPU(LLVMTargetMachineRef T);
char* LLVMGetTargetMachineFeatureString(LLVMTargetMachineRef T);
LLVMTargetRef LLVMGetTargetMachineTarget(LLVMTargetMachineRef T);
char* LLVMGetTargetMachineTriple(LLVMTargetMachineRef T);
const(char)* LLVMGetTargetName(LLVMTargetRef T);
char* LLVMNormalizeTargetTriple(const(char)* triple);
void LLVMSetTargetMachineAsmVerbosity(LLVMTargetMachineRef T, LLVMBool VerboseAsm);
LLVMBool LLVMTargetHasAsmBackend(LLVMTargetRef T);
LLVMBool LLVMTargetHasJIT(LLVMTargetRef T);
LLVMBool LLVMTargetHasTargetMachine(LLVMTargetRef T);
LLVMBool LLVMTargetMachineEmitToMemoryBuffer(LLVMTargetMachineRef T, LLVMModuleRef M, LLVMCodeGenFileType codegen, char** ErrorMessage, LLVMMemoryBufferRef* OutMemBuf);
version(LLVMVersion15AndAbove) {
	LLVMBool LLVMTargetMachineEmitToFile(LLVMTargetMachineRef T, LLVMModuleRef M, const(char)* Filename, LLVMCodeGenFileType codegen, char** ErrorMessage);
} else {
	LLVMBool LLVMTargetMachineEmitToFile(LLVMTargetMachineRef T, LLVMModuleRef M, char* Filename, LLVMCodeGenFileType codegen, char** ErrorMessage);
}
version(LLVMVersion18AndAbove) {
	LLVMTargetMachineOptionsRef LLVMCreateTargetMachineOptions();
	LLVMTargetMachineRef LLVMCreateTargetMachineWithOptions(LLVMTargetRef T, const(char)* Triple, LLVMTargetMachineOptionsRef Options);
	void LLVMDisposeTargetMachineOptions(LLVMTargetMachineOptionsRef Options);
	void LLVMSetTargetMachineFastISel(LLVMTargetMachineRef T, LLVMBool Enable);
	void LLVMSetTargetMachineGlobalISel(LLVMTargetMachineRef T, LLVMBool Enable);
	void LLVMSetTargetMachineGlobalISelAbort(LLVMTargetMachineRef T, LLVMGlobalISelAbortMode Mode);
	void LLVMSetTargetMachineMachineOutliner(LLVMTargetMachineRef T, LLVMBool Enable);
	void LLVMTargetMachineOptionsSetABI(LLVMTargetMachineOptionsRef Options, const(char)* ABI);
	void LLVMTargetMachineOptionsSetCPU(LLVMTargetMachineOptionsRef Options, const(char)* CPU);
	void LLVMTargetMachineOptionsSetCodeGenOptLevel(LLVMTargetMachineOptionsRef Options, LLVMCodeGenOptLevel Level);
	void LLVMTargetMachineOptionsSetCodeModel(LLVMTargetMachineOptionsRef Options, LLVMCodeModel CodeModel);
	void LLVMTargetMachineOptionsSetFeatures(LLVMTargetMachineOptionsRef Options, const(char)* Features);
	void LLVMTargetMachineOptionsSetRelocMode(LLVMTargetMachineOptionsRef Options, LLVMRelocMode Reloc);
}
