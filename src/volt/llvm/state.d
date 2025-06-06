/*#D*/
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Implementation of the @ref volt.llvm.interfaces.State class.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.state;

import lib.llvm.core;
import watt.text.string : startsWith;

import volt.errors;
import volt.interfaces;
import ir = volta.ir;

import volta.visitor.visitor;

import volta.ir.location;
import volt.semantic.lookup;

import volt.llvm.constant;
import volt.llvm.toplevel;
import volt.llvm.expression;
import volt.llvm.interfaces;


/*!
 * Collection of objects used by pretty much all of the translation
 * code. It isn't called Module, Context or Builder because it will
 * collide in meaning with language concepts.
 *
 * One is created for each Volt module that is compiled.
 *
 * @ingroup llvmbackend
 */
class VoltState : State
{
protected:

	/*!
	 * Used to store defined Variables.
	 */
	static struct Store
	{
		LLVMValueRef value;
		Type type;
	}

	/*!
	 * Store for all the defined llvm values, like functions,
	 * that might be referenced by other code.
	 */
	Store[ir.NodeID] valueStore;

	/*!
	 * Store for all the defined types, types are only defined once.
	 */
	Type[string] typeStore;

	/*!
	 * Visitor to build statements.
	 */
	LlvmVisitor visitor;

	/*
	 * Lazily created & cached.
	 */
	LLVMValueRef mTrapFunc;
	LLVMValueRef mPersonalityFunc;
	LLVMValueRef mTypeIdFunc;
	LLVMValueRef mPadFunc;
	LLVMTypeRef mLandingType;

public:
	this(LanguagePass lp, ir.Module irMod, ir.Function ehPersonality, ir.Function llvmTypeidFor,
		string execDir, string currentWorkingDir, string identStr)
	{
		assert(irMod.name.identifiers.length > 0);
		string name = irMod.name.toString();

		this.irMod = irMod;
		this.context = LLVMContextCreate();
		this.mod = LLVMModuleCreateWithNameInContext(name, context);
		this.builder = LLVMCreateBuilderInContext(context);
		this.diBuilder = diCreateDIBuilder(mod);
		this.lp = lp;
		this.target = lp.target;
		this.execDir = execDir;
		this.currentWorkingDir = currentWorkingDir;
		assert(this.execDir.length > 0);
		this.identStr = identStr;
		assert(this.identStr.length > 0);
		this.ehPersonality = ehPersonality;
		this.llvmTypeidFor = llvmTypeidFor;

		uint enumKind;
		enumKind = LLVMGetEnumAttributeKindForName("byval", 5);
		version (LLVMVersion12AndAbove) {
			this.attrByValKind = enumKind;
		} else {
			this.attrByVal = LLVMCreateEnumAttribute(this.context, enumKind, 0);
		}
		enumKind = LLVMGetEnumAttributeKindForName("sret", 4);
		version (LLVMVersion13AndAbove) {
			this.attrSRetKind = enumKind;
		} else {
			this.attrSRet = LLVMCreateEnumAttribute(this.context, enumKind, 0);
		}
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
		if (diBuilder !is null) {
			diDisposeDIBuilder(/*#ref*/diBuilder);
		}
		if (builder !is null) {
			LLVMDisposeBuilder(builder);
			builder = null;
		}
		if (mod !is null) {
			LLVMDisposeModule(mod);
			mod = null;
		}
		if (context !is null) {
			LLVMContextDispose(context);
			context = null;
		}
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
		return mPersonalityFunc = getFunctionValue(ehPersonality, /*#out*/type);
	}

