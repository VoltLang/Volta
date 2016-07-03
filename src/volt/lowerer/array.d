// Copyright © 2013-2015, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013-2015, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.array;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.interfaces;
import volt.token.location;

import volt.semantic.util;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;

import volt.lowerer.alloc : buildAllocVoidPtr;


/*
 *
 * Common helpers.
 *
 */

ir.Function getLlvmMemMove(Location loc, LanguagePass lp)
{
	return lp.ver.isP64 ? lp.llvmMemmove64 : lp.llvmMemmove32;
}

ir.Function getLlvmMemCopy(Location loc, LanguagePass lp)
{
	return lp.ver.isP64 ? lp.llvmMemcpy64 : lp.llvmMemcpy32;
}


/*
 *
 * Array function getters.
 *
 */

ir.Function getArrayAppendFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType ltype, ir.Type rtype, bool isAssignment)
{
	if (ltype.mangledName is null) {
		ltype.mangledName = mangle(ltype);
	}
	if (rtype.mangledName is null) {
		rtype.mangledName = mangle(rtype);
	}

	string name;
	if (isAssignment) {
		name = "__appendArrayAssign" ~ ltype.mangledName ~ rtype.mangledName;
	} else {
		name = "__appendArray" ~ ltype.mangledName ~ rtype.mangledName;
	}

	auto func = lookupFunction(lp, thisModule.myScope, loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	func.type.ret = copyTypeSmart(loc, ltype);

	ir.FunctionParam left, right;
	if (isAssignment) {
		left = addParam(loc, func, buildPtrSmart(loc, ltype), "left");
	} else {
		left = addParamSmart(loc, func, ltype, "left");
	}
	right = addParamSmart(loc, func, rtype, "right");

	auto funcCopy = getLlvmMemCopy(loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(loc, func._body, func._body.myScope, buildVoidPtr(loc), "allocated");
	auto count = buildVarStatSmart(loc, func._body, func._body.myScope, buildSizeT(loc, lp), "count");
	ir.Exp leftlength()
	{
		if (isAssignment) {
			return buildArrayLength(loc, lp, buildDeref(loc, buildExpReference(loc, left, left.name)));
		} else {
			return buildArrayLength(loc, lp, buildExpReference(loc, left, left.name));
		}
	}

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildExpReference(loc, count, count.name),
			buildAdd(loc,
				leftlength(),
				buildConstantSizeT(loc, lp, 1)
			)
		)
	);

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildAllocVoidPtr(loc, lp, ltype.base, buildExpReference(loc, count, count.name))
		)
	);

	ir.Exp leftPtr;
	if (isAssignment) {
		leftPtr = buildArrayPtr(loc, left.type, buildDeref(loc, buildExpReference(loc, left, left.name)));
	} else {
		leftPtr = buildArrayPtr(loc, left.type, buildExpReference(loc, left, left.name));
	}

	args = [
		cast(ir.Exp)
		buildExpReference(loc, allocated, allocated.name),
		buildCastToVoidPtr(loc, leftPtr),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			leftlength(),
			buildConstantSizeT(loc, lp, size(lp, ltype.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, func._body, buildCall(loc, buildExpReference(loc, funcCopy, funcCopy.name), args));

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildDeref(loc,
				buildAdd(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
					leftlength()
				)
			),
			buildExpReference(loc, right, right.name)
		)
	);

	if (isAssignment) {
		buildExpStat(loc, func._body,
			buildAssign(loc,
				buildDeref(loc, buildExpReference(loc, left, left.name)),
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
				)
			)
		);
		buildReturnStat(loc, func._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
	} else {
		buildReturnStat(loc, func._body,
			buildSlice(loc,
				buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
			)
		);
	}

	return func;
}

