// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license in src/lib/llvm/core.d.
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
