// Copyright © 2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license in src/lib/llvm/core.d.
module lib.llvm.linker;

import lib.llvm.core;
public import lib.llvm.c.Linker;


/+
alias LLVMLinkModules = lib.llvm.c.Linker.LLVMLinkModules;
+/

bool LLVMLinkModules(LLVMModuleRef dst, LLVMModuleRef src,
                     LLVMLinkerMode mode, ref string outMsg)
{
	const(char)* msg;
	auto ret = cast(bool)lib.llvm.c.Linker.LLVMLinkModules(dst, src, mode, &msg);
	outMsg = handleAndDisposeMessage(&msg);
	return ret;
}