ir.Function getArrayPrependFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType ltype, ir.Type rtype)
{
	if (ltype.mangledName is null) {
		ltype.mangledName = mangle(ltype);
	}
	if (rtype.mangledName is null) {
		rtype.mangledName = mangle(rtype);
	}

	string name = "__prependArray" ~ ltype.mangledName ~ rtype.mangledName;

	auto func = lookupFunction(lp, thisModule.myScope, loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isWeakLink = true;
	func.type.ret = copyTypeSmart(loc, ltype);

	ir.FunctionParam left, right;
	right = addParamSmart(loc, func, rtype, "left");
	left = addParamSmart(loc, func, ltype, "right");

	auto funcCopy = getLlvmMemCopy(loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(loc, func._body, func._body.myScope, buildVoidPtr(loc), "allocated");
	auto count = buildVarStatSmart(loc, func._body, func._body.myScope, buildSizeT(loc, lp), "count");

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildExpReference(loc, count, count.name),
			buildAdd(loc,
				buildArrayLength(loc, lp, buildExpReference(loc, left, left.name)),
				buildConstantSizeT(loc, lp, 1)
			)
		)
	);

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildAllocVoidPtr(loc, lp, ltype.base, buildExpReference(loc, count, count.name))
		)
	);

	args = [
		cast(ir.Exp)
		buildAdd(loc, buildExpReference(loc, allocated, allocated.name), buildConstantSizeT(loc, lp, size(lp, ltype.base))),
		buildCastToVoidPtr(loc, buildArrayPtr(loc, left.type, buildExpReference(loc, left, left.name))),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildArrayLength(loc, lp, buildExpReference(loc, left, left.name)),
			buildConstantSizeT(loc, lp, size(lp, ltype.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, func._body, buildCall(loc, buildExpReference(loc, funcCopy, funcCopy.name), args));

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildDeref(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
			),
			buildExpReference(loc, right, right.name)
		)
	);

	buildReturnStat(loc, func._body,
		buildSlice(loc,
			buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
			[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
		)
	);

	return func;
}

ir.Function getArrayCopyFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	auto name = "__copyArray" ~ type.mangledName;
	auto func = lookupFunction(lp, thisModule.myScope, loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isWeakLink = true;
	func.type.ret = copyTypeSmart(loc, type);
	auto left = addParamSmart(loc, func, type, "left");
	auto right = addParamSmart(loc, func, type, "right");

	auto funcMove = getLlvmMemMove(loc, lp);
	auto expRef = buildExpReference(loc, funcMove, funcMove.name);

	auto typeSize = size(lp, type.base);

	ir.Exp[] args = [
		cast(ir.Exp)
		buildCastToVoidPtr(loc, buildArrayPtr(loc, left.type, buildExpReference(loc, left, "left"))),
		buildCastToVoidPtr(loc, buildArrayPtr(loc, right.type, buildExpReference(loc, right, "right"))),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildArrayLength(loc, lp, buildExpReference(loc, left, "left")),
			buildConstantSizeT(loc, lp, size(lp, type.base))
			),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, func._body, buildCall(loc, expRef, args));

	buildReturnStat(loc, func._body, buildExpReference(loc, func.params[0], "left"));

	return func;
}

