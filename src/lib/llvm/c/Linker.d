/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Linker;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
enum LLVMLinkerMode {
	DestroySource = 0,
	PreserveSource_Removed = 1,
}
LLVMBool LLVMLinkModules2(LLVMModuleRef Dest, LLVMModuleRef Src);
