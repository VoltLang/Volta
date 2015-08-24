// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.interfaces;

import volt.errors;

public import lib.llvm.core;
public import lib.llvm.c.DIBuilder : LLVMDIBuilderRef;

public import volt.interfaces;
public import ir = volt.ir.ir;

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
 * collide in meaning with language concepts.
 *
 * One is created for each Volt module that is compiled.
 */
abstract class State
{
public:
	LanguagePass lp;
	ir.Module irMod;

	LLVMContextRef context;
	LLVMBuilderRef builder;
	LLVMDIBuilderRef diBuilder;
	LLVMModuleRef mod;

	static struct PathState
	{
	public:
		LLVMBasicBlockRef landingBlock;
		LLVMBasicBlockRef continueBlock;
		LLVMBasicBlockRef breakBlock;
	}

	static struct SwitchState
	{
		LLVMBasicBlockRef def;
		LLVMBasicBlockRef[long] cases;
	}

	static struct FunctionState
	{
		LLVMValueRef func;
		bool fall; ///< Tracking for auto branch generation.

		PathState path;
		LLVMBasicBlockRef block;

		SwitchState swi;
	}

	FunctionState fnState;

	final @property LLVMValueRef func() { return fnState.func; }
	final @property bool fall() { return fnState.fall; }
	final @property LLVMBasicBlockRef block() { return fnState.block; }
	final @property PathState path() { return fnState.path; }

	final @property LLVMBasicBlockRef breakBlock() { return fnState.path.breakBlock; }
	final @property LLVMBasicBlockRef continueBlock() { return fnState.path.continueBlock; }
	final @property LLVMBasicBlockRef landingBlock() { return fnState.path.landingBlock; }

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
	abstract LLVMValueRef getFunctionValue(ir.Function fn, out Type type);

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
	 */
	abstract LLVMValueRef buildCallOrInvoke(LLVMValueRef fn, LLVMValueRef[] args);

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
}
