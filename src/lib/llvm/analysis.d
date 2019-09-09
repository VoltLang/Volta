/*#D*/
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: NCSA OR (Apache-2.0 WITH LLVM-Exception)
module lib.llvm.analysis;

import lib.llvm.core;
public import lib.llvm.c.Analysis;


// Need to do this for all overloaded functions.
alias LLVMVerifyModule = lib.llvm.c.Analysis.LLVMVerifyModule;

bool LLVMVerifyModule(LLVMModuleRef mod)
{
	return cast(bool).lib.llvm.c.Analysis.LLVMVerifyModule(
		mod, LLVMVerifierFailureAction.ReturnStatus, null);
}

bool LLVMVerifyModule(LLVMModuleRef mod, out string ret)
{
	const(char)* str;
	auto b =  cast(bool).lib.llvm.c.Analysis.LLVMVerifyModule(
		mod, LLVMVerifierFailureAction.ReturnStatus, &str);

	ret = handleAndDisposeMessage(&str);
	return b;
}