	@property override LLVMValueRef ehTypeIdFunc()
	{
		if (mTypeIdFunc !is null) {
			return mTypeIdFunc;
		}

		Type type;
		return mTypeIdFunc = getFunctionValue(llvmTypeidFor, /*#out*/type);
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

		fnState.indexVar = buildAlloca(
			intType.llvmType, "__index");

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

		fnState.exceptionVar = buildAlloca(
			voidPtrType.llvmType, "__exception");

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
		v = LLVMBuildInsertValue(builder, v, LLVMBuildLoad(builder, ehExceptionVar), 0, "");
		v = LLVMBuildInsertValue(builder, v, LLVMBuildLoad(builder, ehIndexVar), 1, "");
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

	override LLVMValueRef buildCallNeverInvoke(ref Location loc,
	                                           LLVMValueRef argFunc,
	                                           LLVMValueRef[] args)
	{
		diSetPosition(this, /*#ref*/loc);
		scope (success) {
			diUnsetPosition(this);
		}

		return LLVMBuildCall(builder, argFunc, args);
	}

	override LLVMValueRef buildCallOrInvoke(ref Location loc,
	                                        LLVMValueRef argFunc,
	                                        LLVMValueRef[] args)
	{
		auto p = findLanding();
		if (p is null) {
			return buildCallOrInvoke(/*#ref*/loc, argFunc, args, null);
		} else {
			return buildCallOrInvoke(/*#ref*/loc, argFunc, args, p.landingBlock);
		}
	}

	override LLVMValueRef buildCallOrInvoke(ref Location loc,
	                                        LLVMValueRef argFunc,
	                                        LLVMValueRef[] args,
	                                        LLVMBasicBlockRef landingBlock)
	{
		diSetPosition(this, /*#ref*/loc);
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

	/*!
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
			throw panic(/*#ref*/argFunc.loc, "function without type");
		}
		if (argFunc.kind == ir.Function.Kind.Invalid) {
			throw panic(/*#ref*/argFunc.loc, "invalid function kind");
		}

		LLVMValueRef v;
		type = this.fromIr(argFunc.type);
		auto ft = cast(FunctionType)type;

		if (argFunc.loadDynamic) {
			auto llvmType = ft.llvmType;

			v = LLVMAddGlobal(mod, llvmType, argFunc.mangledName);
			assert(!argFunc.isMergable);
		} else if (argFunc.mangledName == "vrt_eh_personality_v0") {

			// This is a horribly hack to make ThinLTO work.
			// The hasBody path is not currently in use as
			// a different workaround is in place. But we keep
			// the code here just in case we need it in the future.
		        if (argFunc.hasBody) {
				v = ehPersonalityFunc;
			} else {
				v = LLVMAddFunction(mod, argFunc.mangledName, ft.llvmCallType);
			}

			// Don't emit any other attributes for this function.
			LLVMSetVisibility(v, LLVMVisibility.Protected);
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
			version (LLVMVersion13AndAbove) {
				assert(ft.ret.sRetTypeAttr !is null);
				LLVMAddAttributeAtIndex(v, index, ft.ret.sRetTypeAttr);
			} else {
				LLVMAddAttributeAtIndex(v, index, attrSRet);
			}
		}

		Store add = { v, type };
		valueStore[k] = add;
		return v;
	}

	/*!
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
			throw panic(/*#ref*/var.loc, "variable without type");
		}

		type = this.fromIr(var.type);
		LLVMValueRef v;
		LLVMTypeRef llvmType;

		/*!
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
			throw panic(/*#ref*/var.loc, "unclassified variable");
		case Field:
			throw panic(/*#ref*/var.loc, "field variable refered directly");
		case Function, Nested:
			if (func is null) {
				throw panic(/*#ref*/var.loc,
					"non-local/global variable in non-function scope");
			}
			if (var.useBaseStorage) {
				throw panic(/*#ref*/var.loc,
					"useBaseStorage can not be used on function variables");
			}

			diSetPosition(this, /*#ref*/var.loc);
			v = buildAlloca(llvmType, var.name);

			diLocalVariable(this, var, type, v);
			diUnsetPosition(this);

			if (var.name == "__nested") {
				assert(fnState.nested is null);
				fnState.nested = v;
			}

			break;
		case Local:
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);

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
			v = LLVMAddGlobal(mod, llvmType, var.mangledName);
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
			throw panic(/*#ref*/var.loc, "variable without type");

		type = this.fromIr(var.type);
		LLVMValueRef v;
		LLVMTypeRef llvmType;

		llvmType = type.llvmType;

		if (func is null) {
			throw panic(/*#ref*/var.loc, "non-local/global variable in non-function scope");
		}

		diSetPosition(this, /*#ref*/var.loc);
		v = buildAlloca(llvmType, var.name);

		diParameterVariable(this, var, type, v);
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

		/*!
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
	do {
		typeStore[mangledName] = type;
	}

	override Type getTypeNoCreate(string mangledName)
	in {
		assert(mangledName.length > 0);
	}
	do {
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
