/*===-- llvm-c/Linker.h - Module Linker C Interface ---------------*- D -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See src/lib/llvm/core.d for details.                              *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This file defines the C interface to the module/file/archive linker.       *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* Up-to-date as of LLVM 3.4                                                  *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
module lib.llvm.c.Linker;

import lib.llvm.c.Core;


extern(C):

enum LLVMLinkerMode
{
  DestroySource = 0, /* Allow source module to be destroyed. */
  PreserveSource = 1 /* Preserve the source module. */
}


/* Links the source module into the destination module, taking ownership
 * of the source module away from the caller. Optionally returns a
 * human-readable description of any errors that occurred in linking.
 * OutMessage must be disposed with LLVMDisposeMessage. The return value
 * is true if an error occurred, false otherwise. */
LLVMBool LLVMLinkModules(LLVMModuleRef Dest, LLVMModuleRef Src,
                         LLVMLinkerMode Mode, const(char)** OutMessage);
