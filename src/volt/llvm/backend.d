// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.backend;

import io = watt.io.std;

import volt.errors;
import volt.interfaces;
import ir = volt.ir.ir;
import volt.ir.util;
import volt.token.location;

import lib.llvm.core;
import lib.llvm.analysis;
import lib.llvm.bitreader;
import lib.llvm.bitwriter;
import lib.llvm.targetmachine;
import lib.llvm.executionengine;
import lib.llvm.c.Target;
import lib.llvm.c.Linker;
import lib.llvm.c.Initialization;

import volt.llvm.host;
import volt.llvm.state;
import volt.llvm.toplevel;


/**
 * Main interface for the @link volt.interfaces.Driver
 * Driver@endlink to the llvm backend.
 */
class LlvmBackend : Backend
{
protected:
	LanguagePass lp;

	TargetType mTargetType;
	bool mDump;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
		this.mDump = lp.driver.internalDebug;

		auto passRegistry = LLVMGetGlobalPassRegistry();

		LLVMInitializeCore(passRegistry);
		LLVMInitializeAnalysis(passRegistry);
		LLVMInitializeTarget(passRegistry);

		if (lp.target.arch == Arch.X86 ||
		    lp.target.arch == Arch.X86_64) {
			LLVMInitializeX86TargetInfo();
			LLVMInitializeX86Target();
			LLVMInitializeX86TargetMC();
			LLVMInitializeX86AsmPrinter();
		}

		LLVMLinkInMCJIT();
	}

	override void close()
	{
		// XXX: Shutdown LLVM.
	}

	override TargetType[] supported()
	{
		return [TargetType.LlvmBitcode, TargetType.Host];
	}

	override void setTarget(TargetType type)
	{
		mTargetType = type;
	}

	override BackendResult compile(ir.Module m)
	{
		auto state = new VoltState(lp, m);
		auto mod = state.mod;
		scope (failure) {
			state.close();
		}

		if (mDump) {
			io.output.writefln("Compiling module");
		}

		llvmModuleCompile(state, m);

		if (mDump) {
			io.output.writefln("Dumping module");
			LLVMDumpModule(mod);
		}

		string result;
		auto failed = LLVMVerifyModule(mod, result);
		if (failed) {
			LLVMDumpModule(mod);
			io.error.writefln("%s", result);
			throw panic("Module verification failed.");
		}

		if (mTargetType == TargetType.LlvmBitcode) {
			return new BitcodeResult(state);
		} else if (mTargetType == TargetType.Host) {
			return new HostResult(state);
		} else {
			assert(false);
		}
	}

protected:
	void llvmModuleCompile(VoltState state, ir.Module m)
	{
		scope (failure) {
			if (mDump) {
				version (Volt) {
					io.output.writefln("Failure, dumping module:");
				} else {
					io.output.writefln("Failure, dumping module:");
				}
				LLVMDumpModule(state.mod);
			}
		}
		state.compile(m);
	}
}

class BitcodeResult : BackendResult
{
protected:
	VoltState mState;


public:
	this(VoltState state)
	{
		this.mState = state;
	}

	override void saveToFile(string filename)
	{
		auto t = mState.lp.target;
		auto triple = tripleList[t.platform][t.arch];
		auto layout = layoutList[t.platform][t.arch];
		LLVMSetTarget(mState.mod, triple);
		LLVMSetDataLayout(mState.mod, layout);
		LLVMWriteBitcodeToFile(mState.mod, filename);
	}

	override BackendResult.CompiledDg getFunction(ir.Function)
	{
		assert(false);
	}

	override void close()
	{
		mState.close();
	}
}

LLVMModuleRef loadModule(LLVMContextRef ctx, string filename)
{
	string msg;

	auto mod = LLVMModuleFromFileInContext(ctx, filename, msg);
	if (msg !is null && mod !is null) {
		io.error.writefln("%s", msg); // Warnings
	}
	if (mod is null) {
		throw makeNoLoadBitcodeFile(filename, msg);
	}

	return mod;
}

/**
 * Helper function to link several LLVM modules together.
 */
void linkModules(string output, string[] inputs...)
{
	assert(inputs.length > 0);

	LLVMModuleRef dst, src;
	LLVMContextRef ctx;
	string msg;

	if (inputs.length == 1 &&
	    output == inputs[0]) {
		return;
	}

	ctx = LLVMContextCreate();
	scope (exit) {
		LLVMContextDispose(ctx);
	}

	dst = loadModule(ctx, inputs[0]);
	scope (exit) {
		LLVMDisposeModule(dst);
	}

	foreach (filename; inputs[1 .. $]) {
		src = loadModule(ctx, filename);

		auto ret = LLVMLinkModules2(dst, src);
		if (ret) {
			throw makeNoLinkModule(filename, msg);
		}
	}

	auto ret = LLVMWriteBitcodeToFile(dst, output);
	if (ret) {
		throw makeNoWriteBitcodeFile(output, msg);
	}
}

void writeObjectFile(TargetInfo target, string output, string input)
{
	auto arch = archList[target.arch];
	auto triple = tripleList[target.platform][target.arch];
	auto layout = layoutList[target.platform][target.arch];
	if (arch is null || triple is null || layout is null) {
		throw makeArchNotSupported();
	}

	// Need a context to load the module into.
	auto ctx = LLVMContextCreate();
	scope (exit) {
		LLVMContextDispose(ctx);
	}


	// Load the module from file.
	auto mod = loadModule(ctx, input);
	scope (exit) {
		LLVMDisposeModule(mod);
	}


	// Load the target mc/assmbler.
	// Doesn't need to disposed.
	LLVMTargetRef llvmTarget = LLVMGetTargetFromName(arch);

	auto opt = LLVMCodeGenOptLevel.Default;
	auto codeModel = LLVMCodeModel.Default;
	auto reloc = LLVMRelocMode.Default;

	// Force -fPIC on linux.
	if (target.arch == Arch.X86_64 &&
	    target.platform == Platform.Linux) {
		reloc = LLVMRelocMode.PIC;
	}

	// Create target machine used to hold all of the settings.
	auto machine = LLVMCreateTargetMachine(
		llvmTarget, triple, "", "", opt, reloc, codeModel);
	scope (exit) {
		LLVMDisposeTargetMachine(machine);
	}


	// Write the module to the file
	string msg;
	auto ret = LLVMTargetMachineEmitToFile(
		machine, mod, output,
		LLVMCodeGenFileType.Object, msg) != 0;

	if (msg !is null && !ret) {
		io.error.writefln("%s", msg); // Warnings
	}
	if (ret) {
		throw makeNoWriteObjectFile(output, msg);
	}
}
