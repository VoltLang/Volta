/*#D*/
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
|* Up-to-date as of LLVM 3.8                                                  *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
module lib.llvm.c.Linker;

import lib.llvm.c.Core;


extern(C):

/* This enum is provided for backwards-compatibility only. It has no effect. */
enum LLVMLinkerMode
{
  DestroySource = 0, /* This is the default behavior. */
  PreserveSource = 1 /* This option has been deprecated and
                        should not be used. */
}

/* Links the source module into the destination module. The source module is
 * damaged. The only thing that can be done is destroy it. Optionally returns a
 * human-readable description of any errors that occurred in linking. OutMessage
 * must be disposed with LLVMDisposeMessage. The return value is true if an
 * error occurred, false otherwise.
 *
 * Note that the linker mode parameter \p Unused is no longer used, and has
 * no effect.
 *
 * This function is deprecated. Use LLVMLinkModules2 instead.
 */
LLVMBool LLVMLinkModules(LLVMModuleRef Dest, LLVMModuleRef Src,
                         LLVMLinkerMode Unused, const(char)** OutMessage);

/* Links the source module into the destination module. The source module is
 * destroyed.
 * The return value is true if an error occurred, false otherwise.
 * Use the diagnostic handler to get any diagnostic message.
*/
LLVMBool LLVMLinkModules2(LLVMModuleRef Dest, LLVMModuleRef Src);