ir.Function getArrayConcatFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type, bool isAssignment)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	string name;
	if (isAssignment) {
		name = "__concatAssignArray" ~ type.mangledName;
	} else {
		name = "__concatArray" ~ type.mangledName;
	}
	auto func = lookupFunction(lp, thisModule.myScope, loc, name);

	if (func !is null) {
		return func;
	}

	func = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isWeakLink = true;
	func.type.ret = copyTypeSmart(loc, type);

	ir.FunctionParam left;
	if (isAssignment) {
		left = addParam(loc, func, buildPtrSmart(loc, type), "left");
	} else {
		left = addParamSmart(loc, func, type, "left");
	}
	auto right = addParamSmart(loc, func, type, "right");

	auto funcCopy = getLlvmMemCopy(loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(loc, func._body, func._body.myScope, buildVoidPtr(loc), "allocated");
	auto count = buildVarStatSmart(loc, func._body, func._body.myScope, buildSizeT(loc, lp), "count");
	ir.Exp leftlength()
	{
		if (isAssignment) {
			return buildArrayLength(loc, lp, buildDeref(loc, buildExpReference(loc, left, left.name)));
		} else {
			return buildArrayLength(loc, lp, buildExpReference(loc, left, left.name));
		}
	}

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildExpReference(loc, count, count.name),
			buildAdd(loc,
				leftlength(),
				buildArrayLength(loc, lp, buildExpReference(loc, right, right.name))
			)
		)
	);

	buildExpStat(loc, func._body,
		buildAssign(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildAllocVoidPtr(loc, lp, type.base, buildExpReference(loc, count, count.name))
		)
	);

	ir.Exp leftPtr;
	if (isAssignment) {
		leftPtr = buildArrayPtr(loc, left.type, buildDeref(loc, buildExpReference(loc, left, left.name)));
	} else {
		leftPtr = buildArrayPtr(loc, left.type, buildExpReference(loc, left, left.name));
	}

	args = [
		cast(ir.Exp)
		buildExpReference(loc, allocated, allocated.name),
		buildCastToVoidPtr(loc, leftPtr),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			leftlength(),
			buildConstantSizeT(loc, lp, size(lp, type.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, func._body, buildCall(loc, buildExpReference(loc, funcCopy, funcCopy.name), args));


	args = [
		cast(ir.Exp)
		buildAdd(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				leftlength(),
				buildConstantSizeT(loc, lp, size(lp, type.base))
			)
		),
		buildCastToVoidPtr(loc, buildArrayPtr(loc, right.type, buildExpReference(loc, right, right.name))),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildArrayLength(loc, lp, buildExpReference(loc, right, right.name)),
			buildConstantSizeT(loc, lp, size(lp, type.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, func._body, buildCall(loc, buildExpReference(loc, funcCopy, funcCopy.name), args));


	if (isAssignment) {
		buildExpStat(loc, func._body,
			buildAssign(loc,
				buildDeref(loc, buildExpReference(loc, left, left.name)),
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
				)
			)
		);
		buildReturnStat(loc, func._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
	} else {
		buildReturnStat(loc, func._body,
			buildSlice(loc,
				buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
			)
		);
	}

	return func;
}

ir.Function getArrayCmpFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type, bool notEqual)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	string name;
	if (notEqual) {
		name = "__cmpNotArray" ~ type.mangledName;
	} else {
		name = "__cmpArray" ~ type.mangledName;
	}
	auto func = lookupFunction(lp, thisModule.myScope, loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isWeakLink = true;
	func.type.ret = buildBool(loc);

	auto left = addParamSmart(loc, func, type, "left");
	auto right = addParamSmart(loc, func, type, "right");

	auto memCmp = lp.memcmpFunc;
	auto memCmpExpRef = buildExpReference(loc, memCmp, memCmp.name);


	auto thenState = buildBlockStat(loc, func, func._body.myScope);
	buildReturnStat(loc, thenState, buildConstantBool(loc, notEqual));
	buildIfStat(loc, func._body,
		buildBinOp(loc, ir.BinOp.Op.NotEqual,
			buildArrayLength(loc, lp, buildExpReference(loc, left, left.name)),
			buildArrayLength(loc, lp, buildExpReference(loc, right, right.name))
		),
		thenState
	);

	auto childArray = cast(ir.ArrayType) type.base;
	if (childArray !is null) {
		/* for (size_t i = 0; i < left.length; ++i) {
		 *     if (left[i] !=/== right[i]) {
		 *         return true;
		 *     }
		 * }
		 * return false;
		 */
		ir.ForStatement forLoop;
		ir.Variable iVar;
		buildForStatement(loc, lp, func._body.myScope, buildArrayLength(loc, lp, buildExpReference(loc, left, left.name)), forLoop, iVar);
		auto l = buildIndex(loc, buildExpReference(loc, left, left.name), buildExpReference(loc, iVar, iVar.name));
		auto r = buildIndex(loc, buildExpReference(loc, right, right.name), buildExpReference(loc, iVar, iVar.name));
		auto cmp = buildBinOp(loc, notEqual ? ir.BinOp.Op.NotEqual : ir.BinOp.Op.Equal, l, r);
		auto then = buildBlockStat(loc, null, forLoop.block.myScope);
		buildReturnStat(loc, then, buildConstantBool(loc, true));
		auto ifs = buildIfStat(loc, cmp, then);
		forLoop.block.statements ~= ifs;
		func._body.statements ~= forLoop;
		buildReturnStat(loc, func._body, buildConstantBool(loc, false));
	} else {
		buildReturnStat(loc, func._body,
			buildBinOp(loc, notEqual ? ir.BinOp.Op.NotEqual : ir.BinOp.Op.Equal,
				buildCall(loc, memCmpExpRef, [
					buildCastSmart(loc, buildVoidPtr(loc), buildArrayPtr(loc, left.type, buildExpReference(loc, left, left.name))),
					buildCastSmart(loc, buildVoidPtr(loc), buildArrayPtr(loc, right.type, buildExpReference(loc, right, right.name))),
					cast(ir.Exp)buildBinOp(loc, ir.BinOp.Op.Mul,
						buildArrayLength(loc, lp, buildExpReference(loc, left, left.name)),
						buildConstantSizeT(loc, lp, size(lp, type.base))
					)

				]),
				buildConstantInt(loc, 0)
			)
		);
	}

	return func;
}
