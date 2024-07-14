/*#D*/
// SPDX-FileCopyrightText: 2007-2026, LLVM Developers.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

module lib.llvm.c.Support;

public import lib.llvm.c.Types;


extern(C):

//#--- Auto generated below ---#
void LLVMAddSymbol(const(char)* symbolName, void* symbolValue);
LLVMBool LLVMLoadLibraryPermanently(const(char)* Filename);
void LLVMParseCommandLineOptions(int argc, const(const(char)*)* argv, const(char)* Overview);
void* LLVMSearchForAddressOfSymbol(const(char)* symbolName);
