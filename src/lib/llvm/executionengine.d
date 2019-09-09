/*#D*/
// Copyright 2012, Jakob Bornecrantz.
// SPDX-License-Identifier: NCSA OR (Apache-2.0 WITH LLVM-exception)
module lib.llvm.executionengine;

private import watt.conv : toStringz;
private import lib.llvm.core;
public import lib.llvm.c.ExecutionEngine;


alias LLVMCreateExecutionEngineForModule = lib.llvm.c.ExecutionEngine.LLVMCreateExecutionEngineForModule;
alias LLVMCreateMCJITCompilerForModule = lib.llvm.c.ExecutionEngine.LLVMCreateMCJITCompilerForModule;
alias LLVMRemoveModule = lib.llvm.c.ExecutionEngine.LLVMRemoveModule;
alias LLVMRunFunction = lib.llvm.c.ExecutionEngine.LLVMRunFunction;


LLVMBool LLVMCreateExecutionEngineForModule(LLVMExecutionEngineRef *outEE, LLVMModuleRef mod, out string error)
{
	const(char)* str = null;
	auto ret = LLVMCreateExecutionEngineForModule(outEE, mod, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}


LLVMBool LLVMCreateMCJITCompilerForModule(LLVMExecutionEngineRef *outJIT, LLVMModuleRef mod, LLVMMCJITCompilerOptions options, out string error)
{
	const(char)* str = null;
	version (Volt) {
		auto optsz = typeid(options).size;
	} else {
		auto optsz = options.sizeof;
	}
	auto ret = LLVMCreateMCJITCompilerForModule(outJIT, mod, &options, optsz, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}

LLVMBool LLVMCreateMCJITCompilerForModule(LLVMExecutionEngineRef *outJIT, LLVMModuleRef mod, LLVMMCJITCompilerOptions* options, size_t optionsSize, out string error)
{
	const(char)* str = null;
	auto ret = LLVMCreateMCJITCompilerForModule(outJIT, mod, options, optionsSize, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}

LLVMBool LLVMRemoveModule(LLVMExecutionEngineRef ee, LLVMModuleRef mod, LLVMModuleRef* outMod, out string error)
{
	const(char)* str = null;
	auto ret = LLVMRemoveModule(ee, mod, outMod, &str);
	error = handleAndDisposeMessage(&str);

	return ret;
}

LLVMGenericValueRef LLVMRunFunction(LLVMExecutionEngineRef ee, string name, LLVMGenericValueRef[] args)
{
	LLVMValueRef func = null;
	auto retFF = LLVMFindFunction(ee, toStringz(name), &func);
	if (func is null || retFF != 0) {
		return null;
	}

	return LLVMRunFunction(ee, func, cast(uint)args.length, args.ptr);
}
