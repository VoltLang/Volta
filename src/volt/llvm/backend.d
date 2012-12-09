// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.backend;

import std.string : toStringz;
import std.stdio : writefln;

import volt.exceptions;
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
 *
 */
class LlvmBackend : Backend
{
protected:
	LLVMContextRef mContext;
	string mFilename;
	TargetType mTargetType;
	bool dump;


public:
	this(bool dump)
	{
		this.dump = dump;
		auto passRegistry = LLVMGetGlobalPassRegistry();

		LLVMInitializeCore(passRegistry);
		LLVMInitializeAnalysis(passRegistry);
		LLVMInitializeTarget(passRegistry);

		mContext = LLVMGetGlobalContext();
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

		auto state = new State(mContext, m);
		auto visitor = new LlvmVisitor(state);
		auto mod = state.mod;

		if (dump)
			writefln("Compiling module");

		visitor.compile(m);

		if (dump) {
			writefln("Dumping module");
			LLVMDumpModule(mod);
		}

		string result;
		auto failed = LLVMVerifyModule(mod, result);
		if (failed) {
			writefln(result);
			throw new CompilerPanic("Module verification failed.");
		}

		LLVMWriteBitcodeToFile(mod, mFilename);

		state.close();
		mFilename = null;
	}
}
