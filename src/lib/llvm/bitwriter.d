/*#D*/
// Copyright 2012, Jakob Bornecrantz.
// SPDX-License-Identifier: NCSA OR (Apache-2.0 WITH LLVM-exception)
module lib.llvm.bitwriter;

import lib.llvm.core;
public import lib.llvm.c.BitWriter;


bool LLVMWriteBitcodeToFile(LLVMModuleRef mod, string filename)
{
	char[1024] stack;
	auto ptr = nullTerminate(stack, filename);
	return lib.llvm.c.BitWriter.LLVMWriteBitcodeToFile(mod, ptr) != 0;
}
