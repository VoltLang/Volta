/*#D*/
/*===-- llvm-c/Support.h - Support C Interface --------------------*- D -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See src/lib/llvm/core.d for details.                              *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This file defines the C interface to the LLVM support library.             *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/
module lib.llvm.c.Support;

import lib.llvm.c.Core;


extern (C):

LLVMBool LLVMLoadLibraryPermanently(const(char)* Filename);
void LLVMParseCommandLineOptions(int argc, const(char*)* argv, const(char)* Overview);
void* LLVMSearchForAddressOfSymbol(const(char)* symbolName);
void LLVMAddSymbol(const(char)* symbolName, void* symbolValue);
