/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Types;


alias LLVMBool = uint;
version (LLVMVersion18AndAbove) {
	alias LLVMFastMathFlags = uint;
}
version (LLVMVersion19AndAbove) {
	alias LLVMGEPNoWrapFlags = uint;
}


struct LLVMAttribute {}
struct LLVMBasicBlock {}
struct LLVMBinary {}
struct LLVMBuilder {}
struct LLVMComdat {}
struct LLVMContext {}
struct LLVMDiagnosticInfo {}
struct LLVMDIBuilder {}
struct LLVMJITEventListener {}
struct LLVMMemoryBuffer {}
struct LLVMMetadata {}
struct LLVMModule {}
struct LLVMModuleFlagEntry {} // Not turned into Ref
struct LLVMModuleProvider {}
struct LLVMNamedMDNode {}
struct LLVMPassManager {}
struct LLVMPassRegistry {}
struct LLVMType {}
struct LLVMUse {}
struct LLVMValue {}
struct LLVMValueMetadataEntry {} // Not turned into Ref
version(LLVMVersion18AndAbove) {
	struct LLVMOperandBundle {}
}
version(LLVMVersion19AndAbove) {
	struct LLVMDbgRecord {}
}

alias LLVMAttributeRef = LLVMAttribute*;
alias LLVMBasicBlockRef = LLVMBasicBlock*;
alias LLVMBinaryRef = LLVMBinary*;
alias LLVMBuilderRef = LLVMBuilder*;
alias LLVMComdatRef = LLVMComdat*;
alias LLVMContextRef = LLVMContext*;
alias LLVMDiagnosticInfoRef = LLVMDiagnosticInfo*;
alias LLVMDIBuilderRef = LLVMDIBuilder*;
alias LLVMJITEventListenerRef = LLVMJITEventListener*;
alias LLVMMemoryBufferRef = LLVMMemoryBuffer*;
alias LLVMMetadataRef = LLVMMetadata*;
alias LLVMModuleProviderRef = LLVMModuleProvider*;
alias LLVMModuleRef = LLVMModule*;
alias LLVMNamedMDNodeRef = LLVMNamedMDNode*;
alias LLVMPassManagerRef = LLVMPassManager*;
alias LLVMPassRegistryRef = LLVMPassRegistry*;
alias LLVMTypeRef = LLVMType*;
alias LLVMUseRef = LLVMUse*;
alias LLVMValueRef = LLVMValue*;
version(LLVMVersion18AndAbove) {
	alias LLVMOperandBundleRef = LLVMOperandBundle*;
}
version(LLVMVersion19AndAbove) {
	alias LLVMDbgRecordRef = LLVMDbgRecord*;
}


extern(C):

//#--- Auto generated below ---#
