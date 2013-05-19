// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.backend;

import std.string : toStringz;
import std.stdio : writefln;

import volt.errors;
import volt.interfaces;

import lib.llvm.core;
import lib.llvm.analysis;
import lib.llvm.bitwriter;
import lib.llvm.c.Initialization;

import volt.llvm.type;
import volt.llvm.state;
import volt.llvm.toplevel;
import volt.llvm.expression;


/**
 * Main interface for the @link volt.interfaces.Controller
 * Controller@endlink to the llvm backend.
 */
class LlvmBackend : Backend
{
protected:
	Settings mSettings;

	TargetType mTargetType;
	string mFilename;
	bool mDump;

public:
	this(Settings settings)
	{
		this.mSettings = settings;
		this.mDump = mSettings.internalDebug;

		auto passRegistry = LLVMGetGlobalPassRegistry();

		LLVMInitializeCore(passRegistry);
		LLVMInitializeAnalysis(passRegistry);
		LLVMInitializeTarget(passRegistry);
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

		auto state = new VoltState(m, mSettings);
		auto visitor = new LlvmVisitor(state);
		auto mod = state.mod;
		scope(exit) {
			state.close();
			mFilename = null;
		}

		if (mDump)
			writefln("Compiling module");

		try {
			visitor.compile(m);
		} catch (Throwable t) {
			if (mDump) {
				writefln("Caught \"%s\" dumping module:", t.classinfo.name);
				LLVMDumpModule(mod);
			}
			throw t;
		}

		if (mDump) {
			writefln("Dumping module");
			LLVMDumpModule(mod);
		}

		string result;
		auto failed = LLVMVerifyModule(mod, result);
		if (failed) {
			writefln("%s", result);
			throw panic("Module verification failed.");
		}

		LLVMWriteBitcodeToFile(mod, mFilename);
	}
}
