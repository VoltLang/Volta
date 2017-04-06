// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.state;

import lib.llvm.core;
import watt.text.string : startsWith;

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
	 */
	Store[ir.NodeID] valueStore;

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
	this(TargetInfo target, ir.Module irMod, ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string identStr)
	{
		assert(irMod.name.identifiers.length > 0);
		string name = irMod.name.toString();

		this.irMod = irMod;
		this.context = LLVMContextCreate();
		this.mod = LLVMModuleCreateWithNameInContext(name, context);
		this.builder = LLVMCreateBuilderInContext(context);
		this.diBuilder = LLVMCreateDIBuilder(mod);
		this.target = target;
		this.execDir = execDir;
		assert(this.execDir.length > 0);
		this.identStr = identStr;
		assert(this.identStr.length > 0);
		this.ehPersonality = ehPersonality;
		this.llvmTypeidFor = llvmTypeidFor;

		uint enumKind;
		enumKind = LLVMGetEnumAttributeKindForName("sret", 4);
		this.attrSRet = LLVMCreateEnumAttribute(this.context, enumKind, 0);
		enumKind = LLVMGetEnumAttributeKindForName("byval", 5);
		this.attrByVal = LLVMCreateEnumAttribute(this.context, enumKind, 0);
		enumKind = LLVMGetEnumAttributeKindForName("uwtable", 7);
		this.attrUWTable = LLVMCreateEnumAttribute(this.context, enumKind, 0);

		buildCommonTypes(this, target.isP64);

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
		return mPersonalityFunc = getFunctionValue(ehPersonality, type);
	}

	@property override LLVMValueRef ehTypeIdFunc()
	{
		if (mTypeIdFunc !is null) {
			return mTypeIdFunc;
		}

		Type type;
		return mTypeIdFunc = getFunctionValue(llvmTypeidFor, type);
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

		auto ty = intType;
		fnState.indexVar = buildAlloca(intType, "__exception");

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

		fnState.exceptionVar = buildAlloca(voidPtrType, "__exception");

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
		auto k = argFunc.uniqueId;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		if (argFunc.type is null) {
			throw panic(argFunc.loc, "function without type");
		}
		if (argFunc.kind == ir.Function.Kind.Invalid) {
			throw panic(argFunc.loc, "invalid function kind");
		}

		LLVMValueRef v;
		type = this.fromIr(argFunc.type);
		auto ft = cast(FunctionType)type;

		if (argFunc.loadDynamic) {
			v = addGlobal(ft, argFunc.mangledName);
			assert(!argFunc.isMergable);
		} else {
			// The simple stuff, declare that mofo.
			auto llvmType = ft.llvmCallType;
			v = LLVMAddFunction(mod, argFunc.mangledName, llvmType);
			if (argFunc.isMergable) {
				LLVMSetUnnamedAddr(v, true);
				// For lack of COMDAT support.
				if (target.platform == Platform.MSVC ||
				    target.platform == Platform.MinGW) {
					LLVMSetLinkage(v, LLVMLinkage.Internal);
				} else {
					LLVMSetLinkage(v, LLVMLinkage.LinkOnceODR);
				}
			}

			// Needs to be done here, because this can not be set on a type.
			if (argFunc.type.linkage == ir.Linkage.Windows) {
				if (target.arch == Arch.X86_64) {
					LLVMSetFunctionCallConv(v, LLVMCallConv.X86_64_Win64);
				} else {
					LLVMSetFunctionCallConv(v, LLVMCallConv.X86Stdcall);
				}
			}

			if (!argFunc.isBuiltinFunction()) {
				// Always add a unwind table.
				// TODO: Check for nothrow
				LLVMAddAttributeAtIndex(v, LLVMAttributeIndex.Function, attrUWTable);

				// Always emit the frame pointer.
				// TODO: Add support for -O*optimization
				// TODO: Add support for -f[no-]omit-frame-pointer
				LLVMAddTargetDependentFunctionAttr(v, "no-frame-pointer-elim", "false");
				LLVMAddTargetDependentFunctionAttr(v, "no-frame-pointer-elim-non-leaf", "");
			}
		}

		// Handle return structs via arguments.
		if (ft.hasStructRet) {
			if (argFunc.loadDynamic) {
				throw panic("return struct and @loadDynamic not supported");
			}

			auto index = cast(LLVMAttributeIndex)1;
			LLVMAddAttributeAtIndex(v, index, attrSRet);
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
		auto k = var.uniqueId;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		if (var.type is null) {
			throw panic(var.loc, "variable without type");
		}

		type = this.fromIr(var.type);
		LLVMValueRef v;
		LLVMTypeRef llvmType;
		Type allocType;

		/**
		 * Deal with which storage should be used.
		 * Note that the LLVM function below automatically wrap
		 * wrap the type with a pointer, because the value returns
		 * a pointer to the storage.
		 */
		if (!var.useBaseStorage) {
			llvmType = type.llvmType;
			allocType = type;
		} else {
			auto pt = cast(PointerType)type;
			assert(pt !is null);
			llvmType = pt.base.llvmType;
			allocType = pt.base;
		}

		final switch(var.storage) with (ir.Variable.Storage) {
		case Invalid:
			throw panic(var.loc, "unclassified variable");
		case Field:
			throw panic(var.loc, "field variable refered directly");
		case Function, Nested:
			if (func is null) {
				throw panic(var.loc,
					"non-local/global variable in non-function scope");
			}
			if (var.useBaseStorage) {
				throw panic(var.loc,
					"useBaseStorage can not be used on function variables");
			}

			diSetPosition(this, var.loc);
			v = buildAlloca(allocType, var.name);

			diAutoVariable(this, var, v, type);
			diUnsetPosition(this);

			if (var.name == "__nested") {
				assert(fnState.nested is null);
				fnState.nested = v;
			}

			break;
		case Local:
			v = addGlobal(allocType, var.mangledName);

			/*
			 * LLVM on Windows (as of 3.2) does not support TLS.
			 * So for now, make all Variables marked as local global,
			 * else nothing will work at all.
			 *
			 * Also disabled on Metal.
			 */
			if (target.platform != Platform.MinGW &&
			    target.platform != Platform.Metal) {
				LLVMSetThreadLocal(v, true);
			}
			break;
		case Global:
			v = addGlobal(allocType, var.mangledName);
			// @TODO Horrible hack for weird linking bugs,
			// proper fix is adding a weak attribute in the language.
			if ((var.mangledName == "__bss_start" ||
			     var.mangledName == "end") &&
			    target.platform == Platform.Linux ) {
				LLVMSetLinkage(v, LLVMLinkage.ExternalWeak);
			} else if (var.isMergable) {
				LLVMSetUnnamedAddr(v, true);
				// For lack of COMDAT support.
				if (target.platform == Platform.MSVC ||
				    target.platform == Platform.MinGW) {
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
		auto k = var.uniqueId;
		auto ret = k in valueStore;

		if (ret !is null) {
			type = ret.type;
			return ret.value;
		}

		if (var.type is null)
			throw panic(var.loc, "variable without type");

		type = this.fromIr(var.type);
		LLVMValueRef v;

		if (func is null) {
			throw panic(var.loc, "non-local/global variable in non-function scope");
		}

		diSetPosition(this, var.loc);
		v = buildAlloca(type, var.name);

		diParameterVariable(this, var, v, type);
		diUnsetPosition(this);

		Store add = { v, type };
		valueStore[k] = add;
		return v;
	}

	override void makeByValVariable(ir.FunctionParam var, LLVMValueRef v)
	{
		auto k = var.uniqueId;
		assert((k in valueStore) is null);

		auto type = this.fromIr(var.type);
		Store add = { v, type };
		valueStore[k] = add;
	}

	override void makeThisVariable(ir.Variable var, LLVMValueRef v)
	{
		auto k = var.uniqueId;
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
		auto k = var.uniqueId;
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

bool isBuiltinFunction(ir.Function func)
{
	if (startsWith(func.mangledName, "llvm.")) {
		return true;
	}

	return false;
}
