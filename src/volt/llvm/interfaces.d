// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.interfaces;

import volt.errors;

public import lib.llvm.core;
public import lib.llvm.c.DIBuilder : LLVMDIBuilderRef;

public import volt.token.location;
public import volt.interfaces;
public import ir = volt.ir.ir;

public import volt.llvm.di;
public import volt.llvm.type;


/**
 * Represents a single LLVMValueRef plus the associated high level type.
 *
 * A Value can be in reference form where it is actually a pointer
 * to the give value, since all variables are stored as alloca'd
 * memory in a function we will not insert loads until needed.
 * This is needed for '&' to work and struct lookups.
 */
class Value
{
public:
	Type type;
	LLVMValueRef value;

	bool isPointer; ///< Is this a reference to the real value?

public:
	this()
	{
	}

	this(Value val)
	{
		this.isPointer = val.isPointer;
		this.type = val.type;
		this.value = val.value;
	}
}

/**
 * Collection of objects used by pretty much all of the translation
 * code. It isn't called Module, Context or Builder because it will
 * collide in meaning with LLVM and language concepts.
 *
 * One is created for each Volt module that is compiled.
 */
abstract class State
{
public:
	LanguagePass lp;
	ir.Module irMod;
	string execDir;
	string identStr;

	LLVMContextRef context;
	LLVMBuilderRef builder;
	LLVMDIBuilderRef diBuilder;
	LLVMModuleRef mod;

	static final class PathState
	{
	public:
		PathState prev;

		LLVMBasicBlockRef landingBlock;
		LLVMBasicBlockRef continueBlock;
		LLVMBasicBlockRef breakBlock;

		LLVMValueRef[] scopeSuccess;
		LLVMValueRef[] scopeFailure;
		LLVMBasicBlockRef[] scopeLanding;

		LLVMBasicBlockRef catchBlock;
		LLVMValueRef[] catchTypeInfos;
	}

	static struct SwitchState
	{
		LLVMBasicBlockRef def;
		LLVMBasicBlockRef[long] cases;
	}

	static struct FunctionState
	{
		LLVMValueRef func;
		LLVMValueRef di;

		bool fall; ///< Tracking for auto branch generation.

		LLVMValueRef nested; ///< Nested value

		PathState path;
		LLVMValueRef entryBr;
		LLVMBasicBlockRef block;

		SwitchState swi;

		LLVMValueRef indexVar;
		LLVMValueRef exceptionVar;
		LLVMBasicBlockRef resumeBlock;
		LLVMBasicBlockRef exitBlock;
	}

	FunctionState fnState;

	final @property LLVMValueRef func() { return fnState.func; }
	final @property bool fall() { return fnState.fall; }
	final @property LLVMBasicBlockRef block() { return fnState.block; }
	final @property PathState path() { return fnState.path; }

	final @property LLVMBasicBlockRef switchDefault() { return fnState.swi.def; }
	final LLVMBasicBlockRef switchSetCase(long val, LLVMBasicBlockRef ret)
	{ fnState.swi.cases[val] = ret; return ret; }
	final bool switchGetCase(long val, out LLVMBasicBlockRef ret)
	{
		auto p = val in fnState.swi.cases;
		if (p is null) {
			return false;
		}
		ret = *p;
		return true;
	}

	final PathState findLanding()
	{
		auto p = path;
		assert(p !is null);
		while (p !is null && p.landingBlock is null) {
			p = p.prev;
		}
		return p;
	}

	final PathState findCatch()
	{
		auto p = path;
		assert(p !is null);
		while (p !is null && p.catchBlock is null) {
			p = p.prev;
		}
		return p;
	}

	final PathState findContinue()
	{
		auto p = path;
		assert(p !is null);
		while (p.continueBlock is null) {
			p = p.prev;
			assert(p !is null);
		}
		return p;
	}

