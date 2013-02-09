// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.state;

import lib.llvm.core;

import volt.exceptions;
import volt.llvm.interfaces;


/**
 * Collection of objects used by pretty much all of the translation
 * code. It isn't called Module, Context or Builder because it will
 * collide in meaning with language concepts.
 *
 * One is created for each Volt module that is compiled.
 */
class VoltState : State
{
protected:

	/**
	 * Used to store defined Variables.
	 */
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
	this(LLVMContextRef context, ir.Module irMod, bool V_P64)
	{
		assert(irMod.name.identifiers.length > 0);
		string name = irMod.name.toString();

		this.irMod = irMod;
		this.context = context;
		this.mod = LLVMModuleCreateWithNameInContext(name, context);
		this.builder = LLVMCreateBuilderInContext(context);

		buildCommonTypes(this, V_P64);

		this.llvmTrap = LLVMAddFunction(mod, "llvm.trap", voidFunctionType.llvmCallType);
	}

	~this()
	{
		assert(mod is null);
		assert(builder is null);
	}

	override void close()
	{
		LLVMDisposeBuilder(builder);
		LLVMDisposeModule(mod);

		mod = null;
		builder = null;
	}

	/**
	 * Return the LLVMValueRef for the given Function.
	 *
	 * If the value is not defined it will do so.
	 */
	override LLVMValueRef getFunctionValue(ir.Function fn, out Type type)
	{
		auto k = *cast(size_t*)&fn;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		if (fn.type is null)
			throw CompilerPanic(fn.location, "function without type");

		// The simple stuff, declare that mofo.
		type = this.fromIr(fn.type);
		auto ft = cast(FunctionType)type;
		auto llvmType = ft.llvmCallType;
		auto v = LLVMAddFunction(mod, fn.mangledName, llvmType);
		if (fn.isWeakLink)
			LLVMSetLinkage(v, LLVMLinkage.LinkOnceODR);

		valueStore[k] = Store(v, type);
		return v;
	}

	/**
	 * Return the LLVMValueRef for the given Variable.
	 *
	 * If the value is not defined it will do so.
	 */
	override LLVMValueRef getVariableValue(ir.Variable var, out Type type)
	{
		auto k = *cast(size_t*)&var;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		if (var.type is null)
			throw CompilerPanic(var.location, "variable without type");

		type = this.fromIr(var.type);
		LLVMValueRef v;
		LLVMTypeRef llvmType;

		/**
		 * Deal with which storage should be used.
		 * Note that the LLVM function below automatically wrap
		 * wrap the type with a pointer, because the value returns
		 * a pointer to the storage.
		 */
		if (!var.useBaseStorage) {
			llvmType = type.llvmType;
		} else {
			auto pt = cast(PointerType)type;
			assert(pt !is null);
			llvmType = pt.base.llvmType;
		}

		final switch(var.storage) with (ir.Variable.Storage) {
		case Invalid:
			assert(false, "unclassified variable");
		case Field:
			assert(false, "field variable refered directly");
		case Function:
			if (currentFunc is null)
				throw CompilerPanic(var.location,
					"non-local/global variable in non-function scope");
			if (var.useBaseStorage)
				throw CompilerPanic(var.location,
					"useBaseStorage can not be used on function variables");
			v = LLVMBuildAlloca(builder, llvmType, var.name);
			break;
		case Local:
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);
			version (Windows) {
				/* LLVM on Windows (as of 3.1) does not support TLS. 
				 * So for now, make all Variables marked as local global,
				 * else nothing will work at all.
				 */
			} else LLVMSetThreadLocal(v, true);
			break;
		case Global:
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);
			if (var.isWeakLink)
				LLVMSetLinkage(v, LLVMLinkage.LinkOnceODR);
			break;
		}

		valueStore[k] = Store(v, type);
		return v;
	}

	override void makeByValVariable(ir.Variable var, LLVMValueRef v)
	{
		auto k = *cast(size_t*)&var;
		assert((k in valueStore) is null);

		auto type = this.fromIr(var.type);
		valueStore[k] = Store(v, type);
	}

	override void makeThisVariable(ir.Variable var, LLVMValueRef v)
	{
		auto k = *cast(size_t*)&var;
		assert((k in valueStore) is null);

		auto type = this.fromIr(var.type);
		LLVMTypeRef llvmType;

		/**
		 * Deal with which storage should be used.
		 * Need to manually wrap the type in a pointer.
		 */
		if (!var.useBaseStorage) {
			llvmType = LLVMPointerType(type.llvmType, 0);
		} else {
			auto pt = cast(PointerType)type;
			assert(pt !is null); // Just error checking.
			llvmType = type.llvmType;
		}

		v = LLVMBuildBitCast(builder, v, llvmType, "this");
		valueStore[k] = Store(v, type);
	}

	override void addType(Type type, string mangledName)
	in {
		assert(type !is null);
		assert(mangledName.length > 0);
		assert((mangledName in typeStore) is null);
	}
	body {
		typeStore[mangledName] = type;
	}

	override Type getTypeNoCreate(string mangledName)
	in {
		assert(mangledName.length > 0);
	}
	body {
		auto ret = mangledName in typeStore;
		if (ret !is null)
			return *ret;
		return null;
	}
}
