// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license in src/lib/llvm/core.d.
module lib.llvm.analysis;

import std.conv : to;
import lib.llvm.core;
public import lib.llvm.c.Analysis;


// Need to do this for all overloaded functions.
alias lib.llvm.c.Analysis.LLVMVerifyModule LLVMVerifyModule;

bool LLVMVerifyModule(LLVMModuleRef mod)
{
	return cast(bool)LLVMVerifyModule(
		mod, LLVMVerifierFailureAction.ReturnStatus, null);
}

bool LLVMVerifyModule(LLVMModuleRef mod, out string ret)
{
	char *str;
	auto b =  cast(bool)LLVMVerifyModule(
		mod, LLVMVerifierFailureAction.ReturnStatus, &str);

	ret = to!string(str);
	LLVMDisposeMessage(str);
	str = null;

	return b;
}
