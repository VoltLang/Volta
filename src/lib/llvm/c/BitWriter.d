/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.BitWriter;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
int LLVMWriteBitcodeToFD(LLVMModuleRef M, int FD, int ShouldClose, int Unbuffered);
int LLVMWriteBitcodeToFile(LLVMModuleRef M, const(char)* Path);
int LLVMWriteBitcodeToFileHandle(LLVMModuleRef M, int Handle);
LLVMMemoryBufferRef LLVMWriteBitcodeToMemoryBuffer(LLVMModuleRef M);
