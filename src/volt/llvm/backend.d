// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.backend;

import io = watt.io.std;

import volt.errors;
import volt.interfaces;

import lib.llvm.core;
import lib.llvm.linker;
import lib.llvm.analysis;
import lib.llvm.bitreader;
import lib.llvm.bitwriter;
import lib.llvm.targetmachine;
import lib.llvm.c.Target;
import lib.llvm.c.Initialization;

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
	string mFilename;
	bool mDump;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
		this.mDump = lp.settings.internalDebug;

		auto passRegistry = LLVMGetGlobalPassRegistry();

		LLVMInitializeCore(passRegistry);
		LLVMInitializeAnalysis(passRegistry);
		LLVMInitializeTarget(passRegistry);

		if (lp.settings.arch == Arch.X86 ||
		    lp.settings.arch == Arch.X86_64) {
			LLVMInitializeX86TargetInfo();
			LLVMInitializeX86Target();
			LLVMInitializeX86TargetMC();
			LLVMInitializeX86AsmPrinter();
		}
	}

	void close()
	{
		mFilename = null;
		// XXX: Shutdown LLVM.
	}

	TargetType[] supported()
	{
		return [TargetType.LlvmBitcode];
	}

	void setTarget(string filename, TargetType type)
	{
		mFilename = filename;
		mTargetType = type;
	}

	void compile(ir.Module m)
	in {
		assert(mFilename !is null);
	}
	body {
		scope(exit)
			mFilename = null;

		auto state = new VoltState(lp, m);
		auto mod = state.mod;
		scope(exit) {
			state.close();
			mFilename = null;
		}

		if (mDump)
			io.output.writefln("Compiling module");

		try {
			state.compile(m);
		} catch (Throwable t) {
			if (mDump) {
				io.output.writefln("Caught \"%s\" dumping module:", t.classinfo.name);
				LLVMDumpModule(mod);
			}
			throw t;
		}

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

		LLVMWriteBitcodeToFile(mod, mFilename);
	}
}

LLVMModuleRef loadModule(LLVMContextRef ctx, string filename)
{
	string msg;

	auto mod = LLVMModuleFromFileInContext(ctx, filename, msg);
	if (msg !is null && mod !is null)
		io.error.writefln("%s", msg); // Warnings
	if (mod is null)
		throw makeNoLoadBitcodeFile(filename, msg);

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
	    output == inputs[0])
		return;

	ctx = LLVMContextCreate();
	scope(exit)
		LLVMContextDispose(ctx);

	dst = loadModule(ctx, inputs[0]);
	scope(exit)
		LLVMDisposeModule(dst);

	foreach(filename; inputs[1 .. $]) {
		src = loadModule(ctx, filename);

		bool ret = LLVMLinkModules(dst, src, LLVMLinkerMode.DestroySource, msg);
		if (msg !is null)
			io.error.writefln("%s", msg);
		if (ret)
			throw makeNoLinkModule(filename, msg);
	}

	auto ret = LLVMWriteBitcodeToFile(dst, output);
	if (ret)
		throw makeNoWriteBitcodeFile(output, msg);
}

void writeObjectFile(Settings settings, string output, string input)
{
	auto arch = archList[settings.arch];
	auto triple = tripleList[settings.platform][settings.arch];
	auto layout = layoutList[settings.platform][settings.arch];
	if (arch is null || triple is null || layout is null)
		throw makeArchNotSupported();

	// Need a context to load the module into.
	auto ctx = LLVMContextCreate();
	scope(exit)
		LLVMContextDispose(ctx);


	// Load the module from file.
	auto mod = loadModule(ctx, input);
	scope(exit)
		LLVMDisposeModule(mod);


	// Load the target mc/assmbler.
	// Doesn't need to disposed.
	LLVMTargetRef target = LLVMGetTargetFromName(arch);


	// Create target machine used to hold all of the settings.
	auto machine = LLVMCreateTargetMachine(
		target, triple, "", "",
		LLVMCodeGenOptLevel.Default,
		LLVMRelocMode.Default,
		LLVMCodeModel.Default);
	scope(exit)
		LLVMDisposeTargetMachine(machine);


	// Write the module to the file
	string msg;
	auto ret = LLVMTargetMachineEmitToFile(
		machine, mod, output,
		LLVMCodeGenFileType.Object, msg) != 0;

	if (msg !is null && !ret)
		io.error.writefln("%s", msg); // Warnings
	if (ret)
		throw makeNoWriteObjectFile(output, msg);
}