	final PathState findBreak()
	{
		auto p = path;
		assert(p !is null);
		while (p.breakBlock is null) {
			p = p.prev;
			assert(p !is null);
		}
		return p;
	}


	/**
	 * Global and local constructors and destructors.
	 * @{
	 */
	LLVMValueRef[] globalConstructors;
	LLVMValueRef[] globalDestructors;
	LLVMValueRef[] localConstructors;
	LLVMValueRef[] localDestructors;
	/**
	 * @}
	 */

	/**
	 * Debug helper variables.
	 * @{
	 */
	LLVMValueRef diCU;
	/**
	 * @}
	 */

	/**
	 * Cached type for convenience.
	 * @{
	 */
	VoidType voidType;

	PrimitiveType boolType;
	PrimitiveType byteType;
	PrimitiveType ubyteType;
	PrimitiveType intType;
	PrimitiveType uintType;
	PrimitiveType ulongType;

	PointerType voidPtrType;

	PrimitiveType sizeType;

	FunctionType voidFunctionType;
	FunctionType springType;
	/**
	 * @}
	 */

	/**
	 * LLVM intrinsic.
	 * @{
	 */
	@property abstract LLVMValueRef llvmTrap();
	/**
	 * @}
	 */

	/**
	 * Exception handling.
	 * @{
	 */
	@property abstract LLVMValueRef ehPersonalityFunc();
	@property abstract LLVMValueRef ehTypeIdFunc();
	@property abstract LLVMTypeRef ehLandingType();
	@property abstract LLVMBasicBlockRef ehResumeBlock();
	@property abstract LLVMBasicBlockRef ehExitBlock();
	@property abstract LLVMValueRef ehIndexVar();
	@property abstract LLVMValueRef ehExceptionVar();
	/**
	 * @}
	 */


public:
	abstract void close();

	abstract void onFunctionClose();

	/*
	 *
	 * High level building blocks.
	 *
	 */

	/**
	 * Build a complete module with this state.
	 */
	abstract void compile(ir.Module m);

	/**
	 * Builds the given statement class at the current place,
	 * and any sub-expressions & -statements.
	 */
	abstract void evaluateStatement(ir.Node node);

	/*
	 *
	 * Expression value functions.
	 *
	 */

	/**
	 * Builds a 'alloca' instructions and inserts it at the end of the
	 * entry basic block that is at the top of the function.
	 */
	final LLVMValueRef buildAlloca(LLVMTypeRef llvmType, string name)
	{
		LLVMPositionBuilderBefore(builder, fnState.entryBr);
		auto v = LLVMBuildAlloca(builder, llvmType, name);
		LLVMPositionBuilderAtEnd(builder, fnState.block);
		return v;
	}

	/**
	 * Returns the LLVMValueRef for the given expression,
	 * evaluated at the current state.builder location.
	 */
	final LLVMValueRef getValue(ir.Exp exp)
	{
		auto v = new Value();
		getValue(exp, v);
		return v.value;
	}

	/**
	 * Returns the value, making sure that the value is not in
	 * reference form, basically inserting load instructions where needed.
	 */
	final void getValue(ir.Exp exp, Value result)
	{
		getValueAnyForm(exp, result);
		if (!result.isPointer)
			return;
		result.value = LLVMBuildLoad(builder, result.value, "");
		result.isPointer = false;
	}

	/**
	 * Returns the value in reference form, basically meaning that
	 * the return value is a pointer to where it is held in memory.
	 */
	final void getValueRef(ir.Exp exp, Value result)
	{
		getValueAnyForm(exp, result);
		if (result.isPointer)
			return;
		throw panic(exp.location, "Value is not a backend reference");
	}

	/**
	 * Returns the value, without doing any checking if it is
	 * in reference form or not.
	 */
	abstract void getValueAnyForm(ir.Exp exp, Value result);

	/**
	 * Returns the LLVMValueRef for the given constant expression,
	 * does not require that state.builder is set.
	 */
	abstract LLVMValueRef getConstant(ir.Exp exp);

