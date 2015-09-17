// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.common;

import volt.ir.util;
import volt.llvm.interfaces;


/**
 * Common handle functions for both inline and constants.
 *
 * All of the error checking should have been done in other passes and
 * unimplemented features is checked for in the called functions.
 * @{
 */
void handleConstant(State state, ir.Constant asConst, Value result)
{
	auto type = state.fromIr(asConst.type);
	type.fromConstant(state, asConst, result);
}

void handleArrayLiteral(State state, ir.ArrayLiteral al, Value result)
{
	auto type = state.fromIr(al.type);
	type.fromArrayLiteral(state, al, result);
}

void handleStructLiteral(State state, ir.StructLiteral sl, Value result)
{
	auto type = state.fromIr(sl.type);
	type.fromStructLiteral(state, sl, result);
}

void handleUnionLiteral(State state, ir.UnionLiteral ul, Value result)
{
	auto type = state.fromIr(ul.type);
	type.fromUnionLiteral(state, ul, result);
}

void handleClassLiteral(State state, ir.ClassLiteral cl, Value result)
{
	auto tr = cast(ir.TypeReference)cl.type;
	assert(tr !is null);

	auto _class = cast(ir.Class)tr.type;
	assert(_class !is null);

	auto pt = cast(PointerType)state.fromIr(_class);
	assert(pt !is null);

	auto st = cast(StructType)pt.base;
	assert(st !is null);

	auto sl = new ir.StructLiteral();
	sl.location = cl.location;
	sl.type = copyTypeSmart(_class.location, _class.layoutStruct);
	auto eref = buildExpReference(cl.location, _class.vtableVariable, _class.vtableVariable.name);
	sl.exps ~= buildAddrOf(cl.location, eref);
	sl.exps ~= cl.exps;

	st.fromStructLiteral(state, sl, result);

	if (!cl.useBaseStorage) {
		auto g = LLVMAddGlobal(state.mod, st.llvmType, "");
		LLVMSetGlobalConstant(g, true);
		LLVMSetInitializer(g, result.value);

		result.isPointer = false;
		result.type = pt;
		result.value = g;
	}
}
/**
 * @}
 */
