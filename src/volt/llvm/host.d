/*#D*/
// Copyright 2012-2017, Jakob Bornecrantz.
// Copyright 2015-2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Host or JIT compilation code.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.host;

import io = watt.io.std;
import watt.conv : toStringz;
import watt.text.format : format;

import volt.errors;
import volt.interfaces;
import ir = volta.ir;
import volta.util.util;
import volta.ir.location;
import volt.semantic.classify;

import lib.llvm.core;
import lib.llvm.analysis;
import lib.llvm.executionengine;

import volt.llvm.type;
import volt.llvm.state;


class HostResult : BackendHostResult
{
protected:
	VoltState state;
	LLVMExecutionEngineRef ee;
	BackendHostResult.CompiledDg[ir.NodeID] mCompiledFunctions;
	LLVMModuleRef[] mModules;


public:
	this(VoltState state)
	{
		this.state = state;

		// Initialise the JIT engine.
		ee = null;
		string error;
		if (LLVMCreateMCJITCompilerForModule(&ee, state.mod, null, 0, /*#out*/error)) {
			assert(false, format("JIT CREATION FAILED: %s", error)); // TODO: Real error.
		}
	}

	override BackendHostResult.CompiledDg getFunction(ir.Function func)
	{
		auto p = func.uniqueId in mCompiledFunctions;
		if (p !is null) {
			return *p;
		}

		auto cfs = new SpringBoard(this, func);
		mCompiledFunctions[func.uniqueId] = cfs.dgt;
		return cfs.dgt;
	}

	override void close()
	{
		foreach (mod; mModules) {
			LLVMDisposeModule(mod);
		}
		mModules = null;
		state.close();
	}


protected:
	LLVMModuleRef createAndTrackModule(string name)
	{
		auto mod = LLVMModuleCreateWithNameInContext(name, state.context);
		mModules ~= mod;
		return mod;
	}
}

class SpringBoard
{
public:
	Location loc;
	BackendHostResult.CompiledDg dgt;


protected:
	//! Direct pointer to the host compiled function.
	void* mPtr;

	version (D_Version2) {
		static extern(C) int dmdIsHorribleFvZi();
		static extern(C) int dmdIsHorribleFviZi(int);
		static extern(C) void dmdIsHorribleCall(void*);

		alias FvZi = typeof(&dmdIsHorribleFvZi);
		alias FviZi = typeof(&dmdIsHorribleFviZi);
		alias Call = typeof(&dmdIsHorribleCall);
	} else {
		alias FvZi = int function();
		alias FviZi = int function(int);
		alias Call = void function(void*);
	}

	// Generated SpringBoard fields.
	Call mSpring;
	void* mArgs;
	size_t[] mPos;
	ir.Type mRetType;


public:
	this(HostResult host, ir.Function func)
	{
		this.loc = func.loc;

		mPtr = cast(void*) LLVMGetFunctionAddress(
			host.ee, toStringz(func.mangledName));
		if (mPtr is null) {
			assert(false, "FIND FUNCTION FAILED"); // TODO: Real error.
		}

		switch (func.type.mangledName) {
		case "FvZi": dgt = callFvZi; break;
		case "FviZi": dgt = callFviZi; break;
		default:
			buildSpringBoard(host, func.mangledName, func.type);
			dgt = callSpring;
		}
	}

	void buildSpringBoard(HostResult host, string name, ir.FunctionType type)
	{
		// Convinience.
		auto state = host.state;

		// Create the layout of the data array to pass to the function.
		// First position is the return field.
		size_t counter;
		if (!type.ret.isVoid()) {
			counter += size(state.target, type.ret);
		}

		foreach (t; type.params) {
			mPos ~= counter;
			counter += size(state.target, type.ret);
		}

		mArgs = (new void[](counter)).ptr;
		mRetType = type.ret;


		//
		// Build the springboard function.
		//

		// Setup another module and builder.
		// XXX TODO The module should be added to the state so it
		// will be closed when the state is closed.
		auto modName = format("__mod_%s", name);
		auto mod = host.createAndTrackModule(modName);
		auto builder = LLVMCreateBuilderInContext(state.context);

		// Declare the real function again in this module.
		auto realType = (cast(FunctionType)fromIr(state, type)).llvmCallType;
		auto realFunc = LLVMAddFunction(mod, name, realType);

		// Create the function here.
		auto springName = format("__springboard_%s", name);
		auto springType = state.springType.llvmCallType;
		auto spring = LLVMAddFunction(mod, springName, springType);

		// Setup basicblock and argument(s) to the springboard function.
		auto arr = LLVMGetParam(spring, 0);
		auto block = LLVMAppendBasicBlock(spring, "entry");
		LLVMPositionBuilderAtEnd(builder, block);

		// Grab all of the arguments from the array.
		LLVMValueRef[] args;
		foreach (i, t; type.params) {
			auto index = state.sizeType.fromNumber(state, cast(long)mPos[i]);
			auto ptr = LLVMBuildGEP(builder, arr, [index], "");

			auto argType = state.fromIr(t);
			auto bitType = LLVMPointerType(argType.llvmType, 0);
			auto bit = LLVMBuildBitCast(builder, ptr, bitType, "");
			args ~= LLVMBuildLoad2(builder, argType.llvmType, bit);
		}

		// Call and then store the result in the array.
		auto v = LLVMBuildCall(builder, realFunc, args);
		if (!type.ret.isVoid()) {
			auto bitType = LLVMPointerType(LLVMTypeOf(v), 0);
			auto bit = LLVMBuildBitCast(builder, arr, bitType, "");
			LLVMBuildStore(builder, v, bit);
		}

		// Terminate basicblock.
		LLVMBuildRet(builder, null);

		// Verify the module.
		string result;
		auto failed = LLVMVerifyModule(mod, /*#out*/result);
		if (failed) {
			LLVMDumpModule(mod);
			io.error.writefln("%s", result);
			throw panic("Module verification failed.");
		}

		// Add the module to the execution engine so we can run it.
		LLVMAddModule(host.ee, mod);

		// Cleanup.
		LLVMDisposeBuilder(builder);

		// Update the function pointer.
		mSpring = cast(Call)
			LLVMGetFunctionAddress(host.ee, toStringz(springName));
	}

