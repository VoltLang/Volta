// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.state;

import lib.llvm.core;

import volt.errors;
import volt.interfaces;
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

	/**
	 * The settings that the module was compiled with.
	 * Needed for target/platform info and size_t.
	 */
	Settings mSettings;

public:
	this(ir.Module irMod, Settings settings)
	{
		assert(irMod.name.identifiers.length > 0);
		string name = irMod.name.toString();

		this.irMod = irMod;
		this.context = LLVMContextCreate();
		this.mod = LLVMModuleCreateWithNameInContext(name, context);
		this.builder = LLVMCreateBuilderInContext(context);
		this.mSettings = settings;

		setTargetAndLayout();
		buildCommonTypes(this, mSettings.isVersionSet("V_P64"));

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
		LLVMContextDispose(context);

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

		if (fn.type is null) {
			throw panic(fn.location, "function without type");
		}
		if (fn.kind == ir.Function.Kind.Invalid) {
			throw panic(fn.location, "invalid function kind");
		}

		// The simple stuff, declare that mofo.
		type = this.fromIr(fn.type);
		auto ft = cast(FunctionType)type;
		auto llvmType = ft.llvmCallType;
		auto v = LLVMAddFunction(mod, fn.mangledName, llvmType);
		if (fn.isWeakLink) {
			LLVMSetLinkage(v, LLVMLinkage.LinkOnceODR);
		}

		// Needs to be done here, because this can not be set on a type.
		if (fn.type.linkage == ir.Linkage.Windows) {
			LLVMSetFunctionCallConv(v, LLVMCallConv.X86Stdcall);
		}

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
			throw panic(var.location, "variable without type");

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
			throw panic(var.location, "unclassified variable");
		case Field:
			throw panic(var.location, "field variable refered directly");
		case Function:
			if (currentFunc is null)
				throw panic(var.location,
					"non-local/global variable in non-function scope");
			if (var.useBaseStorage)
				throw panic(var.location,
					"useBaseStorage can not be used on function variables");
			v = LLVMBuildAlloca(builder, llvmType, var.name);
			break;
		case Local:
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);

			/* LLVM on Windows (as of 3.2) does not support TLS.
			 * So for now, make all Variables marked as local global,
			 * else nothing will work at all.
			 */
			if (mSettings.platform != Platform.MinGW) {
				LLVMSetThreadLocal(v, true);
			}
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

protected:
	void setTargetAndLayout()
	{
		final switch (mSettings.platform) with (Platform) {
		case Linux:
			LLVMSetTarget(mod, targetLinuxList[mSettings.arch]);
			LLVMSetDataLayout(mod, layoutList[mSettings.arch]);
			break;
		case MinGW:
			LLVMSetTarget(mod, targetMinGWList[mSettings.arch]);
			LLVMSetDataLayout(mod, layoutList[mSettings.arch]);
			break;
		case OSX:
			LLVMSetTarget(mod, targetOSXList[mSettings.arch]);
			LLVMSetDataLayout(mod, layoutOSXList[mSettings.arch]);
			break;
		}
	}
}

/**
 * The subsystem will controll if llc emits coff or ELF object files.
 *
 * - i686-mingw32 emits ELF object files.
 * - i686-pc-mingw32 emits COFF object files.
 * - i686-w64-mingw32 emits COFF object files.
 */
string[] targetMinGWList = [
	"i686-pc-mingw32",
	"x86_64-w64-mingw32",
];

/**
 * This is what clang uses for Linux.
 */
string[] targetLinuxList = [
	"i386-unknown-linux-gnu",
	"x86_64-unknown-linux-gnu",
];

/**
 * This is what clang uses for OSX.
 */
string[] targetOSXList = [
	"i386-apple-macosx10.7.0",
	"x86_64-apple-macosx10.7.0",
];

/**
 * Shared between windows and linux platforms.
 */
string[] layoutList = [
	"e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:32:32-n8:16:32-S128",
	"e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128",
];

/**
 * OSX layouts grabbed from clang.
 */
string[] layoutOSXList = [
	"e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:128:128-n8:16:32-S128",
	"e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128",
];
