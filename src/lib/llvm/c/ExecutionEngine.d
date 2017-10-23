/*#D*/
module lib.llvm.c.ExecutionEngine;

import lib.llvm.c.Core;
import lib.llvm.c.Target;
import lib.llvm.c.TargetMachine;

private alias uintptr_t = size_t;
private alias uint64_t = ulong;
private alias uint8_t = ubyte;

struct LLVMGenericValue {};
alias LLVMGenericValueRef  = LLVMGenericValue*;

struct LLVMExecutionEngine {};
alias LLVMExecutionEngineRef  = LLVMExecutionEngine*;

struct LLVMMCJITMemoryManager {};
alias LLVMMCJITMemoryManagerRef  = LLVMMCJITMemoryManager*;


extern(C):

struct LLVMMCJITCompilerOptions {
	uint OptLevel;
	LLVMCodeModel CodeModel;
	LLVMBool NoFramePointerElim;
	LLVMBool EnableFastISel;
	LLVMMCJITMemoryManagerRef MCJMM;
}

alias LLVMMemoryManagerAllocateCodeSectionCallback = uint8_t function(void *Opaque, uintptr_t Size, uint Alignment, uint SectionID, const(char)* SectionName);
alias LLVMMemoryManagerAllocateDataSectionCallback = uint8_t function(void *Opaque, uintptr_t Size, uint Alignment, uint SectionID, const(char)* SectionName, LLVMBool IsReadOnly);
alias LLVMMemoryManagerFinalizeMemoryCallback = LLVMBool function(void *Opaque, char **ErrMsg);
alias LLVMMemoryManagerDestroyCallback = void function(void *Opaque);

void LLVMLinkInMCJIT();
void LLVMLinkInInterpreter();

LLVMGenericValueRef LLVMCreateGenericValueOfInt(LLVMTypeRef Ty, ulong N, LLVMBool IsSigned);
LLVMGenericValueRef LLVMCreateGenericValueOfPointer(void *P);
LLVMGenericValueRef LLVMCreateGenericValueOfFloat(LLVMTypeRef Ty, double N);
uint LLVMGenericValueIntWidth(LLVMGenericValueRef GenValRef);
ulong LLVMGenericValueToInt(LLVMGenericValueRef GenVal, LLVMBool IsSigned);
void* LLVMGenericValueToPointer (LLVMGenericValueRef GenVal);
double LLVMGenericValueToFloat (LLVMTypeRef TyRef, LLVMGenericValueRef GenVal);
void LLVMDisposeGenericValue (LLVMGenericValueRef GenVal);

LLVMBool LLVMCreateExecutionEngineForModule(LLVMExecutionEngineRef *OutEE, LLVMModuleRef M, const(char*)* OutError);
void LLVMInitializeMCJITCompilerOptions(LLVMMCJITCompilerOptions *Options, size_t SizeOfOptions);
LLVMBool LLVMCreateMCJITCompilerForModule(LLVMExecutionEngineRef *OutJIT, LLVMModuleRef M, LLVMMCJITCompilerOptions *Options, size_t SizeOfOptions, const(char*)* OutError);

void LLVMDisposeExecutionEngine(LLVMExecutionEngineRef EE);

void LLVMRunStaticConstructors(LLVMExecutionEngineRef EE);
void LLVMRunStaticDestructors(LLVMExecutionEngineRef EE);

int LLVMRunFunctionAsMain(LLVMExecutionEngineRef EE, LLVMValueRef F, uint ArgC, const(char*)* ArgV, const(char*)* EnvP);
LLVMGenericValueRef LLVMRunFunction(LLVMExecutionEngineRef EE, LLVMValueRef F, uint NumArgs, LLVMGenericValueRef *Args);

void LLVMFreeMachineCodeForFunction(LLVMExecutionEngineRef EE, LLVMValueRef F);

void LLVMAddModule(LLVMExecutionEngineRef EE, LLVMModuleRef M);
LLVMBool LLVMRemoveModule(LLVMExecutionEngineRef EE, LLVMModuleRef M, LLVMModuleRef *OutMod, const(char*)* OutError);

LLVMBool LLVMFindFunction(LLVMExecutionEngineRef EE, const(char)* Name, LLVMValueRef *OutFn);
void *LLVMRecompileAndRelinkFunction(LLVMExecutionEngineRef EE, LLVMValueRef Fn);
LLVMTargetDataRef LLVMGetExecutionEngineTargetData(LLVMExecutionEngineRef EE);
LLVMTargetMachineRef LLVMGetExecutionEngineTargetMachine(LLVMExecutionEngineRef EE);
void LLVMAddGlobalMapping(LLVMExecutionEngineRef EE, LLVMValueRef Global, void *Addr);
void* LLVMGetPointerToGlobal(LLVMExecutionEngineRef EE, LLVMValueRef Global);
uint64_t LLVMGetGlobalValueAddress (LLVMExecutionEngineRef EE, const(char)* Name);
uint64_t LLVMGetFunctionAddress(LLVMExecutionEngineRef EE, const(char)* Name);

LLVMMCJITMemoryManagerRef LLVMCreateSimpleMCJITMemoryManager(
	void *Opaque,
	LLVMMemoryManagerAllocateCodeSectionCallback AllocateCodeSection,
	LLVMMemoryManagerAllocateDataSectionCallback AllocateDataSection,
	LLVMMemoryManagerFinalizeMemoryCallback FinalizeMemory,
	LLVMMemoryManagerDestroyCallback Destroy
);

void LLVMDisposeMCJITMemoryManager(LLVMMCJITMemoryManagerRef MM);