	ir.Constant callFvZi(ir.Constant[])
	{
		auto call = cast(FvZi) mPtr;
		return buildConstantInt(/*#ref*/loc, call());
	}

	ir.Constant callFviZi(ir.Constant[] a)
	{
		auto call = cast(FviZi) mPtr;
		return buildConstantInt(/*#ref*/loc, call(a[0].u._int));
	}

	ir.Constant callSpring(ir.Constant[] a)
	{
		foreach (i, arg; a) {
			writeConstantToPtr(arg, mArgs + mPos[i]);
		}

		mSpring(mArgs);

		return getConstantFromPtr(/*#ref*/loc, mRetType, mArgs);
	}

	version (D_Version2) {
		BackendHostResult.CompiledDg callFvZi() { return &callFvZi; }
		BackendHostResult.CompiledDg callFviZi() { return &callFviZi; }
		BackendHostResult.CompiledDg callSpring() { return &callSpring; }
	}
}

void writeConstantToPtr(ir.Constant constant, void* ptr)
{
	auto ptype = cast(ir.PrimitiveType)constant.type;
	if (ptype is null) {
		assert(false, "NON PRIMITIVE ARGUMENT");  // TODO: Real error.
	}
	switch (ptype.type) with (ir.PrimitiveType.Kind) {
	case Byte:   *cast(byte*)ptr   = constant.u._byte; break;
	case Ubyte:  *cast(ubyte*)ptr  = constant.u._ubyte; break;
	case Short:  *cast(short*)ptr  = constant.u._short; break;
	case Ushort: *cast(ushort*)ptr = constant.u._ushort; break;
	case Int:    *cast(int*)ptr    = constant.u._int; break;
	case Uint:   *cast(uint*)ptr   = constant.u._uint; break;
	case Long:   *cast(long*)ptr   = constant.u._long; break;
	case Ulong:  *cast(ulong*)ptr  = constant.u._ulong; break;
	case Float:  *cast(float*)ptr  = constant.u._float; break;
	case Double: *cast(double*)ptr = constant.u._double; break;
	default:
		assert(false, "UNHANDLED PRIMITIVE TYPE");  // TODO: Real error.
	}
}

ir.Constant getConstantFromPtr(ref Location loc, ir.Type type, void* ptr)
{
	auto ptype = cast(ir.PrimitiveType)type;
	if (ptype is null) {
		assert(false, "NON PRIMITIVE ARGUMENT");  // TODO: Real error.
	}

	switch (ptype.type) with (ir.PrimitiveType.Kind) {
	case Byte:   return buildConstantByte(/*#ref*/loc, *cast(byte*)ptr);
	case Ubyte:  return buildConstantUbyte(/*#ref*/loc, *cast(ubyte*)ptr);
	case Short:  return buildConstantShort(/*#ref*/loc, *cast(short*)ptr);
	case Ushort: return buildConstantUshort(/*#ref*/loc, *cast(ushort*)ptr);
	case Int:    return buildConstantInt(/*#ref*/loc, *cast(int*)ptr);
	case Uint:   return buildConstantUint(/*#ref*/loc, *cast(uint*)ptr);
	case Long:   return buildConstantLong(/*#ref*/loc, *cast(long*)ptr);
	case Ulong:  return buildConstantUlong(/*#ref*/loc, *cast(ulong*)ptr);
	case Float:  return buildConstantFloat(/*#ref*/loc, *cast(float*)ptr);
	case Double: return buildConstantDouble(/*#ref*/loc, *cast(double*)ptr);
	default:
		assert(false, "UNHANDLED PRIMITIVE TYPE");  // TODO: Real error.
	}
}
