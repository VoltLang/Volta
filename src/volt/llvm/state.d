// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.state;

import lib.llvm.core;

import volt.exceptions;
import volt.llvm.type;


/**
 * Collection of objects used by pretty much all of the translation
 * code. It isn't called Module, Context or Builder because it will
 * collide in meaning with language concepts.
 *
 * One is created for each Volt module that is compiled.
 */
class State
{
public:
	ir.Module irMod;

	LLVMContextRef context;
	LLVMBuilderRef builder;
	LLVMModuleRef mod;

	LLVMBasicBlockRef currentBlock;
	LLVMBasicBlockRef currentBreakBlock; ///< Block to jump to on break.
	LLVMBasicBlockRef currentContinueBlock; ///< Block to jump to on continue.

	LLVMValueRef currentFunc;
	bool currentFall; ///< Tracking for auto branch generation.

	static struct Store
	{
		LLVMValueRef value;
		Type type;
	}

	/**
	 * Store for all the defined llvm values, like functions,
	 * that might be referenced by other code.
	 *
	 * XXX: Depends on the GC not being a moving one.
	 */
	Store[size_t] valueStore;

	/**
	 * Store for all the defined types, types are only defined once.
	 */
	Type[string] typeStore;

public:
	this(LLVMContextRef context, ir.Module irMod)
	{
		assert(irMod.name.identifiers.length > 0);
		string name = irMod.name.identifiers[0].value;
		foreach (n; irMod.name.identifiers[1 .. $]) {
			name ~= "." ~ n.value;
		}

		this.irMod = irMod;
		this.context = context;
		this.mod = LLVMModuleCreateWithNameInContext(name, context);
		this.builder = LLVMCreateBuilderInContext(context);
	}

	~this()
	{
		assert(mod is null);
		assert(builder is null);
	}

	void close()
	{
		LLVMDisposeBuilder(builder);
		LLVMDisposeModule(mod);

		mod = null;
		builder = null;
	}

	void startBlock(LLVMBasicBlockRef b)
	{
		currentFall = true;
		currentBlock = b;
		LLVMPositionBuilderAtEnd(builder, currentBlock);
	}

	/**
	 * Helper function to swap out the currentContineBlock, returns the old one.
	 */
	LLVMBasicBlockRef replaceContinueBlock(LLVMBasicBlockRef b)
	{
		auto t = currentContinueBlock;
		currentContinueBlock = b;
		return t;
	}

	/**
	 * Helper function to swap out the currentBreakBlock, returns the old one.
	 */
	LLVMBasicBlockRef replaceBreakBlock(LLVMBasicBlockRef b)
	{
		auto t = currentBreakBlock;
		currentBreakBlock = b;
		return t;
	}

	/**
	 * Return the LLVMValueRef for the given Function.
	 *
	 * If the value is not defined it will do so.
	 */
	LLVMValueRef getFunctionValue(ir.Function fn, out Type type)
	{
		auto k = *cast(size_t*)&fn;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		// The simple stuff, declare that mofo.
		type = this.fromIr(fn.type);
		auto llvmType = type.llvmType;
		auto v = LLVMAddFunction(mod, fn.mangledName, llvmType);

		valueStore[k] = Store(v, type);
		return v;
	}

	/**
	 * Return the LLVMValueRef for the given Variable.
	 *
	 * If the value is not defined it will do so.
	 */
	LLVMValueRef getVariableValue(ir.Variable var, out Type type)
	{
		auto k = *cast(size_t*)&var;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		type = this.fromIr(var.type);
		LLVMValueRef v;

		final switch(var.storage) with (ir.Variable.Storage) {
		case None:
			if (currentFunc is null)
				throw CompilerPanic(var.location,
					"non-local/global variable in non-function scope");
			v = LLVMBuildAlloca(builder, type.llvmType, var.name);
			break;
		case Local:
			v = LLVMAddGlobal(mod, type.llvmType, var.mangledName);
			LLVMSetThreadLocal(v, true);
			break;
		case Global:
			v = LLVMAddGlobal(mod, type.llvmType, var.mangledName);
			break;
		}

		valueStore[k] = Store(v, type);
		return v;
	}
}
