// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.interfaces;

public import lib.llvm.core;

public import ir = volt.ir.ir;

public import volt.llvm.value;
public import volt.llvm.type;


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
	ir.Module irMod;

	LLVMContextRef context;
	LLVMBuilderRef builder;
	LLVMModuleRef mod;

	LLVMBasicBlockRef currentBlock;
	LLVMBasicBlockRef currentBreakBlock; ///< Block to jump to on break.
	LLVMBasicBlockRef currentContinueBlock; ///< Block to jump to on continue.

	LLVMValueRef currentFunc;
	bool currentFall; ///< Tracking for auto branch generation.

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
	LLVMValueRef llvmTrap;
	/**
	 * @}
	 */

public:
	abstract void close();

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
	 * Start using a new basic block, setting currentBlock.
	 *
	 * Side-Effects:
	 *   Will reset currentFall.
	 *   Will set the builder to the end of the given block.
	 */
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
}
