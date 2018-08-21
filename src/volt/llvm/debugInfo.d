/*#D*/
// Copyright © 2015-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Debug info generation code.
 *
 * @ingroup backend llvmbackend
 */
module volt.llvm.debugInfo;

import ir = volta.ir;

import volt.llvm.interfaces;


/*
 *
 * Debug info builder functions.
 *
 */
version(all) {

	LLVMDIBuilderRef diCreateDIBuilder(LLVMModuleRef mod) { return null; }
	void diDisposeDIBuilder(ref LLVMDIBuilderRef) {}

	void diSetPosition(State state, ref Location loc) {}
	void diUnsetPosition(State state) {}
	LLVMMetadataRef diCompileUnit(State state) { return null; }
	void diFinalize(State state) {}
	LLVMMetadataRef diUnspecifiedType(State state, Type t) { return null; }
	LLVMMetadataRef diBaseType(State state, ir.PrimitiveType pt) { return null; }
	LLVMMetadataRef diPointerType(State state, ir.PointerType pt, Type base) { return null; }
	LLVMMetadataRef diStaticArrayType(State state, ir.StaticArrayType sat,
	                               Type type) { return null; }
	LLVMMetadataRef diForwardDeclareAggregate(State state, ir.Type t) { return null; }
	void diUnionReplace(State state, ref LLVMMetadataRef diType, Type p,
	                    ir.Variable[] elms) {}
	void diStructReplace(State state, ref LLVMMetadataRef diType,
	                     ir.Type irType, ir.Variable[] elms) {}
	void diStructReplace(State state, ref LLVMMetadataRef diType,
	                     Type p, Type[2] t, string[2] names) {}
	LLVMMetadataRef diFunctionType(State state, Type ret, Type[] args,
	                               string mangledName,
	                               out LLVMMetadataRef diCallType) { return null; }
	LLVMMetadataRef diFunction(State state, ir.Function irFn,
	                           LLVMValueRef func, FunctionType ft) { return null; }
	void diGlobalVariable(State state, ir.Variable var, Type type,
	                      LLVMValueRef val) {}
	void diLocalVariable(State state, ir.Variable var, Type type,
	                     LLVMValueRef val) {}
	void diParameterVariable(State state, ir.FunctionParam var, Type type,
	                         LLVMValueRef val) { }
}
