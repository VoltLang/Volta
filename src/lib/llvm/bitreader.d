// Copyright © 2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license in src/lib/llvm/core.d.
module lib.llvm.bitreader;

import lib.llvm.core;
public import lib.llvm.c.BitReader;


LLVMModuleRef LLVMModuleFromFileInContext(LLVMContextRef ctx, string filename, ref string outMsg)
{
	LLVMMemoryBufferRef mem;
	LLVMModuleRef mod;
	const(char)* msg;
	char[1024] stack;

	auto ptr = nullTerminate(stack, filename);
	auto ret = LLVMCreateMemoryBufferWithContentsOfFile(ptr, &mem, &msg);
	outMsg = handleAndDisposeMessage(&msg);
	if (ret)
		return null;

	ret = LLVMParseBitcodeInContext(ctx, mem, &mod, &msg);
	outMsg = handleAndDisposeMessage(&msg);

	LLVMDisposeMemoryBuffer(mem);
	mem = null;
	if (ret && mod !is null) {
		LLVMDisposeModule(mod);
		mod = null;
	}
	return mod;
}
