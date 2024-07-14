/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.ExecutionEngine;

public import lib.llvm.c.Types;
import lib.llvm.c.Target;
import lib.llvm.c.TargetMachine;


private alias uintptr_t = size_t;
private alias uint8_t = ubyte;


struct LLVMGenericValue {} alias LLVMGenericValueRef = LLVMGenericValue*;
struct LLVMExecutionEngine {} alias LLVMExecutionEngineRef = LLVMExecutionEngine*;
struct LLVMMCJITMemoryManager {} alias LLVMMCJITMemoryManagerRef = LLVMMCJITMemoryManager*;


struct LLVMMCJITCompilerOptions {
	uint OptLevel;
	LLVMCodeModel CodeModel;
	bool NoFramePointerElim;
	bool EnableFastISel;
	LLVMMCJITMemoryManagerRef MCJMM;
}

alias LLVMMemoryManagerAllocateCodeSectionCallback = uint8_t function(void *Opaque, uintptr_t Size, uint Alignment, uint SectionID, const(char)* SectionName);
alias LLVMMemoryManagerAllocateDataSectionCallback = uint8_t function(void *Opaque, uintptr_t Size, uint Alignment, uint SectionID, const(char)* SectionName, LLVMBool IsReadOnly);
alias LLVMMemoryManagerFinalizeMemoryCallback = LLVMBool function(void *Opaque, char **ErrMsg);
alias LLVMMemoryManagerDestroyCallback = void function(void *Opaque);


extern(C):

//#--- Auto generated below ---#
void LLVMAddGlobalMapping(LLVMExecutionEngineRef EE, LLVMValueRef Global, void* Addr);
void LLVMAddModule(LLVMExecutionEngineRef EE, LLVMModuleRef M);
LLVMBool LLVMCreateExecutionEngineForModule(LLVMExecutionEngineRef* OutEE, LLVMModuleRef M, char** OutError);
LLVMJITEventListenerRef LLVMCreateGDBRegistrationListener();
LLVMGenericValueRef LLVMCreateGenericValueOfFloat(LLVMTypeRef Ty, double N);
LLVMGenericValueRef LLVMCreateGenericValueOfInt(LLVMTypeRef Ty, ulong N, LLVMBool IsSigned);
LLVMGenericValueRef LLVMCreateGenericValueOfPointer(void* P);
LLVMJITEventListenerRef LLVMCreateIntelJITEventListener();
LLVMBool LLVMCreateInterpreterForModule(LLVMExecutionEngineRef* OutInterp, LLVMModuleRef M, char** OutError);
LLVMBool LLVMCreateJITCompilerForModule(LLVMExecutionEngineRef* OutJIT, LLVMModuleRef M, uint OptLevel, char** OutError);
LLVMBool LLVMCreateMCJITCompilerForModule(LLVMExecutionEngineRef* OutJIT, LLVMModuleRef M, LLVMMCJITCompilerOptions* Options, size_t SizeOfOptions, char** OutError);
LLVMJITEventListenerRef LLVMCreateOProfileJITEventListener();
LLVMJITEventListenerRef LLVMCreatePerfJITEventListener();
LLVMMCJITMemoryManagerRef LLVMCreateSimpleMCJITMemoryManager(void* Opaque, LLVMMemoryManagerAllocateCodeSectionCallback AllocateCodeSection, LLVMMemoryManagerAllocateDataSectionCallback AllocateDataSection, LLVMMemoryManagerFinalizeMemoryCallback FinalizeMemory, LLVMMemoryManagerDestroyCallback Destroy);
void LLVMDisposeExecutionEngine(LLVMExecutionEngineRef EE);
void LLVMDisposeGenericValue(LLVMGenericValueRef GenVal);
void LLVMDisposeMCJITMemoryManager(LLVMMCJITMemoryManagerRef MM);
LLVMBool LLVMFindFunction(LLVMExecutionEngineRef EE, const(char)* Name, LLVMValueRef* OutFn);
void LLVMFreeMachineCodeForFunction(LLVMExecutionEngineRef EE, LLVMValueRef F);
uint LLVMGenericValueIntWidth(LLVMGenericValueRef GenValRef);
double LLVMGenericValueToFloat(LLVMTypeRef TyRef, LLVMGenericValueRef GenVal);
ulong LLVMGenericValueToInt(LLVMGenericValueRef GenVal, LLVMBool IsSigned);
void* LLVMGenericValueToPointer(LLVMGenericValueRef GenVal);
LLVMTargetDataRef LLVMGetExecutionEngineTargetData(LLVMExecutionEngineRef EE);
LLVMTargetMachineRef LLVMGetExecutionEngineTargetMachine(LLVMExecutionEngineRef EE);
ulong LLVMGetFunctionAddress(LLVMExecutionEngineRef EE, const(char)* Name);
ulong LLVMGetGlobalValueAddress(LLVMExecutionEngineRef EE, const(char)* Name);
void* LLVMGetPointerToGlobal(LLVMExecutionEngineRef EE, LLVMValueRef Global);
void LLVMInitializeMCJITCompilerOptions(LLVMMCJITCompilerOptions* Options, size_t SizeOfOptions);
void LLVMLinkInInterpreter();
void LLVMLinkInMCJIT();
void* LLVMRecompileAndRelinkFunction(LLVMExecutionEngineRef EE, LLVMValueRef Fn);
LLVMBool LLVMRemoveModule(LLVMExecutionEngineRef EE, LLVMModuleRef M, LLVMModuleRef* OutMod, char** OutError);
LLVMGenericValueRef LLVMRunFunction(LLVMExecutionEngineRef EE, LLVMValueRef F, uint NumArgs, LLVMGenericValueRef* Args);
int LLVMRunFunctionAsMain(LLVMExecutionEngineRef EE, LLVMValueRef F, uint ArgC, const(const(char)*)* ArgV, const(const(char)*)* EnvP);
void LLVMRunStaticConstructors(LLVMExecutionEngineRef EE);
void LLVMRunStaticDestructors(LLVMExecutionEngineRef EE);
version(LLVMVersion11AndAbove) {
	LLVMBool LLVMExecutionEngineGetErrMsg(LLVMExecutionEngineRef EE, char** OutError);
}
