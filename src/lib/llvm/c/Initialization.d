/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Initialization;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
version(LLVMVersion16AndAbove) {
	// Removed
} else {
	void LLVMInitializeAggressiveInstCombiner(LLVMPassRegistryRef R);
	void LLVMInitializeInstrumentation(LLVMPassRegistryRef R);
	void LLVMInitializeObjCARCOpts(LLVMPassRegistryRef R);
}
version(LLVMVersion17AndAbove) {
	// Removed
} else {
	void LLVMInitializeAnalysis(LLVMPassRegistryRef R);
	void LLVMInitializeCodeGen(LLVMPassRegistryRef R);
	void LLVMInitializeCore(LLVMPassRegistryRef R);
	void LLVMInitializeIPA(LLVMPassRegistryRef R);
	void LLVMInitializeIPO(LLVMPassRegistryRef R);
	void LLVMInitializeInstCombine(LLVMPassRegistryRef R);
	void LLVMInitializeScalarOpts(LLVMPassRegistryRef R);
	void LLVMInitializeTarget(LLVMPassRegistryRef R);
	void LLVMInitializeTransformUtils(LLVMPassRegistryRef R);
	void LLVMInitializeVectorization(LLVMPassRegistryRef R);
}
