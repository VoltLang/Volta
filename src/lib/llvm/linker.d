// Copyright © 2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license in src/lib/llvm/core.d.
module lib.llvm.Linker;

import lib.llvm.core;
public import lib.llvm.c.Linker;


/+
enum LLVMLinkerMode
{
  LLVMLinkerDestroySource = 0, /* Allow source module to be destroyed. */
  LLVMLinkerPreserveSource = 1 /* Preserve the source module. */
}


/* Links the source module into the destination module, taking ownership
 * of the source module away from the caller. Optionally returns a
 * human-readable description of any errors that occurred in linking.
 * OutMessage must be disposed with LLVMDisposeMessage. The return value
 * is true if an error occurred, false otherwise. */
LLVMBool LLVMLinkModules(LLVMModuleRef Dest, LLVMModuleRef Src,
                         LLVMLinkerMode Mode, char **OutMessage);
+/


alias LLVMLinkModules = lib.llvm.c.Linker.LLVMLinkModules;

bool LLVMLinkModules(LLVMModuleRef dst, LLVMModuleRef src,
                     LLVMLinkerMode mode, ref string outMsg)
{
	const(char)* msg;
	auto ret = cast(bool)lib.llvm.c.Linker.LLVMLinkModules(dst, src, mode, &msg);
	outMsg = handleAndDisposeMessage(&msg);
	return ret;
}
