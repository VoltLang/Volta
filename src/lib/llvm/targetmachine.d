// Copyright © 2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice and license in src/lib/llvm/core.d.
module lib.llvm.targetmachine;


import std.conv : to;

import lib.llvm.core;
public import lib.llvm.c.TargetMachine;


alias LLVMGetTargetFromName = lib.llvm.c.TargetMachine.LLVMGetTargetFromName;
alias LLVMGetTargetFromTriple = lib.llvm.c.TargetMachine.LLVMGetTargetFromTriple;
alias LLVMCreateTargetMachine = lib.llvm.c.TargetMachine.LLVMCreateTargetMachine;
alias LLVMTargetMachineEmitToFile = lib.llvm.c.TargetMachine.LLVMTargetMachineEmitToFile;
alias LLVMTargetMachineEmitToMemoryBuffer = lib.llvm.c.TargetMachine.LLVMTargetMachineEmitToMemoryBuffer;


LLVMTargetRef LLVMGetTargetFromName(string name)
{
	char[64] stack;
	return lib.llvm.c.TargetMachine.LLVMGetTargetFromName(
		nullTerminate(stack, name));
}

bool LLVMGetTargetFromTriple(string triple, LLVMTargetRef* outTarget,
                                 ref string errorMessage)
{
	char[64] stack;
	const(char)* msg;

	auto ret = lib.llvm.c.TargetMachine.LLVMGetTargetFromTriple(
		nullTerminate(stack, triple), outTarget, &msg) != 0;

	errorMessage = handleAndDisposeMessage(&msg);
	return ret;
}

string LLVMGetTargetName(LLVMTargetRef target)
{
	return to!string(lib.llvm.c.TargetMachine.LLVMGetTargetName(target));
}

string LLVMGetTargetDescription(LLVMTargetRef target)
{
	return to!string(lib.llvm.c.TargetMachine.LLVMGetTargetDescription(target));
}

string LLVMGetTargetMachineTriple(LLVMTargetMachineRef machine)
{
	auto msg = lib.llvm.c.TargetMachine.LLVMGetTargetMachineTriple(machine);
	return handleAndDisposeMessage(&msg);
}

string LLVMGetTargetMachineCPU(LLVMTargetMachineRef machine)
{
	auto msg = lib.llvm.c.TargetMachine.LLVMGetTargetMachineCPU(machine);
	return handleAndDisposeMessage(&msg);
}

string LLVMGetTargetMachineFeatureString(LLVMTargetMachineRef machine)
{
	auto msg =
		lib.llvm.c.TargetMachine.LLVMGetTargetMachineFeatureString(machine);
	return handleAndDisposeMessage(&msg);
}

LLVMTargetMachineRef LLVMCreateTargetMachine(LLVMTargetRef target,
                                             string triple,
                                             string cpu,
                                             string feature,
                                             LLVMCodeGenOptLevel level,
                                             LLVMRelocMode reloc,
                                             LLVMCodeModel codeModel)
{
	char[64] tripleStack;
	char[64] cpuStack;
	char[256] featureStack;

	return lib.llvm.c.TargetMachine.LLVMCreateTargetMachine(
		target,
		nullTerminate(tripleStack, triple),
		nullTerminate(cpuStack, cpu),
		nullTerminate(featureStack, feature),
		level, reloc, codeModel);
}

bool LLVMTargetMachineEmitToFile(LLVMTargetMachineRef machine,
                                 LLVMModuleRef mod,
                                 string filename,
                                 LLVMCodeGenFileType codegen,
                                 ref string errorMessage)
{
	char[1024] stack;
	const(char)* msg;

	auto ret = lib.llvm.c.TargetMachine.LLVMTargetMachineEmitToFile(
		machine, mod, nullTerminate(stack, filename), codegen, &msg) != 0;

	errorMessage = handleAndDisposeMessage(&msg);
	return ret;
}

bool LLVMTargetMachineEmitToMemoryBuffer(LLVMTargetMachineRef machine,
                                         LLVMModuleRef mod,
                                         LLVMCodeGenFileType codegen,
                                         ref string errorMessage,
                                         LLVMMemoryBufferRef* outMemBuf)
{
	const(char)* msg;

	auto ret = lib.llvm.c.TargetMachine.LLVMTargetMachineEmitToMemoryBuffer(
		machine, mod, codegen, &msg, outMemBuf) != 0;

	errorMessage = handleAndDisposeMessage(&msg);
	return ret;
}
