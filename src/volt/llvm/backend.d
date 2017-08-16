// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Main module for the @ref llvmbackend.
 *
 * @ingroup backend llvmbackend
 */
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

/*!
 * @defgroup llvmbackend LLVM Backend
 * @brief LLVM based backend.
 *
 * Generate object code using LLVM.
 *
 * The LLVM backend is the original and default backend for
 * Volt, and as such is the most fully featured.
 *
 * @see http://llvm.org
 * @ingroup backend
 */

/*!
 * Main interface for the @link volt.interfaces.Driver
 * Driver@endlink to the llvm backend.
 *
 * @ingroup backend llvmbackend
 */
class LlvmBackend : Backend
{
protected:
	TargetInfo target;
	LLVMTargetRef llvmTarget;
	LLVMTargetMachineRef llvmMachineTarget;

	TargetType mTargetType;
	bool mDump;


public:
	this(TargetInfo target, bool internalDebug)
	{
		this.target = target;
		this.mDump = internalDebug;

		auto passRegistry = LLVMGetGlobalPassRegistry();

		LLVMInitializeCore(passRegistry);
		LLVMInitializeAnalysis(passRegistry);
		LLVMInitializeTarget(passRegistry);

		if (target.arch == Arch.X86 ||
		    target.arch == Arch.X86_64) {
			LLVMInitializeX86TargetInfo();
			LLVMInitializeX86Target();
			LLVMInitializeX86TargetMC();
			LLVMInitializeX86AsmPrinter();
		}

		LLVMLinkInMCJIT();

		llvmMachineTarget = createTargetMachine(target);
	}

	override void close()
	{
		if (llvmMachineTarget !is null) {
			LLVMDisposeTargetMachine(llvmMachineTarget);
			llvmMachineTarget = null;
		}
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

	override BackendResult compile(ir.Module m, ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string identStr)
	{
		auto state = new VoltState(target, m, ehPersonality, llvmTypeidFor, execDir, identStr);
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

		switch (mTargetType) with (TargetType) {
		case LlvmBitcode: return new BitcodeResult(this, state);
		case Host: return new HostResult(state);
		default: assert(false);
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

/*!
 * A llvm result that saves to bitcode files.
 */
class BitcodeResult : BackendResult
{
protected:
	//! The backend that produced this result.
	LlvmBackend mBackend;
	LLVMContextRef mContext;
	LLVMModuleRef mMod;


public:
	this(LlvmBackend backend, VoltState state)
	{
		this.mBackend = backend;
		this.mContext = state.context;
		this.mMod = state.mod;
		state.context = null;
		state.mod = null;
		state.close();
	}

	override void close()
	{
		if (mMod !is null) {
			LLVMDisposeModule(mMod);
			mMod = null;
		}
		if (mContext !is null) {
			LLVMContextDispose(mContext);
			mContext = null;
		}
	}

	override void saveToFile(string filename)
	{
		writeBitcodeFile(mBackend.target, filename, mMod);
	}

	override BackendResult.CompiledDg getFunction(ir.Function)
	{
		assert(false);
	}
}


/*
 *
 * Helper functions.
 *
 */

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

/*!
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

void writeBitcodeFile(TargetInfo target, string output, LLVMModuleRef mod)
{
	auto triple = getTriple(target);
	auto layout = getLayout(target);
	string nullStr;

	if (triple is null || layout is null) {
		throw makeArchNotSupported();
	}

	LLVMSetTarget(mod, triple);
	LLVMSetDataLayout(mod, layout);
	LLVMWriteBitcodeToFile(mod, output);
	LLVMSetDataLayout(mod, nullStr);
	LLVMSetTarget(mod, nullStr);
}

void writeObjectFile(TargetInfo target, string output, string input)
{
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

	auto machine = createTargetMachine(target);
	scope (exit) {
		LLVMDisposeTargetMachine(machine);
	}
	return writeObjectFile(machine, output, mod);
}

void writeObjectFile(LLVMTargetMachineRef machine, string output, LLVMModuleRef mod)
{
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

/*!
 * Create a target machine.
 */
LLVMTargetMachineRef createTargetMachine(TargetInfo target)
{
	auto arch = getArchTarget(target);
	auto triple = getTriple(target);

	if (arch is null || triple is null) {
		throw makeArchNotSupported();
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
	return LLVMCreateTargetMachine(llvmTarget, triple, "", "",
	                               opt, reloc, codeModel);
}

/*!
 * Used to select LLVMTarget.
 */
string getArchTarget(TargetInfo target)
{
	final switch (target.arch) with (Arch) {
	case X86: return "x86";
	case X86_64: return "x86-64";
	}
}

/*!
 * Returns the llvm triple string for the given target.
 */
string getTriple(TargetInfo target)
{
	final switch (target.platform) with (Platform) {
	case MinGW:
		final switch (target.arch) with (Arch) {
		case X86: return "i686-w64-windows-gnu";
		case X86_64: return "x86_64-w64-windows-gnu";
		}
	case Metal:
		final switch (target.arch) with (Arch) {
		case X86: return "i686-pc-none-elf";
		case X86_64: return "x86_64-pc-none-elf";
		}
	case MSVC:
		final switch (target.arch) with (Arch) {
		case X86: assert(false);
		case X86_64: return "x86_64-pc-windows-msvc";
		}
	case Linux:
		final switch (target.arch) with (Arch) {
		case X86: return "i386-pc-linux-gnu";
		case X86_64: return "x86_64-pc-linux-gnu";
		}
	case OSX:
		final switch (target.arch) with (Arch) {
		case X86: return "i386-apple-macosx10.9.0";
		case X86_64: return "x86_64-apple-macosx10.9.0";
		}
	}
}

/*!
 * Returns the llvm layout string for the given target.
 */
string getLayout(TargetInfo target)
{
	final switch (target.platform) with (Platform) {
	case MinGW:
		final switch (target.arch) with (Arch) {
		case X86: return layoutWinLinux32;
		case X86_64: return layoutWinLinux64;
		}
	case Metal:
		final switch (target.arch) with (Arch) {
		case X86: return layoutMetal32;
		case X86_64: return layoutMetal64;
		}
	case MSVC:
		final switch (target.arch) with (Arch) {
		case X86: assert(false);
		case X86_64: return layoutWinLinux64;
		}
	case Linux:
		final switch (target.arch) with (Arch) {
		case X86: return layoutWinLinux32;
		case X86_64: return layoutWinLinux64;
		}
	case OSX:
		final switch (target.arch) with (Arch) {
		case X86: return layoutOSX32;
		case X86_64: return layoutOSX64;
		}
	}
}

/*!
 * Layout strings grabbed from clang.
 */
enum string layoutWinLinux32 = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128";
enum string layoutWinLinux64 = "e-m:e-i64:64-f80:128-n8:16:32:64-S128";
enum string layoutOSX32 = "e-m:o-p:32:32-f64:32:64-f80:128-n8:16:32-S128";
enum string layoutOSX64 = "e-m:o-i64:64-f80:128-n8:16:32:64-S128";

/*!
 * Bare metal layout, grabbed from clang with target "X-pc-none-elf".
 */
enum string layoutMetal32 = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128";
enum string layoutMetal64 = "e-m:e-i64:64-f80:128-n8:16:32:64-S128";
