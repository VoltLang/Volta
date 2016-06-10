// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.state;

import lib.llvm.core;

import volt.errors;
import volt.interfaces;
import ir = volt.ir.ir;

import volt.visitor.visitor;

import volt.token.location;
import volt.semantic.lookup;

import volt.llvm.di;
import volt.llvm.constant;
import volt.llvm.toplevel;
import volt.llvm.expression;
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
	 * Visitor to build statements.
	 */
	LlvmVisitor visitor;

	/*
	 * Lazily created & cached.
	 */
	LLVMValueRef mTrapFunc;
	LLVMValueRef mPersonalityFunc;
	LLVMValueRef mTypeIdFunc;
	LLVMTypeRef mLandingType;

public:
	this(LanguagePass lp, ir.Module irMod)
	{
		assert(irMod.name.identifiers.length > 0);
		string name = irMod.name.toString();

		this.irMod = irMod;
		this.context = LLVMContextCreate();
		this.mod = LLVMModuleCreateWithNameInContext(name, context);
		this.builder = LLVMCreateBuilderInContext(context);
		this.diBuilder = LLVMCreateDIBuilder(mod);
		this.lp = lp;

		buildCommonTypes(this, lp.ver.isP64);

		visitor = new LlvmVisitor(this);

		this.diCU = diCompileUnit(this);
	}

	~this()
	{
		assert(mod is null);
		assert(builder is null);
	}

	override void close()
	{
		LLVMDisposeDIBuilder(diBuilder);
		LLVMDisposeBuilder(builder);
		LLVMDisposeModule(mod);
		LLVMContextDispose(context);

		mod = null;
		builder = null;
		diBuilder = null;
	}

	override void compile(ir.Module m)
	{
		visitor.compile(m);
		this.diFinalize();
	}

	override void evaluateStatement(ir.Node node)
	{
		accept(node, visitor);
	}

	override void getValueAnyForm(ir.Exp exp, Value result)
	{
		.getValueAnyForm(this, exp, result);
	}

	override LLVMValueRef getConstant(ir.Exp exp)
	{
		auto v = new Value();
		.getConstantValue(this, exp, v);
		return v.value;
	}

	override void getConstantValueAnyForm(ir.Exp exp, Value result)
	{
		.getConstantValue(this, exp, result);
	}


	/*
	 *
	 * Exception handling.
	 *
	 */

	@property override LLVMValueRef llvmTrap()
	{
		if (mTrapFunc !is null) {
			return mTrapFunc;
		}
		return mTrapFunc = LLVMAddFunction(mod, "llvm.trap", voidFunctionType.llvmCallType);
	}

	@property override LLVMValueRef ehPersonalityFunc()
	{
		if (mPersonalityFunc !is null) {
			return mPersonalityFunc;
		}
		Type type;
		return mPersonalityFunc = getFunctionValue(lp.ehPersonalityFunc, type);
	}

	@property override LLVMValueRef ehTypeIdFunc()
	{
		if (mTypeIdFunc !is null) {
			return mTypeIdFunc;
		}

		auto argFunc = retrieveFunctionFromObject(lp, irMod.location, "__llvm_typeid_for");

		Type type;
		return mTypeIdFunc = getFunctionValue(argFunc, type);
	}

	@property override LLVMTypeRef ehLandingType()
	{
		if (mLandingType !is null) {
			return mLandingType;
		}

		return mLandingType = LLVMStructTypeInContext(context,
			[voidPtrType.llvmType, intType.llvmType], false);
	}

	@property override LLVMValueRef ehIndexVar()
	{
		if (fnState.indexVar !is null) {
			return fnState.indexVar;
		}

		auto bb = LLVMGetFirstBasicBlock(func);
		auto val = LLVMGetFirstInstruction(bb);
		LLVMPositionBuilderBefore(builder, val);

		fnState.indexVar = LLVMBuildAlloca(
			builder, intType.llvmType, "__index");

		LLVMPositionBuilderAtEnd(builder, block);
		return fnState.indexVar;
	}

	@property override LLVMValueRef ehExceptionVar()
	{
		if (fnState.exceptionVar !is null) {
			return fnState.exceptionVar;
		}

		auto bb = LLVMGetFirstBasicBlock(func);
		auto val = LLVMGetFirstInstruction(bb);
		LLVMPositionBuilderBefore(builder, val);

		fnState.exceptionVar = LLVMBuildAlloca(
			builder, voidPtrType.llvmType, "__exception");

		LLVMPositionBuilderAtEnd(builder, block);
		return fnState.exceptionVar;
	}

	@property override LLVMBasicBlockRef ehResumeBlock()
	{
		if (fnState.resumeBlock !is null) {
			return fnState.resumeBlock;
		}

		auto b = LLVMAppendBasicBlockInContext(
			context, func, "resume");
		LLVMPositionBuilderAtEnd(builder, b);

		auto v = LLVMGetUndef(ehLandingType);
		v = LLVMBuildInsertValue(builder, v, LLVMBuildLoad(builder, ehExceptionVar, ""), 0, "");
		v = LLVMBuildInsertValue(builder, v, LLVMBuildLoad(builder, ehIndexVar, ""), 1, "");
		LLVMBuildResume(builder, v);
		LLVMPositionBuilderAtEnd(builder, block);

		return fnState.resumeBlock = b;
	}

	@property override LLVMBasicBlockRef ehExitBlock()
	{
		if (fnState.exitBlock !is null) {
			return fnState.exitBlock;
		}

		auto b = LLVMAppendBasicBlockInContext(
			context, func, "exit");
		LLVMPositionBuilderAtEnd(builder, b);

		return fnState.exitBlock = b;
	}

	override LLVMValueRef buildCallOrInvoke(ref Location loc,
	                                        LLVMValueRef argFunc,
	                                        LLVMValueRef[] args)
	{
		auto p = findLanding();
		if (p is null) {
			return buildCallOrInvoke(loc, argFunc, args, null);
		} else {
			return buildCallOrInvoke(loc, argFunc, args, p.landingBlock);
		}
	}

	override LLVMValueRef buildCallOrInvoke(ref Location loc,
	                                        LLVMValueRef argFunc,
	                                        LLVMValueRef[] args,
	                                        LLVMBasicBlockRef landingBlock)
	{
		diSetPosition(this, loc);
		scope (success) {
			diUnsetPosition(this);
		}

		// If we don't have a landing pad or
		// if the function is a llvm intrinsic
		if (landingBlock is null ||
		    LLVMGetIntrinsicID(argFunc) != 0) {
			return LLVMBuildCall(builder, argFunc, args);
		} else {
			auto b = LLVMAppendBasicBlockInContext(
				context, func, "");
			auto ret = LLVMBuildInvoke(builder, argFunc, args, b,
				landingBlock);
			LLVMMoveBasicBlockAfter(b, block);
			LLVMPositionBuilderAtEnd(builder, b);
			fnState.block = b;
			return ret;
		}
	}

	override void onFunctionClose()
	{
		if (fnState.resumeBlock !is null) {
			LLVMMoveBasicBlockAfter(fnState.resumeBlock, block);
		}

		fnState = FunctionState.init;
	}


	/*
	 *
	 * Value functions.
	 *
	 */

	/**
	 * Return the LLVMValueRef for the given Function.
	 *
	 * If the value is not defined it will do so.
	 */
	override LLVMValueRef getFunctionValue(ir.Function argFunc, out Type type)
	{
		auto k = *cast(size_t*)&argFunc;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		if (argFunc.type is null) {
			throw panic(argFunc.location, "function without type");
		}
		if (argFunc.kind == ir.Function.Kind.Invalid) {
			throw panic(argFunc.location, "invalid function kind");
		}

		LLVMValueRef v;
		type = this.fromIr(argFunc.type);
		auto ft = cast(FunctionType)type;

		if (argFunc.loadDynamic) {
			auto llvmType = ft.llvmType;

			v = LLVMAddGlobal(mod, llvmType, argFunc.mangledName);
			assert(!argFunc.isWeakLink);
		} else {
			// The simple stuff, declare that mofo.
			auto llvmType = ft.llvmCallType;
			v = LLVMAddFunction(mod, argFunc.mangledName, llvmType);
			if (argFunc.isWeakLink) {
				LLVMSetUnnamedAddr(v, true);
				// For lack of COMDAT support.
				if (lp.target.platform == Platform.MSVC ||
				    lp.target.platform == Platform.MinGW) {
					LLVMSetLinkage(v, LLVMLinkage.Internal);
				} else {
					LLVMSetLinkage(v, LLVMLinkage.LinkOnceODR);
				}
			}

			// Needs to be done here, because this can not be set on a type.
			if (argFunc.type.linkage == ir.Linkage.Windows) {
				if (lp.target.arch == Arch.X86_64) {
					LLVMSetFunctionCallConv(v, LLVMCallConv.X86_64_Win64);
				} else {
					LLVMSetFunctionCallConv(v, LLVMCallConv.X86Stdcall);
				}
			}
		}

		Store add = { v, type };
		valueStore[k] = add;
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

		if (var.type is null) {
			throw panic(var.location, "variable without type");
		}

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
		case Function, Nested:
			if (func is null) {
				throw panic(var.location,
					"non-local/global variable in non-function scope");
			}
			if (var.useBaseStorage) {
				throw panic(var.location,
					"useBaseStorage can not be used on function variables");
			}

			diSetPosition(this, var.location);
			v = LLVMBuildAlloca(builder, llvmType, var.name);

			diAutoVariable(this, var, v, type);
			diUnsetPosition(this);

			if (var.name == "__nested") {
				assert(fnState.nested is null);
				fnState.nested = v;
			}

			break;
		case Local:
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);

			/* LLVM on Windows (as of 3.2) does not support TLS.
			 * So for now, make all Variables marked as local global,
			 * else nothing will work at all.
			 */
			if (lp.target.platform != Platform.MinGW) {
				LLVMSetThreadLocal(v, true);
			}
			break;
		case Global:
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);
			if (var.isWeakLink) {
				LLVMSetUnnamedAddr(v, true);
				// For lack of COMDAT support.
				if (lp.target.platform == Platform.MSVC ||
				    lp.target.platform == Platform.MinGW) {
					LLVMSetLinkage(v, LLVMLinkage.Internal);
				} else {
					LLVMSetLinkage(v, LLVMLinkage.LinkOnceODR);
				}
			}
			break;
		}

		Store add = { v, type };
		valueStore[k] = add;
		return v;
	}

	override LLVMValueRef getVariableValue(ir.FunctionParam var, out Type type)
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

		llvmType = type.llvmType;

		if (func is null) {
			throw panic(var.location, "non-local/global variable in non-function scope");
		}

		diSetPosition(this, var.location);
		v = LLVMBuildAlloca(builder, llvmType, var.name);

		diParameterVariable(this, var, v, type);
		diUnsetPosition(this);

		Store add = { v, type };
		valueStore[k] = add;
		return v;
	}

	override void makeByValVariable(ir.FunctionParam var, LLVMValueRef v)
	{
		auto k = *cast(size_t*)&var;
		assert((k in valueStore) is null);

		auto type = this.fromIr(var.type);
		Store add = { v, type };
		valueStore[k] = add;
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
		Store add = { v, type };
		valueStore[k] = add;
	}

	override void makeNestVariable(ir.Variable var, LLVMValueRef v)
	{
		auto k = *cast(size_t*)&var;
		assert((k in valueStore) is null);

		auto type = this.fromIr(var.type);
		LLVMTypeRef llvmType;
		llvmType = LLVMPointerType(type.llvmType, 0);

		v = LLVMBuildBitCast(builder, v, llvmType, "__nested");
		Store add = { v, type };
		valueStore[k] = add;

		assert(fnState.nested is null);
		fnState.nested = v;
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

/**
 * Used to select LLVMTarget.
 */
static string[] archList = [
	"x86",
	"x86-64",
	null,
];

static string[][] tripleList = [
	/*
	 * The subsystem will controll if llc emits coff or ELF object files.
	 *
	 * - i686-mingw32 emits ELF object files.
	 * - i686-pc-mingw32 emits COFF object files, used with mingw32.
	 * - i686-w64-mingw32 emits COFF object files, used with mingw64.
	 *
	 * These are now translated into:
	 *
	 * - i686-pc-windows-gnu - mingw32
	 * - i686-w64-windows-gnu - mingw64
	 *
	 * For linking with MSVC
	 *
	 * - x86_64-pc-windows-msvc
	 */
	[
		"i686-w64-windows-gnu",
		"x86_64-w64-windows-gnu",
		null,
	],

	/*
	 * MSVC platform, see above comment.
	 */
	[
		cast(string)null,
		"x86_64-pc-windows-msvc",
		null,
	],

	/*
	 * This is what clang uses for Linux.
	 */
	[
		"i386-unknown-linux-gnu",
		"x86_64-unknown-linux-gnu",
		null,
	],

	/*
	 * This is what clang uses for OSX.
	 */
	[
		"i386-apple-macosx10.7.0",
		"x86_64-apple-macosx10.7.0",
		cast(string)null,
	],

	/*
	 * This is what emscripten uses.
	 */
	[
		cast(string)null,
		null,
		"le32-unknown-nacl",
	],

	/*
	 * Bare metal.
	 */
	[
		"i686-pc-none-elf",
		"x86_64-pc-none-elf",
		null,
	],
];

static string[][] layoutList = [
	[ // MinGW
		layoutWinLinux32,
		layoutWinLinux64,
		null,
	],
	[ // MSVC
		layoutWinLinux32,
		layoutWinLinux64,
		null,
	],
	[ // Linux
		layoutWinLinux32,
		layoutWinLinux64,
		null,
	],
	[ // Windows
		layoutOSX32,
		layoutOSX64,
		null,
	],
	[ // Emscripten
		cast(string)null,
		null,
		layoutEmscripten,
	],
	[ // Metal
		layoutMetal32,
		layoutMetal64,
		null,
	],
];

/**
 * Shared between windows and linux platforms.
 */
enum string layoutWinLinux32 = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:32:32-n8:16:32-S128";
enum string layoutWinLinux64 = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128";

/**
 * OSX layouts grabbed from clang.
 */
enum string layoutOSX32 = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:128:128-n8:16:32-S128";
enum string layoutOSX64 = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128";

/**
 * The layout that emscripten uses.
 */
enum string layoutEmscripten = "e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-p:32:32:32-v128:32:32";

/**
 * Bare metal layout, grabbed from clang with target "X-pc-none-elf".
 */
enum string layoutMetal32 = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128";
enum string layoutMetal64 = "e-m:e-i64:64-f80:128-n8:16:32:64-S128";
