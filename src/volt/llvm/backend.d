/*#D*/
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Main module for the @ref llvmbackend.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.backend;

import io = watt.io.std;

import volt.errors;
import volt.interfaces;
import ir = volta.ir;
import volta.util.util;
import volta.ir.location;

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
	LanguagePass lp;
	TargetInfo target;
	LLVMTargetRef llvmTarget;
	LLVMTargetMachineRef llvmMachineTarget;
	bool mDump;


public:
	this(LanguagePass lp, bool internalDebug)
	{
		this.lp = lp;
		this.target = lp.target;
		this.mDump = internalDebug;

		auto passRegistry = LLVMGetGlobalPassRegistry();

		LLVMInitializeCore(passRegistry);
		LLVMInitializeAnalysis(passRegistry);
		LLVMInitializeTarget(passRegistry);

		final switch (target.arch) with (Arch) {
		case X86:
		case X86_64:
			LLVMInitializeX86TargetInfo();
			LLVMInitializeX86Target();
			LLVMInitializeX86TargetMC();
			LLVMInitializeX86AsmPrinter();
			break;
		case ARMHF:
			LLVMInitializeARMTargetInfo();
			LLVMInitializeARMTarget();
			LLVMInitializeARMTargetMC();
			LLVMInitializeARMAsmPrinter();
			break;
		case AArch64:
			LLVMInitializeAArch64TargetInfo();
			LLVMInitializeAArch64Target();
			LLVMInitializeAArch64TargetMC();
			LLVMInitializeAArch64AsmPrinter();
			break;
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
		return [TargetType.LlvmBitcode, TargetType.Object, TargetType.Host];
	}

	override BackendFileResult compileFile(ir.Module m, TargetType type,
		ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string currentWorkingDir, string identStr)
	{
		auto state = compileState(m, ehPersonality, llvmTypeidFor,
		                          execDir, currentWorkingDir, identStr);

		switch (type) with (TargetType) {
		case LlvmBitcode: return new BitcodeResult(this, state);
		case Object: return new ObjectResult(this, state);
		default: assert(false);
		}
	}

	override BackendHostResult compileHost(ir.Module m,
		ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string currentWorkingDir, string identStr)
	{
		auto state = compileState(m, ehPersonality, llvmTypeidFor,
		                          execDir, currentWorkingDir, identStr);
		return new HostResult(state);
	}

	VoltState compileState(ir.Module m,
		ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string currentWorkingDir, string identStr)
	{
		auto state = new VoltState(lp, m, ehPersonality,
			llvmTypeidFor, execDir, currentWorkingDir, identStr);
		auto mod = state.mod;
		scope (failure) {
			state.close();
		}

		if (mDump) {
			io.output.flush();
			io.error.writefln("Compiling module");
			io.error.flush();
		}

		scope (failure) {
			if (mDump) {
				io.output.flush();
				io.error.writefln("Failure, dumping module:");
				io.error.flush();
				LLVMDumpModule(state.mod);
			}
		}
		state.compile(m);

		if (mDump) {
			io.output.flush();
			io.error.writefln("Dumping module");
			io.error.flush();
			LLVMDumpModule(mod);
		}

		string result;
		auto failed = LLVMVerifyModule(mod, /*#out*/result);
		if (failed) {
			io.output.flush();
			io.error.flush();
			io.error.writefln("###### RESULTS START");
			io.error.writefln("%s", result);
			io.error.writefln("###### RESULTS END");
			io.error.writefln("###### DUMP START");
			io.error.flush();
			LLVMDumpModule(mod);
			io.error.flush();
			io.error.writefln("###### DUMP END");
			io.error.flush();
			throw panic("Module verification failed.");
		}

		return state;
	}
}

/*!
 * A llvm result that saves to bitcode files.
 *
 * @ingroup backend llvmbackend
 */
class BitcodeResult : BackendFileResult
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
}

/*!
 * Backend results that procudes a object file.
 *
 * @ingroup backend llvmbackend
 */