	/**
	 * Returns the value, without doing any checking if it is
	 * in reference form or not.
	 */
	abstract void getConstantValueAnyForm(ir.Exp exp, Value result);

	/**
	 * Makes a private mergable global constant. Used for strings,
	 * array literal and storage for struct literals.
	 */
	final LLVMValueRef makeAnonGlobalConstant(LLVMTypeRef t, LLVMValueRef val)
	{
		auto g = LLVMAddGlobal(mod, t, "");
		LLVMSetGlobalConstant(g, true);
		LLVMSetUnnamedAddr(g, true);
		LLVMSetLinkage(g, LLVMLinkage.Private);
		LLVMSetInitializer(g, val);
		return g;
	}


	/*
	 *
	 * Value store functions.
	 *
	 */

	/**
	 * Return the LLVMValueRef for the given Function.
	 *
	 * If the value is not defined it will do so.
	 */
	abstract LLVMValueRef getFunctionValue(ir.Function func, out Type type);

	/**
	 * Return the LLVMValueRef for the given Variable.
	 *
	 * If the value is not defined it will do so.
	 */
	abstract LLVMValueRef getVariableValue(ir.Variable var, out Type type);
	abstract LLVMValueRef getVariableValue(ir.FunctionParam var, out Type type);

	abstract void makeByValVariable(ir.FunctionParam var, LLVMValueRef v);

	abstract void makeThisVariable(ir.Variable var, LLVMValueRef v);
	abstract void makeNestVariable(ir.Variable var, LLVMValueRef v);

	/*
	 *
	 * Type store functions.
	 *
	 */

	abstract void addType(Type type, string mangledName);

	abstract Type getTypeNoCreate(string mangledName);

	/*
	 *
	 * Basic  store functions.
	 *
	 */

	/**
	 * Builds either a call or a invoke. If invoke automatically
	 * sets up a catch basic block and sets the currentBlock to it.
	 *
	 * Gets the landingPad from the current state.
	 */
	abstract LLVMValueRef buildCallOrInvoke(ref Location loc,
	                                        LLVMValueRef func,
	                                        LLVMValueRef[] args);

	/**
	 * Builds either a call or a invoke. If invoke automatically
	 * sets up a catch basic block and sets the currentBlock to it.
	 *
	 * Uses the given landingPad.
	 */
	abstract LLVMValueRef buildCallOrInvoke(ref Location loc,
	                                        LLVMValueRef func,
	                                        LLVMValueRef[] args,
	                                        LLVMBasicBlockRef landingPad);

	/**
	 * Start using a new basic block, setting currentBlock.
	 *
	 * Side-Effects:
	 *   Will reset currentFall.
	 *   Will set the builder to the end of the given block.
	 */
	void startBlock(LLVMBasicBlockRef b)
	{
		fnState.fall = true;
		fnState.block = b;
		LLVMPositionBuilderAtEnd(builder, fnState.block);
	}

	/**
	 * Helper function to swap out the currentContineBlock, returns the old one.
	 */
	LLVMBasicBlockRef replaceContinueBlock(LLVMBasicBlockRef b)
	{
		auto t = fnState.path.continueBlock;
		fnState.path.continueBlock = b;
		return t;
	}

	/**
	 * Helper function to swap out the currentBreakBlock, returns the old one.
	 */
	LLVMBasicBlockRef replaceBreakBlock(LLVMBasicBlockRef b)
	{
		auto t = fnState.path.breakBlock;
		fnState.path.breakBlock = b;
		return t;
	}

	/**
	 * Push a new Path, setting prev as needed.
	 */
	void pushPath()
	{
		auto p = new PathState();
		p.prev = path;
		fnState.path = p;
	}

	/**
	 * Pop a PathState.
	 */
	void popPath()
	{
		fnState.path = path.prev;
	}
}
