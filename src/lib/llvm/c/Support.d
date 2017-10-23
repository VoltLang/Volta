/*#D*/
module lib.llvm.c.Support;


import lib.llvm.c.Core;


extern (C):

LLVMBool LLVMLoadLibraryPermanently(const(char)* Filename);
void LLVMParseCommandLineOptions(int argc, const(char*)* argv, const(char)* Overview);
void* LLVMSearchForAddressOfSymbol(const(char)* symbolName);
void LLVMAddSymbol(const(char)* symbolName, void* symbolValue);