class ObjectResult : BitcodeResult
{
public:
	this(LlvmBackend b, VoltState s) { super(b, s); }

	override void saveToFile(string filename)
	{
		auto triple = getTriple(mBackend.target);
		auto layout = getLayout(mBackend.target);

		if (triple is null || layout is null) {
			throw makeArchNotSupported();
		}

		LLVMSetTarget(mMod, triple);
		LLVMSetDataLayout(mMod, layout);
		scope (exit) {
			string nullStr;
			LLVMSetDataLayout(mMod, nullStr);
			LLVMSetTarget(mMod, nullStr);
		}
		writeObjectFile(mBackend.llvmMachineTarget, filename, mMod);
	}
}


/*
 *
 * Helper functions.
 *
 */

/*!
 * Load a LLVMModuleRef into memory from file.
 *
 * @param ctx      The context that the module will be created in.
 * @param filename The bitcode file to load the module from.
 *
 * @ingroup llvmbackend
 */
LLVMModuleRef loadModule(LLVMContextRef ctx, string filename)
{
	string msg;

	auto mod = LLVMModuleFromFileInContext(ctx, filename, /*#ref*/msg);
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
 *
 * @param output The filename to write the result into.
 * @param input  The filenames of the files to link together.
 *
 * @ingroup llvmbackend
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

/*!
 * Write the given module into a bitcode file.
 *
 * @param target Layout and triple decided by the target.
 * @param output The filename that the function writes the bitcode to.
 * @param mod    The module to assemble and write out to the output file.
 *
 * @SideEffect Will overwrite the modules triple and layout information.
 *
 * @ingroup llvmbackend
 */
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

/*!
 * Read a bitcode file from disk, assemble and write the given it to the given
 * filename using the given target. The assemble type and file format is
 * decided by the given target.
 *
 * @param target Decides assemble type and file format.
 * @param output The filename to write the object file to.
 * @param input  The file to read the module from.
 * @ingroup llvmbackend
 */
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

/*!
 * Assemble and write the given module to the given filename using the given
 * target. The assemble type and file format is decided by the given machine.
 *
 * @param machine Used to create the object file, @ref createMachineTarget.
 * @param output  The filename to write the object file to.
 * @param mod     The module to assemble and write out to the output file.
 *
 * @ingroup llvmbackend
 */
void writeObjectFile(LLVMTargetMachineRef machine, string output, LLVMModuleRef mod)
{
	// Write the module to the file
	string msg;
	auto ret = LLVMTargetMachineEmitToFile(
		machine, mod, output,
		LLVMCodeGenFileType.Object, /*#ref*/msg) != 0;

	if (msg !is null && !ret) {
		io.error.writefln("%s", msg); // Warnings
	}
	if (ret) {
		throw makeNoWriteObjectFile(output, msg);
	}
}

/*!
 * Create a target machine.
 *
 * @param target The target for which to create a LLVMTargetMachineRef.
 *
 * @ingroup llvmbackend
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
	if (llvmTarget is null) {
		throw makeArchNotSupported();
	}

	auto opt = LLVMCodeGenOptLevel.Default;
	auto codeModel = LLVMCodeModel.Default;
	auto reloc = LLVMRelocMode.Default;

	// Force -fPIC on linux.
	if (target.platform == Platform.Linux &&
	    (target.arch == Arch.AArch64 ||
	     target.arch == Arch.X86_64)) {
		reloc = LLVMRelocMode.PIC;
	}

	// Create target machine used to hold all of the settings.
	return LLVMCreateTargetMachine(llvmTarget, triple, "", "",
	                               opt, reloc, codeModel);
}

/*!
 * Used to select LLVMTarget.
 *
 * @param target The target to get the arch string for.
 *
 * @ingroup llvmbackend
 */
string getArchTarget(TargetInfo target)
{
	final switch (target.arch) with (Arch) {
	case X86: return "x86";
	case X86_64: return "x86-64";
	case ARMHF: return "arm";
	case AArch64: return "aarch64";
	}
}

/*!
 * Returns the llvm triple string for the given target.
 *
 * @param target The target to get the triple string for.
 *
 * @ingroup llvmbackend
 */
string getTriple(TargetInfo target)
{
	final switch (target.platform) with (Platform) {
	case MinGW:
		final switch (target.arch) with (Arch) {
		case X86: return "i686-w64-windows-gnu";
		case X86_64: return "x86_64-w64-windows-gnu";
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	case Metal:
		final switch (target.arch) with (Arch) {
		case X86: return "i686-pc-none-elf";
		case X86_64: return "x86_64-pc-none-elf";
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	case MSVC:
		final switch (target.arch) with (Arch) {
		case X86: assert(false);
		case X86_64: return "x86_64-pc-windows-msvc";
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	case Linux:
		final switch (target.arch) with (Arch) {
		case X86: return "i386-pc-linux-gnu";
		case X86_64: return "x86_64-pc-linux-gnu";
		case ARMHF: return "armv7l-unknown-linux-gnueabihf";
		case AArch64: return "aarch64-unknown-linux-gnu";
		}
	case OSX:
		final switch (target.arch) with (Arch) {
		case X86: return "i386-apple-macosx10.9.0";
		case X86_64: return "x86_64-apple-macosx10.9.0";
		case ARMHF: assert(false);
		case AArch64: return "arm64-apple-macosx12.0.0"; // Yes arm64
		}
	}
}

/*!
 * Returns the llvm layout string for the given target.
 *
 * @param target The target to get the layout string for.
 *
 * @ingroup llvmbackend
 */
string getLayout(TargetInfo target)
{
	final switch (target.platform) with (Platform) {
	case MinGW:
		final switch (target.arch) with (Arch) {
		case X86: return layoutWinLinux32;
		case X86_64: return layoutWinLinux64;
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	case Metal:
		final switch (target.arch) with (Arch) {
		case X86: return layoutMetal32;
		case X86_64: return layoutMetal64;
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	case MSVC:
		final switch (target.arch) with (Arch) {
		case X86: assert(false);
		case X86_64: return layoutWinLinux64;
		case ARMHF: assert(false);
		case AArch64: assert(false);
		}
	case Linux:
		final switch (target.arch) with (Arch) {
		case X86: return layoutWinLinux32;
		case X86_64: return layoutWinLinux64;
		case ARMHF: return layoutARMHFLinux32;
		case AArch64: return layoutAArch64Linux64;
		}
	case OSX:
		final switch (target.arch) with (Arch) {
		case X86: return layoutOSX32;
		case X86_64: return layoutOSX64;
		case ARMHF: assert(false);
		case AArch64: return layoutAArch64OSX;
		}
	}
}

/*!
 * Layout strings grabbed from clang.
 *
 * @ingroup llvmbackend
 * @{
 */
enum string layoutWinLinux32 = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128";
enum string layoutWinLinux64 = "e-m:e-i64:64-f80:128-n8:16:32:64-S128";
enum string layoutOSX32 = "e-m:o-p:32:32-f64:32:64-f80:128-n8:16:32-S128";
enum string layoutOSX64 = "e-m:o-i64:64-f80:128-n8:16:32:64-S128";
enum string layoutAArch64OSX = "e-m:o-i64:64-i128:128-n32:64-S128";
enum string layoutAArch64Linux64 = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128";
enum string layoutARMHFLinux32 = "e-m:e-p:32:32-i64:64-v128:64:128-a:0:32-n32-S64";
//! @}

/*!
 * Bare metal layout, grabbed from clang with target "X-pc-none-elf".
 *
 * @ingroup llvmbackend
 * @{
 */
enum string layoutMetal32 = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128";
enum string layoutMetal64 = "e-m:e-i64:64-f80:128-n8:16:32:64-S128";
//! @}
