/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.BitReader;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
LLVMBool LLVMGetBitcodeModule(LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutM, char** OutMessage);
LLVMBool LLVMGetBitcodeModule2(LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutM);
LLVMBool LLVMGetBitcodeModuleInContext(LLVMContextRef ContextRef, LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutM, char** OutMessage);
LLVMBool LLVMGetBitcodeModuleInContext2(LLVMContextRef ContextRef, LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutM);
LLVMBool LLVMParseBitcode(LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutModule, char** OutMessage);
LLVMBool LLVMParseBitcode2(LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutModule);
LLVMBool LLVMParseBitcodeInContext(LLVMContextRef ContextRef, LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutModule, char** OutMessage);
LLVMBool LLVMParseBitcodeInContext2(LLVMContextRef ContextRef, LLVMMemoryBufferRef MemBuf, LLVMModuleRef* OutModule);
