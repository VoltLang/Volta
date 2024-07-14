/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Analysis;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
enum LLVMVerifierFailureAction {
	AbortProcess = 0,
	PrintMessage = 1,
	ReturnStatus = 2,
}
LLVMBool LLVMVerifyFunction(LLVMValueRef Fn, LLVMVerifierFailureAction Action);
LLVMBool LLVMVerifyModule(LLVMModuleRef M, LLVMVerifierFailureAction Action, char** OutMessage);
void LLVMViewFunctionCFG(LLVMValueRef Fn);
void LLVMViewFunctionCFGOnly(LLVMValueRef Fn);
