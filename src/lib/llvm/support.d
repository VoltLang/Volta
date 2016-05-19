module lib.llvm.support;


private import watt.conv : toStringz;
public import lib.llvm.c.Support;


alias LLVMSearchForAddressOfSymbol = lib.llvm.c.Support.LLVMSearchForAddressOfSymbol;
alias LLVMAddSymbol = lib.llvm.c.Support.LLVMAddSymbol;


void* LLVMSearchForAddressOfSymbol(const(char)[] symbolName)
{
	return LLVMSearchForAddressOfSymbol(toStringz(symbolName));
}

void LLVMAddSymbol(const(char)[] symbolName, void* symbolValue)
{
	LLVMAddSymbol(toStringz(symbolName), symbolValue);
}
